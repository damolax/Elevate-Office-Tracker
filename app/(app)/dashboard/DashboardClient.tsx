'use client'

import { useRouter } from 'next/navigation'
import { formatCurrency, getStatusLabel, getStatusColor } from '@/lib/utils'
import type { Profile, ColorGroup } from '@/lib/types'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts'

const RANGES = [
  { value: 'this_week', label: 'This Week' },
  { value: 'this_month', label: 'This Month' },
  { value: 'last_month', label: 'Last Month' },
  { value: 'last_3_months', label: 'Last 3 Months' },
  { value: 'last_6_months', label: 'Last 6 Months' },
  { value: 'last_year', label: 'Last Year' },
]

export default function DashboardClient({
  profile, range, myAttendanceDays, myTotalEarnings, myScoutingCount,
  myRank, todayAttendanceCount, newMembersCount, topEarners,
  lastMonthTopEarners, groupEarnings, colorGroups, isAdmin, settingsMap,
}: {
  profile: Profile
  range: string
  myAttendanceDays: number
  myTotalEarnings: number
  myScoutingCount: number
  myRank: number
  todayAttendanceCount: number
  newMembersCount: number
  topEarners: { id: string; full_name: string; member_id: string; status: string; total: number; group_name: string; group_color: string }[]
  lastMonthTopEarners: { id: string; full_name: string; member_id: string; total: number; group_name: string }[]
  groupEarnings: { name: string; hex_color: string; total: number }[]
  colorGroups: ColorGroup[]
  isAdmin: boolean
  settingsMap: Record<string, string>
}) {
  const router = useRouter()

  function setRange(r: string) {
    router.push(`/dashboard?range=${r}`)
  }

  const myGroupName = profile.color_groups?.name ?? 'No Group'
  const topGroupEarning = groupEarnings[0]

  return (
    <div className="space-y-6 max-w-7xl mx-auto">
      {/* Range filter */}
      <div className="flex items-center gap-2 flex-wrap">
        {RANGES.map(r => (
          <button
            key={r.value}
            onClick={() => setRange(r.value)}
            className={`px-3 py-1.5 rounded-full text-sm font-medium transition-colors ${
              range === r.value
                ? 'bg-brand-600 text-white'
                : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
            }`}
          >
            {r.label}
          </button>
        ))}
      </div>

      {/* Personal stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <StatCard
          label="My Attendance"
          value={`${myAttendanceDays} days`}
          sub="in selected range"
          color="bg-blue-50"
          textColor="text-blue-700"
        />
        <StatCard
          label="My Earnings"
          value={formatCurrency(myTotalEarnings)}
          sub="in selected range"
          color="bg-green-50"
          textColor="text-green-700"
        />
        <StatCard
          label="Businesses Scouted"
          value={myScoutingCount.toLocaleString()}
          sub="in selected range"
          color="bg-purple-50"
          textColor="text-purple-700"
        />
        <StatCard
          label="My Rank"
          value={myRank > 0 ? `#${myRank}` : 'Unranked'}
          sub="among top earners"
          color="bg-orange-50"
          textColor="text-orange-700"
        />
      </div>

      {/* Office-wide stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {isAdmin && (
          <StatCard
            label="In Office Today"
            value={todayAttendanceCount}
            sub="signed in"
            color="bg-indigo-50"
            textColor="text-indigo-700"
          />
        )}
        <StatCard
          label="New Members"
          value={newMembersCount}
          sub="this month"
          color="bg-pink-50"
          textColor="text-pink-700"
        />
        <StatCard
          label="Leading Group"
          value={topGroupEarning?.name ?? '—'}
          sub={topGroupEarning ? formatCurrency(topGroupEarning.total) + ' this month' : 'No data yet'}
          color="bg-yellow-50"
          textColor="text-yellow-700"
        />
        <StatCard
          label="My Group"
          value={myGroupName}
          sub={profile.color_groups?.member_count ? `${profile.color_groups.member_count} members` : 'No group'}
          color="bg-gray-50"
          textColor="text-gray-700"
          dot={profile.color_groups?.hex_color}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Earners */}
        <div className="card p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="section-title">Top 20 Earners — This Month</h2>
            <span className="text-xs text-gray-400">Managers & Below</span>
          </div>
          {topEarners.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
          ) : (
            <div className="space-y-2 max-h-80 overflow-y-auto">
              {topEarners.map((e, i) => {
                const isMe = e.id === profile.id
                // People with same amount get same rank
                const sameRankCount = topEarners.filter((x, xi) => xi < i && x.total === e.total).length
                const rank = i + 1 - sameRankCount
                return (
                  <div key={e.id} className={`flex items-center gap-3 p-2.5 rounded-lg ${isMe ? 'bg-brand-50 border border-brand-200' : 'hover:bg-gray-50'}`}>
                    <div className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 ${i < 3 ? 'bg-yellow-100 text-yellow-700' : 'bg-gray-100 text-gray-500'}`}>
                      {rank}
                    </div>
                    <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: e.group_color }} />
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium truncate">{e.full_name} {isMe && <span className="text-brand-600">(You)</span>}</div>
                      <div className="text-xs text-gray-400">{e.member_id} · {getStatusLabel(e.status as any)}</div>
                    </div>
                    <div className="font-bold text-sm text-green-700">{formatCurrency(e.total)}</div>
                  </div>
                )
              })}
            </div>
          )}
        </div>

        {/* Group Earnings Chart */}
        <div className="card p-5">
          <h2 className="section-title mb-4">Group Money Rankings — This Month</h2>
          {groupEarnings.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No group earnings yet</p>
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <BarChart data={groupEarnings} margin={{ top: 0, right: 0, bottom: 0, left: 0 }}>
                <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} tickFormatter={v => `$${v}`} />
                <Tooltip formatter={(v: number) => formatCurrency(v)} />
                <Bar dataKey="total" radius={[4, 4, 0, 0]}>
                  {groupEarnings.map((entry, i) => (
                    <Cell key={i} fill={entry.hex_color} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>

      {/* Last month top earners */}
      {lastMonthTopEarners.length > 0 && (
        <div className="card p-5">
          <h2 className="section-title mb-4">Last Month — Top Earners</h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {lastMonthTopEarners.map((e, i) => (
              <div key={e.id} className="flex items-center gap-3 p-3 bg-gray-50 rounded-xl">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 ${
                  i === 0 ? 'bg-yellow-100 text-yellow-700' : i === 1 ? 'bg-gray-200 text-gray-700' : 'bg-orange-100 text-orange-700'
                }`}>
                  {i + 1}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-semibold truncate">{e.full_name}</div>
                  <div className="text-xs text-gray-400">{e.group_name}</div>
                </div>
                <div className="text-sm font-bold text-green-700">{formatCurrency(e.total)}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Color groups overview */}
      <div className="card p-5">
        <h2 className="section-title mb-4">Color Groups</h2>
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
          {colorGroups.map(g => (
            <div key={g.id} className="text-center p-3 rounded-xl border border-gray-100">
              <div
                className="w-10 h-10 rounded-full mx-auto mb-2 border-2 border-white shadow-sm"
                style={{ backgroundColor: g.hex_color }}
              />
              <div className="text-sm font-bold text-gray-900">{g.name}</div>
              <div className="text-xs text-gray-400">{g.member_count} members</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function StatCard({
  label, value, sub, color, textColor, dot,
}: {
  label: string
  value: string | number
  sub: string
  color: string
  textColor: string
  dot?: string
}) {
  return (
    <div className={`card p-4 ${color}`}>
      <div className="text-xs font-medium text-gray-500 mb-1">{label}</div>
      <div className={`text-2xl font-extrabold ${textColor} flex items-center gap-1.5`}>
        {dot && <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: dot }} />}
        {value}
      </div>
      <div className="text-xs text-gray-400 mt-0.5">{sub}</div>
    </div>
  )
}
