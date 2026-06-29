import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'

export default async function HomePage() {
  const supabase = createClient()

  // Fetch public stats
  const [
    { count: totalMembers },
    { data: earnings },
    { data: settings },
    { data: groups },
  ] = await Promise.all([
    supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('approved', true),
    supabase.from('weekly_earnings').select('amount_usd'),
    supabase.from('app_settings').select('key,value'),
    supabase.from('color_groups').select('name, hex_color, member_count').order('member_count', { ascending: false }),
  ])

  const totalEarnings = (earnings ?? []).reduce((s, e) => s + Number(e.amount_usd), 0)
  const settingsMap = Object.fromEntries((settings ?? []).map(s => [s.key, s.value]))
  const appName = settingsMap.app_name ?? 'Elevate Office Tracker'

  return (
    <div className="min-h-screen bg-gradient-to-br from-brand-900 via-brand-800 to-brand-700 text-white">
      {/* Nav */}
      <nav className="flex items-center justify-between px-6 py-4 max-w-6xl mx-auto">
        <div className="font-bold text-xl tracking-tight">{appName}</div>
        <div className="flex gap-3">
          <Link href="/login" className="btn-secondary text-gray-700">Sign In</Link>
          <Link href="/signup" className="bg-white text-brand-700 font-semibold px-4 py-2 rounded-lg hover:bg-gray-50 transition-colors text-sm">Sign Up</Link>
        </div>
      </nav>

      {/* Hero */}
      <div className="max-w-6xl mx-auto px-6 py-20 text-center">
        <div className="inline-block bg-white/10 text-white/80 px-4 py-1.5 rounded-full text-sm font-medium mb-6">
          Office Attendance · Team Tracking · Business Growth
        </div>
        <h1 className="text-4xl sm:text-6xl font-extrabold mb-6 leading-tight">
          Elevate Your Team<br/>Performance
        </h1>
        <p className="text-white/70 text-lg max-w-2xl mx-auto mb-10">
          {settingsMap.about_us ?? 'Track attendance, monitor team growth, and celebrate wins together.'}
        </p>
        <Link href="/signup" className="bg-white text-brand-700 font-bold px-8 py-3.5 rounded-xl hover:bg-gray-50 transition-colors text-base shadow-lg inline-block">
          Join the Team
        </Link>
      </div>

      {/* Stats */}
      <div className="max-w-6xl mx-auto px-6 pb-20">
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-12">
          {[
            { label: 'Active Members', value: (totalMembers ?? 0).toLocaleString() },
            { label: 'Total Earned (All Time)', value: `$${totalEarnings.toLocaleString('en-US', { maximumFractionDigits: 0 })}` },
            { label: 'Color Groups', value: (groups ?? []).length },
          ].map(stat => (
            <div key={stat.label} className="bg-white/10 rounded-xl p-5 text-center backdrop-blur-sm">
              <div className="text-3xl font-extrabold mb-1">{stat.value}</div>
              <div className="text-white/60 text-sm">{stat.label}</div>
            </div>
          ))}
        </div>

        {/* Color groups ranking */}
        {groups && groups.length > 0 && (
          <div className="bg-white/10 rounded-2xl p-6 backdrop-blur-sm">
            <h2 className="font-bold text-lg mb-4">Group Leaderboard</h2>
            <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
              {groups.slice(0, 10).map((g, i) => (
                <div key={g.name} className="text-center">
                  <div
                    className="w-10 h-10 rounded-full mx-auto mb-1.5 flex items-center justify-center text-xs font-bold text-white"
                    style={{ backgroundColor: g.hex_color }}
                  >
                    {i + 1}
                  </div>
                  <div className="text-sm font-semibold">{g.name}</div>
                  <div className="text-white/60 text-xs">{g.member_count} members</div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
