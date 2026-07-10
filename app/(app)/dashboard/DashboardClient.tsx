'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { formatCurrency, getStatusLabel, getStatusColor } from '@/lib/utils'
import type { Profile, ColorGroup } from '@/lib/types'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts'
import { TrendingUp, Users, Target, Calendar, Award, Zap, Star } from 'lucide-react'
import ViewAsBanner from '@/components/admin/ViewAsBanner'

const RANGES = [
  { value: 'this_week', label: 'This Week' },
  { value: 'this_month', label: 'This Month' },
  { value: 'last_month', label: 'Last Month' },
  { value: 'last_3_months', label: 'Last 3 Months' },
  { value: 'last_6_months', label: 'Last 6 Months' },
  { value: 'last_year', label: 'Last Year' },
]

function Avatar({ src, name, color, size = 'sm' }: { src?: string | null; name?: string | null; color?: string; size?: 'sm' | 'md' | 'lg' }) {
  const sizes = { sm: 'w-8 h-8 text-xs', md: 'w-10 h-10 text-sm', lg: 'w-12 h-12 text-base' }
  const displayName = name?.trim() || '?'
  return (
    <div className={`${sizes[size]} rounded-full flex-shrink-0 overflow-hidden`}>
      {src ? (
        <img src={src} alt={displayName} className="w-full h-full object-cover" />
      ) : (
        <div className="w-full h-full flex items-center justify-center text-white font-bold" style={{ backgroundColor: color ?? '#4f46e5' }}>
          {displayName.slice(0, 1)}
        </div>
      )}
    </div>
  )
}

function StatCard({ label, value, sub, icon, color = 'brand', delay = 0 }: { label: string; value: string | number; sub?: string; icon: React.ReactNode; color?: string; delay?: number }) {
  const colors: Record<string, string> = {
    brand: 'text-brand-600 bg-brand-50',
    green: 'text-green-600 bg-green-50',
    amber: 'text-amber-600 bg-amber-50',
    purple: 'text-purple-600 bg-purple-50',
    blue: 'text-blue-600 bg-blue-50',
    red: 'text-red-600 bg-red-50',
  }
  return (
    <div className="card p-5 animate-slide-up" style={{ animationDelay: `${delay}ms` }}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-semibold text-gray-400 uppercase tracking-wider">{label}</p>
          <p className="text-2xl font-extrabold text-gray-900 mt-1">{value}</p>
          {sub && <p className="text-xs text-gray-400 mt-0.5">{sub}</p>}
        </div>
        <div className={`p-2.5 rounded-xl ${colors[color] ?? colors.brand}`}>{icon}</div>
      </div>
    </div>
  )
}

function SectionHeader({ title, sub }: { title: string; sub?: string }) {
  return (
    <div className="mb-3">
      <h2 className="text-base font-bold text-gray-900">{title}</h2>
      {sub && <p className="text-xs text-gray-400 mt-0.5">{sub}</p>}
    </div>
  )
}

