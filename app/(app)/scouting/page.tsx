import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ScoutingClient from './ScoutingClient'

export default async function ScoutingPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director

  const [
    { data: myRecords, count: myCount },
    { data: allRecords },
    { data: groupStats },
  ] = await Promise.all([
    supabase.from('scouting_records')
      .select('*', { count: 'exact' })
      .eq('user_id', user.id)
      .order('scouted_at', { ascending: false })
      .limit(200),

    isAdmin
      ? supabase.from('scouting_records')
          .select('*, profiles!inner(id, full_name, member_id, color_group_id, color_groups!profiles_color_group_id_fkey(name, hex_color, code))')
          .order('scouted_at', { ascending: false })
          .limit(500)
      : { data: null },

    // Group scouting stats
    supabase.from('scouting_records')
      .select('user_id, profiles!inner(color_group_id, color_groups!profiles_color_group_id_fkey(name, hex_color))'),
  ])

  // Aggregate group stats
  const groupMap = new Map<string, { name: string; hex_color: string; total: number }>()
  for (const r of (groupStats ?? [])) {
    const g = (r as any).profiles?.color_groups
    if (!g) continue
    const existing = groupMap.get(g.name) ?? { name: g.name, hex_color: g.hex_color, total: 0 }
    existing.total++
    groupMap.set(g.name, existing)
  }
  const sortedGroupStats = Array.from(groupMap.values()).sort((a, b) => b.total - a.total)

  return (
    <ScoutingClient
      profile={profile}
      isAdmin={isAdmin}
      myRecords={(myRecords ?? []) as any[]}
      myCount={myCount ?? 0}
      allRecords={(allRecords ?? []) as any[]}
      groupStats={sortedGroupStats}
    />
  )
}