export default function DashboardClient({
  profile, range, myAttendanceDays, myTotalEarnings, myScoutingCount,
  myRank, myTotalPoints, todayAttendanceCount, todayAttendees, newMembersCount,
  topEarners, groupEarnings, colorGroups, isAdmin, isEMOrBelow, settingsMap,
  topScoutsToday, groupScoutLeaderboard, consistentEarners, topPunctuality,
  memberStartsThisMonth, teamStartsThisMonth, isSMOrAbove, isViewingAs, viewAsName,
}: {
  profile: Profile; range: string
  myAttendanceDays: number; myTotalEarnings: number; myScoutingCount: number
  myRank: number; myTotalPoints: number
  todayAttendanceCount: number; todayAttendees: any[]
  newMembersCount: number
  topEarners: any[]; groupEarnings: any[]
  colorGroups: ColorGroup[]; isAdmin: boolean; isEMOrBelow: boolean
  settingsMap: Record<string, string>
  topScoutsToday: any[]; groupScoutLeaderboard: any[]; consistentEarners: any[]; topPunctuality: any[]
  memberStartsThisMonth: number; teamStartsThisMonth: number; isSMOrAbove: boolean
  isViewingAs?: boolean; viewAsName?: string | null
}) {
  const router = useRouter()
  const [consistentRange, setConsistentRange] = useState<number>(6) // months

  const appName = settingsMap.app_name ?? 'Elevate Office'
  const myGroupName = profile.color_groups?.name ?? 'No Group'
  const memberDisplayName = profile.full_name?.trim() || profile.member_id || 'Member'
  const firstName = memberDisplayName.split(/\s+/)[0] || 'there'
  const isGroupLeader = profile.member_id?.endsWith('-001') ?? false

  const rangeLabel = (RANGES.find(r => r.value === range)?.label ?? 'This Month').toLowerCase()
  const filteredConsistent = consistentEarners.filter(e => e.months >= 1)

  return (
    <div className="space-y-6 max-w-7xl mx-auto animate-fade-in">
      {isViewingAs && viewAsName && <ViewAsBanner name={viewAsName} />}

      {/* Welcome header */}
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-extrabold text-gray-900">
            Welcome back, {firstName} 👋
          </h1>
          <p className="text-sm text-gray-400 mt-0.5">
            {myGroupName} · {getStatusLabel(profile.status)}{isGroupLeader ? ' · Group Leader' : ''}
          </p>
        </div>
        <div className="flex gap-1.5 flex-wrap">
          {RANGES.map(r => (
            <button key={r.value} onClick={() => router.push(`/dashboard?range=${r.value}`)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all active:scale-95 ${range === r.value ? 'bg-brand-600 text-white shadow-sm' : 'bg-white border border-gray-200 text-gray-600 hover:border-brand-300 hover:text-brand-600'}`}>
              {r.label}
            </button>
          ))}
        </div>
      </div>

      {/* My stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 stagger-children">
        <StatCard label="Days Present" value={myAttendanceDays} sub={rangeLabel} icon={<Calendar size={18} />} color="brand" delay={0} />
        <StatCard label="My Earnings" value={formatCurrency(myTotalEarnings)} sub={rangeLabel} icon={<TrendingUp size={18} />} color="green" delay={50} />
        <StatCard label="Businesses Scouted" value={myScoutingCount} sub="total contacted" icon={<Target size={18} />} color="amber" delay={100} />
        <StatCard label="Members Start" value={memberStartsThisMonth} sub="this month · direct" icon={<Zap size={18} />} color="blue" delay={125} />
        <StatCard label={isSMOrAbove ? 'SM Team Starts' : 'Team Starts'} value={teamStartsThisMonth} sub="this month" icon={<Users size={18} />} color="purple" delay={140} />
        {isEMOrBelow && myRank > 0 && <StatCard label="My Rank" value={`#${myRank}`} sub="this month" icon={<Award size={18} />} color="purple" delay={150} />}
        {isEMOrBelow && <StatCard label="Consistency Points" value={myTotalPoints} sub="all time" icon={<Star size={18} />} color="blue" delay={200} />}
      </div>

      {/* Admin stats bar */}
      {isAdmin && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 stagger-children">
          <StatCard label="In Office Today" value={todayAttendanceCount} icon={<Users size={18} />} color="brand" />
          <StatCard label="New Members" value={newMembersCount} sub="this month" icon={<Zap size={18} />} color="green" />
          <StatCard label="Color Groups" value={colorGroups.length} icon={<Users size={18} />} color="amber" />
          <StatCard label="Top Scout Today" value={topScoutsToday[0]?.count ?? 0} sub={topScoutsToday[0]?.full_name ?? 'No scouts yet'} icon={<Target size={18} />} color="purple" />
        </div>
      )}

      {/* Two column layout for main content */}
      <div className="grid lg:grid-cols-2 gap-6">

        {/* TODAY IN OFFICE (admin) */}
        {isAdmin && todayAttendees.length > 0 && (
          <div className="card p-5 animate-slide-up">
            <SectionHeader title="In Office Today" sub={`${todayAttendanceCount} members signed in`} />
            <div className="space-y-2 max-h-64 overflow-y-auto">
              {todayAttendees.slice(0, 20).map((a: any, i: number) => (
                <div key={a.id ?? i} className="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-50 transition-colors">
                  <Avatar src={a.profile_picture} name={a.full_name ?? '?'} color={a.color_groups?.hex_color} size="sm" />
                  <div className="flex-1 min-w-0">
                    <div className="font-medium text-sm text-gray-900 truncate">{a.full_name}</div>
                    <div className="text-xs text-gray-400">{a.member_id}</div>
                  </div>
                  <span className={`badge ${getStatusColor(a.status)}`}>{getStatusLabel(a.status)}</span>
                </div>
              ))}
              {todayAttendees.length > 20 && <div className="text-xs text-gray-400 text-center pt-2">+{todayAttendees.length - 20} more</div>}
            </div>
          </div>
        )}

        {/* TOP 3 SCOUTS TODAY */}
        <div className="card p-5 animate-slide-up">
          <SectionHeader title="🎯 Top Scouts Today" sub="By businesses contacted today" />
          {topScoutsToday.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No scouting activity today yet</p>
          ) : (
            <div className="space-y-3">
              {topScoutsToday.map((s, i) => (
                <div key={s.id} className="flex items-center gap-3">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-extrabold flex-shrink-0 ${i === 0 ? 'bg-yellow-100 text-yellow-700' : i === 1 ? 'bg-gray-100 text-gray-600' : 'bg-orange-100 text-orange-700'}`}>
                    {i + 1}
                  </div>
                  <Avatar src={s.profile_picture} name={s.full_name} color={s.group_color} size="sm" />
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-sm text-gray-900 truncate">{s.full_name}</div>
                    <div className="text-xs text-gray-400">{s.group_name}</div>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <div className="font-extrabold text-brand-600">{s.count}</div>
                    <div className="text-xs text-gray-400">scouted</div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* TOP 20 EARNERS */}
        <div className="card p-5 animate-slide-up lg:col-span-2">
          <SectionHeader title="💰 Top 20 Earners — This Month" sub="Executive Manager and below" />
          {topEarners.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No earnings recorded this month</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b border-gray-100">
                  <th className="table-th w-10">#</th>
                  <th className="table-th">Member</th>
                  <th className="table-th hidden sm:table-cell">Group</th>
                  <th className="table-th hidden sm:table-cell">Status</th>
                  <th className="table-th text-right">Earned</th>
                </tr></thead>
                <tbody>
                  {topEarners.map((e, i) => (
                    <tr key={e.id} className={`table-row ${e.id === profile.id ? 'bg-brand-50' : ''}`}>
                      <td className="table-td">
                        <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold ${i === 0 ? 'bg-yellow-100 text-yellow-700' : i === 1 ? 'bg-gray-100 text-gray-600' : i === 2 ? 'bg-orange-100 text-orange-700' : 'bg-gray-50 text-gray-400'}`}>{i+1}</div>
                      </td>
                      <td className="table-td">
                        <div className="flex items-center gap-2">
                          <Avatar src={e.profile_picture} name={e.full_name} color={e.group_color} size="sm" />
                          <div>
                            <div className="font-medium text-gray-900">{e.full_name} {e.id === profile.id && <span className="text-brand-500 text-xs">(You)</span>}</div>
                            <div className="text-xs text-gray-400">{e.member_id}</div>
                          </div>
                        </div>
                      </td>
                      <td className="table-td hidden sm:table-cell">
                        <div className="flex items-center gap-1.5">
                          <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: e.group_color }} />
                          <span className="text-gray-500">{e.group_name}</span>
                        </div>
                      </td>
                      <td className="table-td hidden sm:table-cell"><span className={`badge ${getStatusColor(e.status)}`}>{getStatusLabel(e.status)}</span></td>
                      <td className="table-td text-right font-bold text-green-700">{formatCurrency(e.total)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* CONSISTENT EARNERS */}
        <div className="card p-5 animate-slide-up lg:col-span-2">
          <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
            <div>
              <h2 className="text-base font-bold text-gray-900">⭐ Top 20 Most Consistent Earners</h2>
              <p className="text-xs text-gray-400 mt-0.5">1st place = 10pts, 2nd = 9pts … 10th = 1pt, 11th+ = 0pts per month</p>
            </div>
            <select className="input w-auto text-sm py-1.5" value={consistentRange} onChange={e => setConsistentRange(Number(e.target.value))}>
              <option value={1}>Last 1 month</option>
              <option value={3}>Last 3 months</option>
              <option value={6}>Last 6 months</option>
              <option value={12}>Last 12 months</option>
              <option value={999}>All time</option>
            </select>
          </div>
          {consistentEarners.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No points data yet. Record earnings and calculate points first.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b border-gray-100">
                  <th className="table-th w-10">#</th>
                  <th className="table-th">Member</th>
                  <th className="table-th hidden sm:table-cell">Group</th>
                  <th className="table-th">Total Points</th>
                  <th className="table-th hidden sm:table-cell">Months</th>
                </tr></thead>
                <tbody>
                  {filteredConsistent.map((e, i) => (
                    <tr key={e.id} className={`table-row ${e.id === profile.id ? 'bg-brand-50' : ''}`}>
                      <td className="table-td">
                        <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold ${i === 0 ? 'bg-yellow-100 text-yellow-700' : i === 1 ? 'bg-gray-100 text-gray-600' : i === 2 ? 'bg-orange-100 text-orange-700' : 'bg-gray-50 text-gray-400'}`}>{i+1}</div>
                      </td>
                      <td className="table-td">
                        <div className="flex items-center gap-2">
                          <Avatar src={e.profile_picture} name={e.full_name} color={e.group_color} size="sm" />
                          <div>
                            <div className="font-medium text-gray-900">{e.full_name} {e.id === profile.id && <span className="text-brand-500 text-xs">(You)</span>}</div>
                            <div className="text-xs text-gray-400">{e.member_id}</div>
                          </div>
                        </div>
                      </td>
                      <td className="table-td hidden sm:table-cell">
                        <div className="flex items-center gap-1.5">
                          <div className="w-3 h-3 rounded-full" style={{ backgroundColor: e.group_color }} />
                          <span className="text-gray-500">{e.group_name}</span>
                        </div>
                      </td>
                      <td className="table-td font-extrabold text-brand-600">{e.totalPoints} pts</td>
                      <td className="table-td hidden sm:table-cell text-gray-400">{e.months} month{e.months !== 1 ? 's' : ''}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* TOP PUNCTUALITY LEADERBOARD */}
        <div className="card p-5 animate-slide-up">
          <SectionHeader title="⏰ Top 20 Punctuality" sub={`Earliest average sign-in time · ${rangeLabel}`} />
          {topPunctuality.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No sign-ins recorded {rangeLabel} yet.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b border-gray-100">
                  <th className="table-th w-10">#</th>
                  <th className="table-th">Member</th>
                  <th className="table-th hidden sm:table-cell">Group</th>
                  <th className="table-th">Avg. Ahead of Window</th>
                  <th className="table-th hidden sm:table-cell">Days</th>
                </tr></thead>
                <tbody>
                  {topPunctuality.map((e, i) => (
                    <tr key={e.id} className={`table-row ${e.id === profile.id ? 'bg-brand-50' : ''}`}>
                      <td className="table-td">
                        <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold ${i === 0 ? 'bg-yellow-100 text-yellow-700' : i === 1 ? 'bg-gray-100 text-gray-600' : i === 2 ? 'bg-orange-100 text-orange-700' : 'bg-gray-50 text-gray-400'}`}>{i+1}</div>
                      </td>
                      <td className="table-td">
                        <div className="flex items-center gap-2">
                          <Avatar src={e.profile_picture} name={e.full_name} color={e.group_color} size="sm" />
                          <div>
                            <div className="font-medium text-gray-900">{e.full_name} {e.id === profile.id && <span className="text-brand-500 text-xs">(You)</span>}</div>
                            <div className="text-xs text-gray-400">{e.member_id}</div>
                          </div>
                        </div>
                      </td>
                      <td className="table-td hidden sm:table-cell">
                        <div className="flex items-center gap-1.5">
                          <div className="w-3 h-3 rounded-full" style={{ backgroundColor: e.group_color }} />
                          <span className="text-gray-500">{e.group_name}</span>
                        </div>
                      </td>
                      <td className="table-td font-extrabold text-brand-600">
                        {e.avgMinutesEarly >= 0 ? `${e.avgMinutesEarly} min early` : `${Math.abs(e.avgMinutesEarly)} min late`}
                      </td>
                      <td className="table-td hidden sm:table-cell text-gray-400">{e.days} day{e.days !== 1 ? 's' : ''}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* GROUP SCOUTING LEADERBOARD */}
        <div className="card p-5 animate-slide-up">
          <SectionHeader title="🔍 Scouting by Color Group" sub="Total businesses contacted" />
          {groupScoutLeaderboard.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No scouting data yet</p>
          ) : (
            <div className="space-y-2">
              {groupScoutLeaderboard.map((g, i) => (
                <div key={g.name} className="flex items-center gap-3">
                  <div className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold bg-gray-50 text-gray-500 flex-shrink-0">{i+1}</div>
                  <div className="w-4 h-4 rounded-full flex-shrink-0" style={{ backgroundColor: g.hex_color }} />
                  <div className="flex-1 font-medium text-sm text-gray-900">{g.name}</div>
                  <div className="font-extrabold text-brand-600">{g.count}</div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* GROUP EARNINGS CHART */}
        {groupEarnings.length > 0 && (
          <div className="card p-5 animate-slide-up">
            <SectionHeader title="💼 Earnings by Group" sub="This month" />
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={groupEarnings} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
                <XAxis dataKey="name" tick={{ fontSize: 10 }} />
                <YAxis tick={{ fontSize: 10 }} tickFormatter={v => `$${v}`} />
                <Tooltip formatter={(v: number) => formatCurrency(v)} />
                <Bar dataKey="total" radius={[4,4,0,0]}>
                  {groupEarnings.map((g, i) => <Cell key={i} fill={g.hex_color} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>
    </div>
  )
}
