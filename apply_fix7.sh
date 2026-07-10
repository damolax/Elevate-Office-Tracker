#!/usr/bin/env bash
set -e
echo "Writing updated files..."

mkdir -p "app/(app)/dashboard"
cat > "app/(app)/dashboard/DashboardClient.tsx" << 'CLAUDE_EOF_MARKER'
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
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/dashboard"
cat > "app/(app)/dashboard/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format, startOfMonth, endOfMonth, startOfWeek, endOfWeek, subMonths } from 'date-fns'
import { computeTeam, isSmOrAbove, ATTENDANCE_RULES } from '@/lib/types'
import { getEffectiveProfile } from '@/lib/view-as'
import DashboardClient from './DashboardClient'

export default async function DashboardPage({ searchParams }: { searchParams: { range?: string } }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: realProfile, error: profileError } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*), sponsor:sponsor_id(id, full_name, member_id)')
    .eq('id', user.id)
    .single()

  // PGRST116 = no row found. Any other error is a real query/DB problem,
  // not "not yet approved" — don't mask it as pending-approval.
  if (profileError && profileError.code !== 'PGRST116') {
    console.error('DashboardPage profile query failed:', profileError)
    throw new Error(`Failed to load profile: ${profileError.message}`)
  }

  if (!realProfile) redirect('/pending-approval')
  if (!realProfile.approved && !realProfile.is_admin && !realProfile.is_director && !realProfile.is_co_admin) redirect('/pending-approval')

  // Admin "View As": nav/permissions always reflect the REAL logged-in admin;
  // only the personal stats below reflect whoever they're viewing as.
  const { profile, isViewingAs, viewAsName } = await getEffectiveProfile(supabase, realProfile)

  const range = searchParams.range ?? 'this_month'
  const now = new Date()
  const todayStr = format(now, 'yyyy-MM-dd')
  const thisMonthStart = format(startOfMonth(now), 'yyyy-MM-dd')
  const thisMonthEnd = format(endOfMonth(now), 'yyyy-MM-dd')
  const thisMonthStr = format(now, 'yyyy-MM')
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin
  const isEMOrBelow = ['member','distributor','manager','executive_manager'].includes(profile.status)

  let rangeStart: string, rangeEnd: string
  switch (range) {
    case 'this_week':
      rangeStart = format(startOfWeek(now, { weekStartsOn: 1 }), 'yyyy-MM-dd')
      rangeEnd = format(endOfWeek(now, { weekStartsOn: 1 }), 'yyyy-MM-dd')
      break
    case 'last_month':
      rangeStart = format(startOfMonth(subMonths(now, 1)), 'yyyy-MM-dd')
      rangeEnd = format(endOfMonth(subMonths(now, 1)), 'yyyy-MM-dd')
      break
    case 'last_3_months':
      rangeStart = format(startOfMonth(subMonths(now, 3)), 'yyyy-MM-dd')
      rangeEnd = todayStr; break
    case 'last_6_months':
      rangeStart = format(startOfMonth(subMonths(now, 6)), 'yyyy-MM-dd')
      rangeEnd = todayStr; break
    case 'last_year':
      rangeStart = format(new Date(now.getFullYear() - 1, now.getMonth(), 1), 'yyyy-MM-dd')
      rangeEnd = todayStr; break
    default:
      rangeStart = thisMonthStart
      rangeEnd = thisMonthEnd
  }

  const [
    { data: myAttendance },
    { data: myEarnings },
    { count: myScoutingCount },
    { data: todayAttendance },
    { data: colorGroups },
    { data: topEarnersRaw },
    { count: newMembersCount },
    { data: groupEarningsRaw },
    { data: settings },
    { data: todayScouts },
    { data: groupScouts },
    { data: consistentPoints },
    { data: myPoints },
    { data: allProfilesForTeam },
    { data: punctualityRaw },
  ] = await Promise.all([
    supabase.from('attendance').select('date').eq('user_id', profile.id)
      .gte('date', rangeStart).lte('date', rangeEnd).not('sign_in_time', 'is', null),

    supabase.from('weekly_earnings').select('amount_usd').eq('user_id', profile.id)
      .gte('week_start', rangeStart).lte('week_start', rangeEnd),

    supabase.from('scouting_records').select('id', { count: 'exact', head: true })
      .eq('user_id', profile.id).eq('status', 'contacted'),

    supabase.from('attendance')
      .select('user_id, profiles!inner(id, full_name, member_id, status, color_group_id, profile_picture, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .eq('date', todayStr).not('sign_in_time', 'is', null),

    supabase.from('color_groups').select('*').order('member_count', { ascending: false }),

    // Top 20 earners EM and below this month
    supabase.from('weekly_earnings')
      .select('amount_usd, profiles!inner(id, full_name, member_id, status, profile_picture, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .gte('week_start', thisMonthStart).lte('week_start', thisMonthEnd)
      .in('profiles.status', ['member','distributor','manager','executive_manager']),

    supabase.from('profiles').select('id', { count: 'exact', head: true })
      .eq('is_new_member', true).eq('new_member_month', thisMonthStr),

    // Group earnings this month
    supabase.from('weekly_earnings')
      .select('amount_usd, profiles!inner(color_group_id, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .gte('week_start', thisMonthStart).lte('week_start', thisMonthEnd),

    supabase.from('app_settings').select('key, value'),

    // Top scouts today (by contacted count)
    supabase.from('scouting_records')
      .select('user_id, profiles!inner(id, full_name, member_id, profile_picture, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .eq('status', 'contacted')
      .gte('scouted_at', new Date(todayStr).toISOString())
      .lt('scouted_at', new Date(new Date(todayStr).getTime() + 864e5).toISOString()),

    // Scouting by color group (all time)
    supabase.from('scouting_records')
      .select('user_id, profiles!inner(color_group_id, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .eq('status', 'contacted'),

    // Consistent earner points (top 20)
    supabase.from('earner_points')
      .select('user_id, points, month_str, rank, amount_usd, profiles(id, full_name, member_id, profile_picture, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .order('month_str', { ascending: false }),

    // My own points
    supabase.from('earner_points')
      .select('points, month_str, rank').eq('user_id', profile.id),

    // All approved profiles (for team-starts computation)
    supabase.from('profiles')
      .select('id, sponsor_id, status, is_new_member, new_member_month')
      .eq('approved', true),

    // Sign-in times in range, for Top Punctuality
    supabase.from('attendance')
      .select('user_id, date, sign_in_time, is_night_session, profiles!inner(id, full_name, member_id, profile_picture, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .gte('date', rangeStart).lte('date', rangeEnd)
      .not('sign_in_time', 'is', null)
      .eq('is_night_session', false),
  ])

  // Aggregate top earners
  const earnerMap = new Map<string, any>()
  for (const e of (topEarnersRaw ?? [])) {
    const p = (e as any).profiles
    if (!p) continue
    const ex = earnerMap.get(p.id) ?? { id: p.id, full_name: p.full_name, member_id: p.member_id, status: p.status, profile_picture: p.profile_picture, total: 0, group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#999' }
    ex.total += Number(e.amount_usd)
    earnerMap.set(p.id, ex)
  }
  const topEarners = Array.from(earnerMap.values()).sort((a, b) => b.total - a.total).slice(0, 20)
  const myRank = topEarners.findIndex(e => e.id === profile.id) + 1

  // Group earnings
  const groupMap = new Map<string, any>()
  for (const e of (groupEarningsRaw ?? [])) {
    const p = (e as any).profiles
    if (!p?.color_groups) continue
    const ex = groupMap.get(p.color_groups.name) ?? { name: p.color_groups.name, hex_color: p.color_groups.hex_color, total: 0 }
    ex.total += Number(e.amount_usd)
    groupMap.set(p.color_groups.name, ex)
  }
  const groupEarnings = Array.from(groupMap.values()).sort((a, b) => b.total - a.total)

  // Top 3 scouts today
  const scoutMap = new Map<string, any>()
  for (const s of (todayScouts ?? [])) {
    const p = (s as any).profiles
    if (!p) continue
    const ex = scoutMap.get(p.id) ?? { id: p.id, full_name: p.full_name, member_id: p.member_id, profile_picture: p.profile_picture, group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#999', count: 0 }
    ex.count++
    scoutMap.set(p.id, ex)
  }
  const topScoutsToday = Array.from(scoutMap.values()).sort((a, b) => b.count - a.count).slice(0, 3)

  // Scouting by color group
  const groupScoutMap = new Map<string, any>()
  for (const s of (groupScouts ?? [])) {
    const p = (s as any).profiles
    if (!p?.color_groups) continue
    const ex = groupScoutMap.get(p.color_groups.name) ?? { name: p.color_groups.name, hex_color: p.color_groups.hex_color, count: 0 }
    ex.count++
    groupScoutMap.set(p.color_groups.name, ex)
  }
  const groupScoutLeaderboard = Array.from(groupScoutMap.values()).sort((a, b) => b.count - a.count)

  // Consistent earner leaderboard
  const pointsMap = new Map<string, any>()
  for (const ep of (consistentPoints ?? [])) {
    const p = (ep as any).profiles
    if (!p) continue
    const ex = pointsMap.get(p.id) ?? { id: p.id, full_name: p.full_name, member_id: p.member_id, profile_picture: p.profile_picture, group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#999', totalPoints: 0, months: 0 }
    ex.totalPoints += ep.points
    ex.months++
    pointsMap.set(p.id, ex)
  }
  const consistentEarners = Array.from(pointsMap.values()).sort((a, b) => b.totalPoints - a.totalPoints).slice(0, 20)

  // Top Punctuality: average minutes ahead of the sign-in window opening.
  // Higher = earlier/more punctual. Only counts day-session sign-ins.
  const punctualityMap = new Map<string, { id: string; full_name: string; member_id: string; profile_picture: string | null; group_name: string; group_color: string; totalMinutesEarly: number; days: number }>()
  for (const r of (punctualityRaw ?? [])) {
    const p = (r as any).profiles
    if (!p) continue
    const signIn = new Date(r.sign_in_time as string)
    const dayOfWeek = new Date(r.date + 'T00:00:00').getDay() // 0=Sun..5=Fri..6=Sat
    const rule = dayOfWeek === 5 ? ATTENDANCE_RULES.friday : ATTENDANCE_RULES.weekday
    const [openH, openM] = rule.sign_in_open.split(':').map(Number)
    const windowOpen = new Date(signIn)
    windowOpen.setHours(openH, openM, 0, 0)
    const minutesEarly = (windowOpen.getTime() - signIn.getTime()) / 60000
    const ex = punctualityMap.get(p.id) ?? {
      id: p.id, full_name: p.full_name, member_id: p.member_id, profile_picture: p.profile_picture,
      group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#999',
      totalMinutesEarly: 0, days: 0,
    }
    ex.totalMinutesEarly += minutesEarly
    ex.days += 1
    punctualityMap.set(p.id, ex)
  }
  const topPunctuality = Array.from(punctualityMap.values())
    .map(e => ({ ...e, avgMinutesEarly: Math.round(e.totalMinutesEarly / e.days) }))
    .sort((a, b) => b.avgMinutesEarly - a.avgMinutesEarly)
    .slice(0, 20)
  const myTotalPoints = (myPoints ?? []).reduce((s, p) => s + p.points, 0)

  const settingsMap = Object.fromEntries((settings ?? []).map(s => [s.key, s.value]))

  // Members Start This Month: people you directly sponsored who just started this month
  const allTeamProfiles = allProfilesForTeam ?? []
  const memberStartsThisMonth = allTeamProfiles.filter(
    p => p.sponsor_id === profile.id && p.is_new_member && p.new_member_month === thisMonthStr
  ).length

  // Team Starts / SM Team Starts: everyone in your downline up to (not including) the
  // next Senior Manager boundary — same rule for members and Senior Managers alike.
  const isSMOrAbove = isSmOrAbove(profile.status)
  const myTeamIds = computeTeam(profile.id, 'senior_manager' as any, allTeamProfiles as any)
  const teamStartsThisMonth = allTeamProfiles.filter(
    p => myTeamIds.includes(p.id) && p.is_new_member && p.new_member_month === thisMonthStr
  ).length

  return (
    <DashboardClient
      profile={profile}
      range={range}
      myAttendanceDays={(myAttendance ?? []).length}
      myTotalEarnings={(myEarnings ?? []).reduce((s, e) => s + Number(e.amount_usd), 0)}
      myScoutingCount={myScoutingCount ?? 0}
      myRank={myRank}
      myTotalPoints={myTotalPoints}
      todayAttendanceCount={todayAttendance?.length ?? 0}
      todayAttendees={(todayAttendance ?? []).map((a: any) => a.profiles)}
      newMembersCount={newMembersCount ?? 0}
      topEarners={topEarners}
      groupEarnings={groupEarnings}
      colorGroups={colorGroups ?? []}
      isAdmin={isAdmin}
      isEMOrBelow={isEMOrBelow}
      settingsMap={settingsMap}
      topScoutsToday={topScoutsToday}
      groupScoutLeaderboard={groupScoutLeaderboard}
      consistentEarners={consistentEarners}
      topPunctuality={topPunctuality}
      memberStartsThisMonth={memberStartsThisMonth}
      teamStartsThisMonth={teamStartsThisMonth}
      isSMOrAbove={isSMOrAbove}
      isViewingAs={isViewingAs}
      viewAsName={viewAsName}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/member/[id]"
cat > "app/(app)/member/[id]/MemberDetailClient.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Profile } from '@/lib/types'
import { getStatusLabel, getStatusColor, STATUS_ORDER } from '@/lib/types'
import { formatCurrency } from '@/lib/utils'
import { TrendingUp, Target, Users, Zap, Star, ArrowLeft, Pencil } from 'lucide-react'

const RANGES = [
  { value: 'today', label: 'Today' },
  { value: 'yesterday', label: 'Yesterday' },
  { value: 'this_week', label: 'This Week' },
  { value: 'last_7_days', label: 'Last 7 Days' },
  { value: 'this_month', label: 'This Month' },
  { value: 'last_3_months', label: 'Last 3 Months' },
  { value: 'all_time', label: 'All Time' },
]

export default function MemberDetailClient({
  viewer, target, canEdit, range,
  totalEarnings, scoutingCount, teamSize, memberStartsThisMonth, teamStartsThisMonth,
  totalPoints, fullDownline, sponsorOptions,
}: {
  viewer: Profile
  target: Profile & { color_groups?: any; sponsor?: any }
  canEdit: boolean
  range: string
  totalEarnings: number
  scoutingCount: number
  teamSize: number
  memberStartsThisMonth: number
  teamStartsThisMonth: number
  totalPoints: number
  fullDownline: any[]
  sponsorOptions: { id: string; full_name: string; member_id: string | null }[]
}) {
  const router = useRouter()
  const [editing, setEditing] = useState(false)
  const [saving, setSaving] = useState(false)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [form, setForm] = useState({
    full_name: target.full_name,
    status: target.status,
    week_number: target.week_number ?? 1,
    sponsor_id: target.sponsor_id ?? '',
  })

  const cg = (target as any).color_groups

  function changeRange(r: string) {
    router.push(`/member/${target.id}?range=${r}`)
  }

  async function save() {
    setSaving(true)
    setMsg(null)
    const payload = { ...form, sponsor_id: form.sponsor_id || null }
    const res = await fetch('/api/update-profile', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: target.id, actor_id: viewer.id, updates: payload }),
    })
    const json = await res.json()
    setSaving(false)
    if (!res.ok) {
      setMsg({ type: 'error', text: json.error ?? 'Failed to save' })
      return
    }
    setMsg({ type: 'success', text: 'Saved.' })
    setEditing(false)
    router.refresh()
  }

  // Build a shallow tree (direct downline grouped by sponsor) for display
  function renderStructure(parentId: string, depth = 0): React.ReactNode {
    const children = fullDownline.filter(p => p.sponsor_id === parentId)
    if (!children.length) return null
    return (
      <div style={{ marginLeft: depth ? 16 : 0 }} className={depth ? 'border-l border-gray-100 pl-3 mt-1' : ''}>
        {children.map(c => (
          <div key={c.id}>
            <div className="flex items-center gap-2 py-1.5">
              <div className="w-6 h-6 rounded-full flex items-center justify-center text-white text-[10px] font-bold flex-shrink-0"
                style={{ backgroundColor: '#6366f1' }}>
                {c.full_name?.charAt(0)}
              </div>
              <button className="text-sm text-gray-700 hover:text-brand-600 truncate" onClick={() => router.push(`/member/${c.id}`)}>
                {c.full_name}
              </button>
              <span className={`badge text-[10px] ${getStatusColor(c.status)}`}>{getStatusLabel(c.status)}</span>
            </div>
            {renderStructure(c.id, depth + 1)}
          </div>
        ))}
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto space-y-5">
      <button onClick={() => router.back()} className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700">
        <ArrowLeft size={16} /> Back
      </button>

      <div className="card p-5 flex items-start justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-full flex items-center justify-center text-white text-xl font-bold flex-shrink-0"
            style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
            {target.profile_picture ? (
              <img src={target.profile_picture} alt={target.full_name} className="w-16 h-16 rounded-full object-cover" />
            ) : target.full_name?.charAt(0)}
          </div>
          <div>
            <h1 className="text-lg font-bold text-gray-900">{target.full_name}</h1>
            <p className="text-xs text-gray-400">{target.member_id ?? 'No ID yet'} · {cg?.name ?? 'No group'}</p>
            <span className={`badge text-xs mt-1 ${getStatusColor(target.status)}`}>{getStatusLabel(target.status)}</span>
            {target.sponsor && (
              <p className="text-xs text-gray-400 mt-1">Sponsor: {target.sponsor.full_name}</p>
            )}
          </div>
        </div>
        {canEdit && (
          <button onClick={() => setEditing(v => !v)} className="btn-secondary text-sm flex items-center gap-1.5">
            <Pencil size={14} /> {editing ? 'Cancel' : 'Edit'}
          </button>
        )}
      </div>

      {editing && canEdit && (
        <div className="card p-5 space-y-3">
          <div>
            <label className="text-xs text-gray-500">Full Name</label>
            <input className="input" value={form.full_name} onChange={e => setForm(f => ({ ...f, full_name: e.target.value }))} />
          </div>
          <div>
            <label className="text-xs text-gray-500">Status</label>
            <select className="input" value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value as any }))}>
              {STATUS_ORDER.map(s => <option key={s} value={s}>{getStatusLabel(s)}</option>)}
            </select>
          </div>
          <div>
            <label className="text-xs text-gray-500">Current Week (12-week program)</label>
            <input type="number" min={1} max={12} className="input" value={form.week_number}
              onChange={e => setForm(f => ({ ...f, week_number: Number(e.target.value) }))} />
          </div>
          <div>
            <label className="text-xs text-gray-500">Sponsor</label>
            <select className="input" value={form.sponsor_id} onChange={e => setForm(f => ({ ...f, sponsor_id: e.target.value }))}>
              <option value="">No sponsor</option>
              {sponsorOptions.map(s => (
                <option key={s.id} value={s.id}>{s.full_name} {s.member_id ? `(${s.member_id})` : ''}</option>
              ))}
            </select>
          </div>
          <button className="btn-primary text-sm" disabled={saving} onClick={save}>
            {saving ? 'Saving…' : 'Save Changes'}
          </button>
          {msg && <p className={`text-xs ${msg.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>{msg.text}</p>}
          <p className="text-xs text-gray-400">To change color or profile picture, use the People page.</p>
        </div>
      )}

      {/* Range filter */}
      <div className="flex gap-2 flex-wrap">
        {RANGES.map(r => (
          <button key={r.value} onClick={() => changeRange(r.value)}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${range === r.value ? 'bg-brand-600 text-white' : 'bg-white border border-gray-200 text-gray-600 hover:border-brand-300'}`}>
            {r.label}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <StatCard icon={<TrendingUp size={16} />} label="Earnings" value={formatCurrency(totalEarnings)} />
        <StatCard icon={<Target size={16} />} label="Businesses Scouted" value={scoutingCount} />
        <StatCard icon={<Users size={16} />} label="Team Size" value={teamSize} />
        <StatCard icon={<Zap size={16} />} label="Members Start" value={memberStartsThisMonth} sub="this month, direct" />
        <StatCard icon={<Users size={16} />} label="Team Starts" value={teamStartsThisMonth} sub="this month" />
        <StatCard icon={<Star size={16} />} label="Consistency Points" value={totalPoints} sub="all time" />
      </div>

      <div className="card p-5">
        <h2 className="text-sm font-semibold text-gray-900 mb-3">Team Structure</h2>
        {fullDownline.length === 0 ? (
          <p className="text-sm text-gray-400">No downline yet.</p>
        ) : renderStructure(target.id)}
      </div>
    </div>
  )
}

function StatCard({ icon, label, value, sub }: { icon: React.ReactNode; label: string; value: string | number; sub?: string }) {
  return (
    <div className="card p-4">
      <div className="flex items-center gap-2 text-gray-400 mb-1.5">{icon}<span className="text-xs font-medium">{label}</span></div>
      <div className="text-xl font-bold text-gray-900">{value}</div>
      {sub && <div className="text-xs text-gray-400 mt-0.5">{sub}</div>}
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/member/[id]"
cat > "app/(app)/member/[id]/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect, notFound } from 'next/navigation'
import { computeTeam } from '@/lib/types'
import { format, startOfMonth, endOfMonth, startOfWeek, endOfWeek, subDays, subMonths } from 'date-fns'
import MemberDetailClient from './MemberDetailClient'

// Full downline regardless of rank boundary (used for group-visibility checks
// and the "team structure" listing) — computeTeam() is boundary-aware and
// would incorrectly return an empty set if passed a non-status sentinel.
function getFullDownline(rootId: string, allProfiles: { id: string; sponsor_id: string | null }[]): string[] {
  const direct = allProfiles.filter(p => p.sponsor_id === rootId).map(p => p.id)
  return [...direct, ...direct.flatMap(id => getFullDownline(id, allProfiles))]
}

export default async function MemberDetailPage({
  params, searchParams,
}: {
  params: { id: string }
  searchParams: { range?: string }
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: viewer } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*)')
    .eq('id', user.id)
    .single()
  if (!viewer) redirect('/login')

  const targetId = params.id

  const { data: target } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*), sponsor:sponsor_id(id, full_name, member_id)')
    .eq('id', targetId)
    .single()
  if (!target) notFound()

  // --- Permission check: mirror the same hierarchy rules used on the People page ---
  const isSelf = target.id === viewer.id
  const viewerIsMainAdmin = viewer.is_admin
  const viewerIsDirectorOnly = viewer.is_director && !viewer.is_admin
  const viewerIsCoAdminOnly = viewer.is_co_admin && !viewer.is_admin && !viewer.is_director
  const viewerIsAdminTier = viewerIsMainAdmin || viewerIsDirectorOnly || viewerIsCoAdminOnly

  let allowed = isSelf
  if (!allowed && viewerIsAdminTier) {
    if (viewerIsMainAdmin) allowed = true
    else if (viewerIsDirectorOnly) allowed = !target.is_admin
    else if (viewerIsCoAdminOnly) allowed = !target.is_admin && !target.is_director
  }
  if (!allowed && !viewerIsAdminTier) {
    // Regular members: can view anyone in their own color group, or anyone in their downline
    const sameGroup = viewer.color_group_id && target.color_group_id === viewer.color_group_id
    if (sameGroup) allowed = true
    if (!allowed) {
      const { data: allProfiles } = await supabase
        .from('profiles')
        .select('id, sponsor_id, status')
        .eq('approved', true)
      const downlineIds = getFullDownline(viewer.id, (allProfiles ?? []) as any)
      allowed = downlineIds.includes(target.id)
    }
  }
  if (!allowed) redirect('/dashboard')

  const canEdit = viewerIsAdminTier && !isSelf

  // --- Date range for earnings/scouting filter ---
  const range = searchParams.range ?? 'this_month'
  const now = new Date()
  let rangeStart: Date, rangeEnd: Date
  if (range === 'today') { rangeStart = now; rangeEnd = now }
  else if (range === 'yesterday') { rangeStart = subDays(now, 1); rangeEnd = subDays(now, 1) }
  else if (range === 'this_week') { rangeStart = startOfWeek(now, { weekStartsOn: 1 }); rangeEnd = endOfWeek(now, { weekStartsOn: 1 }) }
  else if (range === 'last_7_days') { rangeStart = subDays(now, 6); rangeEnd = now }
  else if (range === 'last_3_months') { rangeStart = startOfMonth(subMonths(now, 2)); rangeEnd = endOfMonth(now) }
  else if (range === 'all_time') { rangeStart = new Date(2020, 0, 1); rangeEnd = now }
  else { rangeStart = startOfMonth(now); rangeEnd = endOfMonth(now) } // this_month default

  const rangeStartStr = format(rangeStart, 'yyyy-MM-dd')
  const rangeEndStr = format(rangeEnd, 'yyyy-MM-dd')
  const thisMonthStr = format(now, 'yyyy-MM')

  const [
    { data: earnings },
    { data: scouting, count: scoutingCount },
    { data: allProfiles },
    { data: earnerPoints },
  ] = await Promise.all([
    supabase.from('weekly_earnings')
      .select('amount_usd, week_start, week_end')
      .eq('user_id', targetId)
      .gte('week_start', rangeStartStr)
      .lte('week_end', rangeEndStr),

    supabase.from('scouting_records')
      .select('id', { count: 'exact' })
      .eq('user_id', targetId)
      .gte('scouted_at', rangeStartStr)
      .lte('scouted_at', rangeEndStr + 'T23:59:59'),

    supabase.from('profiles')
      .select('id, sponsor_id, status, full_name, member_id, is_new_member, new_member_month, profile_picture, color_group_id')
      .eq('approved', true),

    supabase.from('earner_points')
      .select('points, month_str')
      .eq('user_id', targetId),
  ])

  const totalEarnings = (earnings ?? []).reduce((sum, e) => sum + Number(e.amount_usd), 0)
  const allTeamProfiles = allProfiles ?? []

  // Team / SM Team (same boundary rule as dashboard)
  const teamIds = computeTeam(targetId, 'senior_manager' as any, allTeamProfiles as any)
  const teamSize = teamIds.length
  const memberStartsThisMonth = allTeamProfiles.filter(
    p => p.sponsor_id === targetId && p.is_new_member && p.new_member_month === thisMonthStr
  ).length
  const teamStartsThisMonth = allTeamProfiles.filter(
    p => teamIds.includes(p.id) && p.is_new_member && p.new_member_month === thisMonthStr
  ).length

  // Full downline for "team structure" display (every level, not just SM boundary)
  const fullDownline = allTeamProfiles.filter(p => getFullDownline(targetId, allTeamProfiles as any).includes(p.id))

  const totalPoints = (earnerPoints ?? []).reduce((sum, p) => sum + (p.points ?? 0), 0)

  return (
    <MemberDetailClient
      viewer={viewer}
      target={target}
      canEdit={canEdit}
      range={range}
      totalEarnings={totalEarnings}
      scoutingCount={scoutingCount ?? 0}
      teamSize={teamSize}
      memberStartsThisMonth={memberStartsThisMonth}
      teamStartsThisMonth={teamStartsThisMonth}
      totalPoints={totalPoints}
      fullDownline={fullDownline as any[]}
      sponsorOptions={allTeamProfiles
        .filter(p => p.id !== targetId)
        .map(p => ({ id: p.id, full_name: (p as any).full_name, member_id: (p as any).member_id }))}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/people"
cat > "app/(app)/people/PeopleClient.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ColorGroup, ActivityStatus } from '@/lib/types'
import { getStatusLabel, getStatusColor, formatDate } from '@/lib/utils'
import { ACTIVITY_STATUS_LABELS, ACTIVITY_STATUS_COLORS } from '@/lib/types'
import { Check, X, Search, ChevronDown, ChevronRight, Shield, UserX, UserCheck, Eye } from 'lucide-react'

const ACTIVITY_OPTIONS: ActivityStatus[] = [
  'active', 'suspended', 'inactive', 'left_office', 'another_location', 'moved_to_another_office'
]

export default function PeopleClient({
  currentProfile, allProfiles, pendingProfiles, colorGroups, isMainAdmin, mainAdminId,
}: {
  currentProfile: Profile
  allProfiles: Profile[]
  pendingProfiles: Profile[]
  colorGroups: ColorGroup[]
  isMainAdmin: boolean
  mainAdminId: string | null
}) {
  const [tab, setTab] = useState<'active' | 'pending' | 'inactive' | 'tree' | 'add'>('active')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [loading, setLoading] = useState<string | null>(null)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [selectedProfile, setSelectedProfile] = useState<Profile | null>(null)
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  const [confirmAction, setConfirmAction] = useState<{ type: 'approve' | 'reject' | 'delete'; profile: Profile } | null>(null)
  const [rejectReason, setRejectReason] = useState('')
  const [deleteConfirmName, setDeleteConfirmName] = useState('')
  const [addForm, setAddForm] = useState({
    full_name: '', email: '', phone: '', status: 'member',
    color_group_id: '', sponsor_id: '', week_number: 1,
  })
  const [addLoading, setAddLoading] = useState(false)
  const isDirector = currentProfile.is_director && !isMainAdmin
  const isCoAdmin = currentProfile.is_co_admin && !isMainAdmin && !currentProfile.is_director

  // Hide main admin from everyone but main admin; hide Directors from Co-Admins
  // (no one can view or edit someone above them in the hierarchy)
  const visibleProfiles = allProfiles.filter(p => {
    if (!isMainAdmin && p.id === mainAdminId) return false
    if (isCoAdmin && p.is_director) return false
    return true
  })

  // Active vs inactive split
  const activeProfiles = visibleProfiles.filter(p => p.approved && !p.rejected && p.activity_status === 'active')
  const inactiveProfiles = visibleProfiles.filter(p => p.approved && !p.rejected && p.activity_status !== 'active')
  const rejectedProfiles = visibleProfiles.filter(p => p.rejected)

  // Color group → senior manager check
  function getSeniorManagerInColor(colorGroupId: string, excludeId?: string): Profile | null {
    return visibleProfiles.find(p =>
      p.color_group_id === colorGroupId &&
      p.status === 'senior_manager' &&
      p.approved &&
      p.id !== excludeId
    ) || null
  }

  // Downline builder
  function getDownline(rootId: string, profiles: Profile[]): string[] {
    const direct = profiles.filter(p => p.sponsor_id === rootId).map(p => p.id)
    return [...direct, ...direct.flatMap(id => getDownline(id, profiles))]
  }

  // Can this admin delete this person?
  function canDelete(target: Profile): boolean {
    if (isMainAdmin) return true
    if (target.rejected) return true // anyone can delete rejected
    if (isCoAdmin && target.added_by === currentProfile.id) return true
    if (isDirector && !target.approved) return true
    return false
  }

  // Can override sponsor/color?
  const canOverride = isMainAdmin || isDirector

  // ── ACTIONS ────────────────────────────────────────────────────────────────

  async function confirmApprove(p: Profile) {
    setLoading(p.id)
    setMsg(null)
    const supabase = createClient()
    const colorGroup = colorGroups.find(g => g.id === p.color_group_id)
    let memberId = null
    if (colorGroup) {
      const { data: seqData } = await supabase.rpc('generate_member_id', { p_color_code: colorGroup.code })
      memberId = seqData
      await supabase.from('color_groups').update({ member_count: colorGroup.member_count + 1 }).eq('id', colorGroup.id)
    }
    const { error } = await supabase.from('profiles')
      .update({ approved: true, rejected: false, member_id: memberId, added_by: currentProfile.id })
      .eq('id', p.id)
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: `✓ Approved! Member ID: ${memberId ?? 'N/A'}` })
      // Notify the new member
      await supabase.from('notifications').insert({
        user_id: p.id,
        title: 'Application Approved!',
        body: `Welcome to Elevate! Your member ID is ${memberId ?? 'assigned'}. You can now access all features.`,
        type: 'success',
        link: '/dashboard',
      })
      setTimeout(() => window.location.reload(), 1500)
    }
    setConfirmAction(null)
    setLoading(null)
  }

  async function confirmReject(p: Profile) {
    setLoading(p.id)
    const supabase = createClient()
    await supabase.from('profiles').update({ rejected: true, rejection_reason: rejectReason || null }).eq('id', p.id)
    // Notify the rejected person
    await supabase.from('notifications').insert({
      user_id: p.id,
      title: 'Application Status Update',
      body: rejectReason ? `Your application was not approved: ${rejectReason}` : 'Your application was not approved at this time.',
      type: 'error',
    })
    setMsg({ type: 'success', text: `${p.full_name} rejected.` })
    setConfirmAction(null)
    setRejectReason('')
    setTimeout(() => window.location.reload(), 1200)
    setLoading(null)
  }

  async function confirmDelete(p: Profile) {
    // Main admin requires name confirmation
    if (isMainAdmin && deleteConfirmName.trim().toLowerCase() !== p.full_name.toLowerCase()) {
      setMsg({ type: 'error', text: 'Name does not match. Type the exact name to confirm.' })
      return
    }
    setLoading(p.id)
    const supabase = createClient()
    const { error } = await supabase.from('profiles').delete().eq('id', p.id)
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: `${p.full_name} deleted.` })
      setConfirmAction(null)
      setDeleteConfirmName('')
      setTimeout(() => window.location.reload(), 1000)
    }
    setLoading(null)
  }

  async function updateProfile(profileId: string, updates: Record<string, unknown>) {
    const supabase = createClient()
    const { error } = await supabase.from('profiles').update(updates).eq('id', profileId)
    if (error) { setMsg({ type: 'error', text: error.message }); return }
    setMsg({ type: 'success', text: 'Updated!' })
    if (selectedProfile?.id === profileId) {
      setSelectedProfile(prev => prev ? { ...prev, ...updates } as Profile : null)
    }
    setTimeout(() => window.location.reload(), 800)
  }

  async function assignColor(profileId: string, colorGroupId: string, currentStatus: string) {
    // Enforce: no two senior managers in same color
    if (currentStatus === 'senior_manager') {
      const existing = getSeniorManagerInColor(colorGroupId, profileId)
      if (existing) {
        setMsg({ type: 'error', text: `${existing.full_name} is already Senior Manager in this color group. Two Senior Managers cannot share a color.` })
        return
      }
    }
    await updateProfile(profileId, { color_group_id: colorGroupId })
  }

  async function toggleCoAdmin(profileId: string, current: boolean) {
    if (!isMainAdmin) return
    await updateProfile(profileId, { is_co_admin: !current })
    // Notify the person
    const supabase = createClient()
    await supabase.from('notifications').insert({
      user_id: profileId,
      title: !current ? 'Co-Admin Access Granted' : 'Co-Admin Access Removed',
      body: !current
        ? 'You have been granted co-admin access. You can now approve new members.'
        : 'Your co-admin access has been removed.',
      type: !current ? 'success' : 'info',
    })
  }

  async function setActivityStatus(profileId: string, status: ActivityStatus) {
    await updateProfile(profileId, { activity_status: status })
  }

  async function addMemberManually() {
    setAddLoading(true)
    setMsg(null)
    const tempPassword = `Elevate${Math.random().toString(36).slice(2, 8).toUpperCase()}!`
    const res = await fetch('/api/admin/create-user', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...addForm, temp_password: tempPassword, added_by: currentProfile.id }),
    })
    const result = await res.json()
    if (!res.ok) setMsg({ type: 'error', text: result.error ?? 'Failed' })
    else { setMsg({ type: 'success', text: `Created! Temp password: ${tempPassword}` }); setTab('active'); setTimeout(() => window.location.reload(), 2000) }
    setAddLoading(false)
  }

  // ── PROFILE CARD ──────────────────────────────────────────────────────────

  function ProfileCard({ p }: { p: Profile }) {
    const colorGroup = colorGroups.find(g => g.id === p.color_group_id)
    const sponsor = allProfiles.find(s => s.id === p.sponsor_id)
    const actStatus = (p.activity_status || 'active') as ActivityStatus

    return (
      <div className="card p-5 space-y-4">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-3">
            {p.profile_picture
              ? <img src={p.profile_picture} className="w-12 h-12 rounded-full object-cover" />
              : <div className="w-12 h-12 rounded-full flex items-center justify-center font-bold text-lg text-white" style={{ backgroundColor: colorGroup?.hex_color ?? '#6366f1' }}>{p.full_name.charAt(0)}</div>
            }
            <div>
              <button className="font-bold text-gray-900 hover:text-brand-600 hover:underline text-left" onClick={() => window.open(`/member/${p.id}`, '_blank')}>
                {p.full_name}
              </button>
              <div className="text-sm text-gray-400">{p.member_id ?? 'No ID'} · {p.email}</div>
              <div className="flex gap-1.5 mt-1 flex-wrap">
                <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                <span className={`badge ${ACTIVITY_STATUS_COLORS[actStatus]}`}>{ACTIVITY_STATUS_LABELS[actStatus]}</span>
                {p.is_co_admin && <span className="badge bg-purple-100 text-purple-700">Co-Admin</span>}
              </div>
            </div>
          </div>
          <div className="flex gap-2">
            {isMainAdmin && p.id !== currentProfile.id && (
              <button onClick={async () => {
                await fetch('/api/admin/view-as', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ target_id: p.id }),
                })
                window.location.href = '/dashboard'
              }} className="btn-icon text-purple-400 hover:text-purple-600" title={`View app as ${p.full_name}`}>
                <Eye size={16} />
              </button>
            )}
            <button onClick={e => { e.stopPropagation(); setSelectedProfile(null) }}
              className="btn-icon text-gray-400 hover:text-gray-600" title="Close">
              <X size={16} />
            </button>
            {canDelete(p) && (
              <button onClick={() => { setConfirmAction({ type: 'delete', profile: p }); setDeleteConfirmName('') }}
                className="btn-icon text-red-400 hover:text-red-600" title="Delete">
                <UserX size={16} />
              </button>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {/* Color Group — admin/director can override */}
          <div>
            <label className="label">Color Group</label>
            {canOverride ? (
              <select className="input" value={p.color_group_id ?? ''} onChange={e => assignColor(p.id, e.target.value, p.status)}>
                <option value="">No group</option>
                {colorGroups.map(g => {
                  const smInGroup = getSeniorManagerInColor(g.id, p.id)
                  const blocked = p.status === 'senior_manager' && !!smInGroup
                  return (
                    <option key={g.id} value={g.id} disabled={blocked}>
                      {g.name}{blocked ? ` (SM: ${smInGroup!.full_name})` : ''}
                    </option>
                  )
                })}
              </select>
            ) : (
              <div className="flex items-center gap-2 text-sm">
                {colorGroup && <div className="w-3 h-3 rounded-full" style={{ backgroundColor: colorGroup.hex_color }} />}
                {colorGroup?.name ?? '—'}
              </div>
            )}
          </div>

          {/* Sponsor — admin/director can override */}
          <div>
            <label className="label">Sponsor</label>
            {canOverride ? (
              <select className="input" value={p.sponsor_id ?? ''} onChange={e => updateProfile(p.id, { sponsor_id: e.target.value || null })}>
                <option value="">No sponsor</option>
                {visibleProfiles.filter(s => s.id !== p.id && s.approved).map(s => (
                  <option key={s.id} value={s.id}>{s.full_name} ({s.member_id ?? 'no ID'})</option>
                ))}
              </select>
            ) : (
              <div className="text-sm">{sponsor?.full_name ?? '—'}</div>
            )}
          </div>

          {/* Activity Status */}
          <div>
            <label className="label">Activity Status</label>
            <select className="input" value={actStatus} onChange={e => setActivityStatus(p.id, e.target.value as ActivityStatus)}>
              {ACTIVITY_OPTIONS.map(o => <option key={o} value={o}>{ACTIVITY_STATUS_LABELS[o]}</option>)}
            </select>
          </div>

          {/* Week number */}
          <div>
            <label className="label">Week Number</label>
            <input type="number" className="input" defaultValue={p.week_number ?? 1} min={1}
              onBlur={e => updateProfile(p.id, { week_number: parseInt(e.target.value) })} />
          </div>
        </div>

        {/* Co-admin toggle — main admin only */}
        {isMainAdmin && p.id !== currentProfile.id && (
          <div className="flex items-center gap-3 pt-2 border-t border-gray-100">
            <Shield size={15} className="text-purple-500" />
            <span className="text-sm text-gray-700 flex-1">Co-Admin Access</span>
            <button onClick={() => toggleCoAdmin(p.id, p.is_co_admin)}
              className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all ${p.is_co_admin ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-purple-50'}`}>
              {p.is_co_admin ? 'Remove Co-Admin' : 'Make Co-Admin'}
            </button>
          </div>
        )}
      </div>
    )
  }

  // ── TREE VIEW ─────────────────────────────────────────────────────────────

  function TreeNode({ profileId, depth = 0 }: { profileId: string; depth?: number }) {
    const p = allProfiles.find(x => x.id === profileId)
    if (!p) return null
    const children = allProfiles.filter(x => x.sponsor_id === profileId && x.approved)
    const expanded = expandedNodes.has(profileId)
    const colorGroup = colorGroups.find(g => g.id === p.color_group_id)

    return (
      <div style={{ marginLeft: depth * 20 }}>
        <div className="flex items-center gap-2 py-1.5 px-2 rounded-lg hover:bg-gray-50 cursor-pointer"
          onClick={() => {
            setExpandedNodes(prev => { const n = new Set(prev); n.has(profileId) ? n.delete(profileId) : n.add(profileId); return n })
            setSelectedProfile(p)
          }}>
          {children.length > 0
            ? (expanded ? <ChevronDown size={14} className="text-gray-400" /> : <ChevronRight size={14} className="text-gray-400" />)
            : <div className="w-3.5" />
          }
          <div className="w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold text-white flex-shrink-0"
            style={{ backgroundColor: colorGroup?.hex_color ?? '#6366f1' }}>
            {p.full_name.charAt(0)}
          </div>
          <div className="flex-1 min-w-0">
            <span className="text-sm font-medium text-gray-900">{p.full_name}</span>
            <span className="text-xs text-gray-400 ml-2">{p.member_id ?? ''} · {getStatusLabel(p.status)}</span>
          </div>
          {children.length > 0 && <span className="text-xs text-gray-400">{children.length} direct</span>}
        </div>
        {expanded && children.map(c => <TreeNode key={c.id} profileId={c.id} depth={depth + 1} />)}
      </div>
    )
  }

  // ── SEARCH FILTER ─────────────────────────────────────────────────────────

  function filterProfiles(list: Profile[]) {
    return list.filter(p => {
      const q = search.toLowerCase()
      const matchSearch = !q || p.full_name.toLowerCase().includes(q) || (p.member_id ?? '').toLowerCase().includes(q) || p.email.toLowerCase().includes(q)
      const matchStatus = statusFilter === 'all' || p.status === statusFilter
      return matchSearch && matchStatus
    })
  }

  const filtered = filterProfiles(tab === 'active' ? activeProfiles : tab === 'inactive' ? inactiveProfiles : [])

  // ── TABS ─────────────────────────────────────────────────────────────────

  const tabs = [
    { id: 'active', label: `Active (${activeProfiles.length})` },
    { id: 'pending', label: `Pending (${pendingProfiles.length})` },
    { id: 'inactive', label: `Inactive (${inactiveProfiles.length})` },
    { id: 'tree', label: 'Tree View' },
    { id: 'add', label: '+ Add Member' },
  ]

  return (
    <div className="max-w-6xl mx-auto space-y-5">
      {msg && (
        <div className={`px-4 py-3 rounded-xl text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {tabs.map(t => (
          <button key={t.id} onClick={() => { setTab(t.id as any); setSelectedProfile(null) }}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* Search + status filter */}
      {(tab === 'active' || tab === 'inactive') && (
        <div className="flex gap-3 flex-wrap">
          <div className="relative flex-1 max-w-sm">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input className="input pl-8" placeholder="Search name, ID, email…" value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <select className="input w-auto" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
            <option value="all">All Statuses</option>
            {['member','distributor','manager','senior_manager','executive_manager','director'].map(s => (
              <option key={s} value={s}>{getStatusLabel(s as any)}</option>
            ))}
          </select>
        </div>
      )}

      {/* ACTIVE TAB */}
      {tab === 'active' && (
        <div className="grid grid-cols-1 gap-4">
          {filtered.length === 0
            ? <p className="text-sm text-gray-400 text-center py-12">No active members found</p>
            : filtered.map(p => (
              <div key={p.id}>
                {selectedProfile?.id === p.id
                  ? <div onClick={e => e.stopPropagation()}><ProfileCard p={p} /></div>
                  : (
                    <button
                      type="button"
                      className="w-full card p-4 flex items-center gap-3 hover:shadow-md transition-shadow text-left"
                      onClick={e => { e.stopPropagation(); setSelectedProfile(p); setMsg(null) }}
                    >
                      <div className="w-9 h-9 rounded-full flex items-center justify-center font-bold text-white text-sm flex-shrink-0"
                        style={{ backgroundColor: colorGroups.find(g => g.id === p.color_group_id)?.hex_color ?? '#6366f1' }}>
                        {p.full_name.charAt(0)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="font-semibold text-gray-900 truncate">{p.full_name}</div>
                        <div className="text-xs text-gray-400">{p.member_id ?? 'No ID'} · {getStatusLabel(p.status)}</div>
                      </div>
                      {p.is_co_admin && <span className="badge bg-purple-100 text-purple-700 text-xs">Co-Admin</span>}
                      <ChevronRight size={16} className="text-gray-300" />
                    </button>
                  )
                }
              </div>
            ))
          }
        </div>
      )}

      {/* INACTIVE TAB */}
      {tab === 'inactive' && (
        <div className="grid grid-cols-1 gap-4">
          {filtered.length === 0
            ? <p className="text-sm text-gray-400 text-center py-12">No inactive members</p>
            : filtered.map(p => (
              <div key={p.id}>
                {selectedProfile?.id === p.id
                  ? <div onClick={e => e.stopPropagation()}><ProfileCard p={p} /></div>
                  : (
                    <button
                      type="button"
                      className="w-full card p-4 flex items-center gap-3 opacity-70 hover:opacity-100 transition-opacity text-left"
                      onClick={e => { e.stopPropagation(); setSelectedProfile(p); setMsg(null) }}
                    >
                      <div className="w-9 h-9 rounded-full bg-gray-300 flex items-center justify-center font-bold text-white text-sm flex-shrink-0">
                        {p.full_name.charAt(0)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="font-semibold text-gray-700 truncate">{p.full_name}</div>
                        <div className="text-xs text-gray-400">{getStatusLabel(p.status)} · <span className={`${ACTIVITY_STATUS_COLORS[(p.activity_status || 'inactive') as ActivityStatus]}`}>{ACTIVITY_STATUS_LABELS[(p.activity_status || 'inactive') as ActivityStatus]}</span></div>
                      </div>
                      <ChevronRight size={16} className="text-gray-300" />
                    </button>
                  )
                }
              </div>
            ))
          }
        </div>
      )}

      {/* PENDING TAB */}
      {tab === 'pending' && (
        <div className="space-y-4">
          {pendingProfiles.length === 0
            ? <p className="text-sm text-gray-400 text-center py-12">No pending applications</p>
            : pendingProfiles.map(p => (
              <div key={p.id} className="card p-5">
                <div className="flex items-start justify-between gap-3 mb-3">
                  <div>
                    <div className="font-bold text-gray-900">{p.full_name}</div>
                    <div className="text-sm text-gray-400">{p.email} · Applied {formatDate(p.created_at)}</div>
                    <div className="flex gap-1.5 mt-1 flex-wrap">
                      <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                      {(p as any).color_groups && <span className="badge bg-gray-100 text-gray-600">{(p as any).color_groups.name}</span>}
                      {(p as any).sponsor && <span className="badge bg-blue-100 text-blue-700">Sponsor: {(p as any).sponsor.full_name}</span>}
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <button onClick={() => setConfirmAction({ type: 'approve', profile: p })}
                      className="btn-primary text-xs px-3 py-1.5 flex items-center gap-1">
                      <Check size={13} /> Approve
                    </button>
                    <button onClick={() => setConfirmAction({ type: 'reject', profile: p })}
                      className="btn-secondary text-xs px-3 py-1.5 flex items-center gap-1 text-red-600 border-red-200">
                      <X size={13} /> Reject
                    </button>
                    {isMainAdmin && (
                      <button onClick={() => { setConfirmAction({ type: 'delete', profile: p }); setDeleteConfirmName('') }}
                        className="btn-icon text-red-400" title="Delete application">
                        <UserX size={15} />
                      </button>
                    )}
                  </div>
                </div>
                {p.about && <p className="text-sm text-gray-500 bg-gray-50 rounded-lg p-3">{p.about}</p>}
              </div>
            ))
          }

          {/* Rejected section */}
          {rejectedProfiles.length > 0 && (
            <div className="mt-6">
              <h3 className="section-title mb-3 text-red-500">Rejected Applications ({rejectedProfiles.length})</h3>
              {rejectedProfiles.map(p => (
                <div key={p.id} className="card p-4 flex items-center gap-3 opacity-60 mb-2">
                  <div className="flex-1">
                    <div className="font-semibold text-gray-700">{p.full_name}</div>
                    <div className="text-xs text-gray-400">{p.email}</div>
                    {p.rejection_reason && <div className="text-xs text-red-400 mt-0.5">Reason: {p.rejection_reason}</div>}
                  </div>
                  <button onClick={() => { setConfirmAction({ type: 'delete', profile: p }); setDeleteConfirmName('') }}
                    className="btn-icon text-red-400 hover:text-red-600" title="Delete">
                    <UserX size={15} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* TREE VIEW */}
      {tab === 'tree' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div className="card p-5">
            <h2 className="section-title mb-4">Organisation Tree</h2>
            {isMainAdmin ? (
              // Main admin sees full tree from root
              allProfiles.filter(p => !p.sponsor_id && p.approved).map(p => (
                <TreeNode key={p.id} profileId={p.id} />
              ))
            ) : (
              // Directors/others: see tree from any approved member but NOT the main admin as root
              <div>
                <p className="text-xs text-gray-400 mb-3">Click any member to see their downline</p>
                {visibleProfiles.filter(p => p.approved && p.activity_status === 'active').slice(0, 30).map(p => (
                  <TreeNode key={p.id} profileId={p.id} />
                ))}
              </div>
            )}
          </div>
          {selectedProfile && (
            <div>
              <ProfileCard p={selectedProfile} />
            </div>
          )}
        </div>
      )}

      {/* ADD MEMBER */}
      {tab === 'add' && (
        <div className="card p-6 max-w-lg">
          <h2 className="section-title mb-4">Add Member Manually</h2>
          <div className="space-y-3">
            {[
              { label: 'Full Name', key: 'full_name', type: 'text', placeholder: 'John Smith' },
              { label: 'Email', key: 'email', type: 'email', placeholder: 'john@example.com' },
              { label: 'Phone', key: 'phone', type: 'tel', placeholder: '+44 7700 000000' },
            ].map(f => (
              <div key={f.key}>
                <label className="label">{f.label}</label>
                <input type={f.type} className="input" placeholder={f.placeholder}
                  value={(addForm as any)[f.key]} onChange={e => setAddForm(prev => ({ ...prev, [f.key]: e.target.value }))} />
              </div>
            ))}
            <div>
              <label className="label">Status</label>
              <select className="input" value={addForm.status} onChange={e => setAddForm(p => ({ ...p, status: e.target.value }))}>
                {['member','distributor','manager','senior_manager','executive_manager','director'].map(s => (
                  <option key={s} value={s}>{getStatusLabel(s as any)}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Color Group</label>
              <select className="input" value={addForm.color_group_id} onChange={e => setAddForm(p => ({ ...p, color_group_id: e.target.value }))}>
                <option value="">Select group</option>
                {colorGroups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Sponsor</label>
              <select className="input" value={addForm.sponsor_id} onChange={e => setAddForm(p => ({ ...p, sponsor_id: e.target.value }))}>
                <option value="">No sponsor</option>
                {visibleProfiles.filter(p => p.approved).map(p => (
                  <option key={p.id} value={p.id}>{p.full_name} ({p.member_id ?? 'no ID'})</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Starting Week</label>
              <input type="number" className="input" min={1} value={addForm.week_number}
                onChange={e => setAddForm(p => ({ ...p, week_number: parseInt(e.target.value) }))} />
            </div>
            <button onClick={addMemberManually} disabled={addLoading || !addForm.full_name || !addForm.email} className="btn-primary w-full">
              {addLoading ? 'Creating…' : 'Create Member'}
            </button>
            {msg && <div className={`text-sm ${msg.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>{msg.text}</div>}
          </div>
        </div>
      )}

      {/* ── CONFIRM MODALS ─────────────────────────────────────────────────── */}
      {confirmAction && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" onClick={e => { if (e.target === e.currentTarget) setConfirmAction(null) }}>
          <div className="bg-white rounded-2xl p-6 max-w-md w-full shadow-2xl">
            {confirmAction.type === 'approve' && (
              <>
                <h3 className="text-lg font-bold mb-2">Approve {confirmAction.profile.full_name}?</h3>
                <p className="text-sm text-gray-500 mb-4">This will generate their member ID and grant full access.</p>
                <div className="flex gap-3">
                  <button onClick={() => confirmApprove(confirmAction.profile)} className="btn-primary flex-1" disabled={!!loading}>
                    {loading ? 'Processing…' : 'Confirm Approve'}
                  </button>
                  <button onClick={() => setConfirmAction(null)} className="btn-secondary">Cancel</button>
                </div>
              </>
            )}
            {confirmAction.type === 'reject' && (
              <>
                <h3 className="text-lg font-bold mb-2">Reject {confirmAction.profile.full_name}?</h3>
                <label className="label mb-1">Reason (optional)</label>
                <textarea className="input resize-none mb-4" rows={3} placeholder="Why are you rejecting this application?"
                  value={rejectReason} onChange={e => setRejectReason(e.target.value)} />
                <div className="flex gap-3">
                  <button onClick={() => confirmReject(confirmAction.profile)} className="btn-primary bg-red-500 hover:bg-red-600 flex-1">
                    Confirm Reject
                  </button>
                  <button onClick={() => setConfirmAction(null)} className="btn-secondary">Cancel</button>
                </div>
              </>
            )}
            {confirmAction.type === 'delete' && (
              <>
                <h3 className="text-lg font-bold mb-2 text-red-600">Delete {confirmAction.profile.full_name}?</h3>
                <p className="text-sm text-gray-500 mb-4">This action is permanent and cannot be undone. All their data will be removed.</p>
                {isMainAdmin && (
                  <>
                    <label className="label mb-1">Type their full name to confirm:</label>
                    <input className="input mb-4" placeholder={confirmAction.profile.full_name}
                      value={deleteConfirmName} onChange={e => setDeleteConfirmName(e.target.value)} />
                  </>
                )}
                <div className="flex gap-3">
                  <button onClick={() => confirmDelete(confirmAction.profile)}
                    disabled={isMainAdmin && deleteConfirmName.trim().toLowerCase() !== confirmAction.profile.full_name.toLowerCase()}
                    className="btn-primary bg-red-500 hover:bg-red-600 flex-1 disabled:opacity-40">
                    Delete Permanently
                  </button>
                  <button onClick={() => setConfirmAction(null)} className="btn-secondary">Cancel</button>
                </div>
                {msg?.type === 'error' && <p className="text-red-500 text-sm mt-2">{msg.text}</p>}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/weeks"
cat > "app/(app)/weeks/WeeksClient.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { format, parseISO, isToday, isPast } from 'date-fns'
import { CURRICULUM, DAILY_SCHEDULE, WEEK_SKILLS_7_12, getWeekCurriculum, WEEK_RULES } from '@/lib/curriculum'
import { CheckCircle, XCircle, Clock, BookOpen, Calendar, Users, ChevronRight, Award, AlertTriangle, Check, X } from 'lucide-react'
import ViewAsBanner from '@/components/admin/ViewAsBanner'

type Tab = 'overview' | 'curriculum' | 'schedule' | 'history' | 'admin'

export default function WeeksClient({
  profile, isAdmin, isTrackable, currentWeekNumber,
  myWeekAttendance, myAllAttendance, myAssessments, myAdvancementLog,
  allMembers, allAssessments, allWeekAttendance, workDays, weekStartStr, weekEndStr,
  isViewingAs, viewAsName,
}: {
  profile: any; isAdmin: boolean; isTrackable: boolean; currentWeekNumber: number
  myWeekAttendance: any[]; myAllAttendance: any[]; myAssessments: any[]
  myAdvancementLog: any[]; allMembers: any[]; allAssessments: any[]
  allWeekAttendance: any[]; workDays: string[]; weekStartStr: string; weekEndStr: string
  isViewingAs?: boolean; viewAsName?: string | null
}) {
  const [tab, setTab] = useState<Tab>(isTrackable ? 'overview' : 'admin')
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState<string | null>(null)

  const curriculum = getWeekCurriculum(currentWeekNumber)
  const myAttendedDays = myWeekAttendance.map(a => a.date)
  const daysPresent = myAttendedDays.length
  const daysMissed = workDays.filter(d => {
    const date = parseISO(d)
    return isPast(date) && !isToday(date) && !myAttendedDays.includes(d)
  })
  const daysRemaining = workDays.filter(d => {
    const date = parseISO(d)
    return !isPast(date) || isToday(date)
  })
  const currentAssessment = myAssessments.find(a => a.week_number === currentWeekNumber)
  const needsMoreDays = daysPresent < WEEK_RULES.min_attendance_days
  const canStillPass = daysPresent + daysRemaining.length >= WEEK_RULES.min_attendance_days

  // Admin: build member summary
  const memberSummary = allMembers.map(m => {
    const attended = allWeekAttendance.filter(a => a.user_id === m.id).length
    const assessment = allAssessments.find(a => a.user_id === m.id && a.week_number === m.week_number)
    const missedDays = workDays.filter(d => {
      const date = parseISO(d)
      return (isPast(date) && !isToday(date)) &&
        !allWeekAttendance.find(a => a.user_id === m.id && a.date === d)
    })
    const atRisk = attended < 3 && workDays.filter(d => !isPast(parseISO(d)) || isToday(parseISO(d))).length < (WEEK_RULES.min_attendance_days - attended)
    return { ...m, attended, missedDays: missedDays.length, assessment, atRisk }
  })

  async function markAssessmentSubmitted(userId: string, weekNum: number) {
    setLoading(`submit-${userId}-${weekNum}`)
    const supabase = createClient()
    await supabase.from('week_assessments').upsert({
      user_id: userId, week_number: weekNum,
      submitted: true, submitted_at: new Date().toISOString(),
    }, { onConflict: 'user_id,week_number' })
    setMsg({ type: 'success', text: 'Assessment marked as submitted' })
    setLoading(null)
    setTimeout(() => window.location.reload(), 800)
  }

  async function gradeAssessment(userId: string, weekNum: number, grade: string) {
    setLoading(`grade-${userId}-${weekNum}`)
    const supabase = createClient()
    await supabase.from('week_assessments').upsert({
      user_id: userId, week_number: weekNum,
      submitted: true, graded: true, grade,
      graded_at: new Date().toISOString(), graded_by: profile.id,
    }, { onConflict: 'user_id,week_number' })
    setMsg({ type: 'success', text: `Assessment graded: ${grade}` })
    setLoading(null)
    setTimeout(() => window.location.reload(), 800)
  }

  async function advanceMember(userId: string, fromWeek: number, action: 'advanced' | 'repeated' | 'pardoned', notes = '') {
    setLoading(`advance-${userId}`)
    const supabase = createClient()
    const toWeek = action === 'repeated' ? fromWeek : Math.min(fromWeek + 1, 12)
    const member = allMembers.find(m => m.id === userId)
    const assessment = allAssessments.find(a => a.user_id === userId && a.week_number === fromWeek)
    const attended = allWeekAttendance.filter(a => a.user_id === userId).length

    // Log the action
    await supabase.from('week_advancement_log').insert({
      user_id: userId, from_week: fromWeek, to_week: toWeek, action,
      attendance_days: attended,
      assessment_submitted: assessment?.submitted ?? false,
      assessment_graded: assessment?.graded ?? false,
      admin_notes: notes, actioned_by: profile.id,
    })

    // Update profile week number
    await supabase.from('profiles').update({ week_number: toWeek, week_confirmed: action !== 'repeated' }).eq('id', userId)

    setMsg({ type: 'success', text: `${member?.full_name} ${action === 'advanced' ? 'advanced to week ' + toWeek : action === 'pardoned' ? 'pardoned and advanced to week ' + toWeek : 'will repeat week ' + fromWeek}` })
    setLoading(null)
    setTimeout(() => window.location.reload(), 1000)
  }

  async function sendAbsenceEmail(userId: string) {
    setLoading(`email-${userId}`)
    try {
      const res = await fetch('/api/absence-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: userId, type: 'manual', admin_id: profile.id }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error)
      setMsg({ type: 'success', text: 'Absence email sent' })
    } catch (e: any) {
      setMsg({ type: 'error', text: e.message })
    }
    setLoading(null)
  }

  const tabs: { id: Tab; label: string }[] = [
    ...(isTrackable ? [
      { id: 'overview' as Tab, label: 'My Week' },
      { id: 'curriculum' as Tab, label: 'Curriculum' },
      { id: 'schedule' as Tab, label: 'Schedule' },
      { id: 'history' as Tab, label: 'My History' },
    ] : []),
    ...(isAdmin ? [{ id: 'admin' as Tab, label: `Members (${allMembers.length})` }] : []),
  ]

  if (!isTrackable && !isAdmin) {
    return (
      <div className="max-w-2xl mx-auto space-y-4">
        {isViewingAs && viewAsName && <ViewAsBanner name={viewAsName} />}
        <div className="card p-8 text-center space-y-2">
          <BookOpen className="w-10 h-10 text-gray-300 mx-auto" />
          <h2 className="text-lg font-semibold text-gray-900">12-Week Program Not Applicable</h2>
          <p className="text-sm text-gray-500">
            The 12-week onboarding program applies to Members, Distributors, and Managers only.
            {profile.status && ` As a ${String(profile.status).replace('_', ' ')}`}, this program doesn&apos;t apply here.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {isViewingAs && viewAsName && <ViewAsBanner name={viewAsName} />}
      {msg && (
        <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {tabs.map(t => (
          <button key={t.id} onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* ── MY WEEK OVERVIEW ── */}
      {tab === 'overview' && (
        <div className="space-y-4">
          {/* Week header */}
          <div className="card p-6 bg-gradient-to-r from-brand-900 to-brand-700 text-white border-0">
            <div className="flex items-start justify-between flex-wrap gap-4">
              <div>
                <div className="text-brand-200 text-sm font-medium mb-1">
                  Phase {curriculum?.phase} · {curriculum?.phase_title}
                </div>
                <h1 className="text-2xl font-extrabold">Week {currentWeekNumber} — {curriculum?.title}</h1>
                <p className="text-brand-200 text-sm mt-2 max-w-lg">{curriculum?.focus}</p>
              </div>
              <div className="text-right">
                <div className="text-4xl font-black">{currentWeekNumber}<span className="text-brand-300 text-xl">/12</span></div>
                <div className="text-brand-200 text-xs mt-1">Current Week</div>
              </div>
            </div>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { label: 'Days Present', value: daysPresent, total: 5, color: daysPresent >= 4 ? 'text-green-600' : 'text-amber-600', bg: daysPresent >= 4 ? 'bg-green-50' : 'bg-amber-50' },
              { label: 'Days Missed', value: daysMissed.length, color: daysMissed.length === 0 ? 'text-green-600' : 'text-red-600', bg: daysMissed.length === 0 ? 'bg-green-50' : 'bg-red-50' },
              { label: 'Assessment', value: currentAssessment?.graded ? 'Graded' : currentAssessment?.submitted ? 'Submitted' : 'Pending', color: currentAssessment?.graded ? 'text-green-600' : currentAssessment?.submitted ? 'text-blue-600' : 'text-amber-600', bg: 'bg-gray-50', isText: true },
              { label: 'Status', value: daysPresent >= 4 && currentAssessment?.graded ? 'On Track' : canStillPass ? 'In Progress' : 'At Risk', color: daysPresent >= 4 && currentAssessment?.graded ? 'text-green-600' : canStillPass ? 'text-brand-600' : 'text-red-600', bg: 'bg-gray-50', isText: true },
            ].map(s => (
              <div key={s.label} className={`card p-4 ${s.bg}`}>
                <div className={`text-2xl font-extrabold ${s.color}`}>{s.value}</div>
                <div className="text-xs text-gray-500 mt-1 font-medium">{s.label}</div>
              </div>
            ))}
          </div>

          {/* Attendance this week */}
          <div className="card p-5">
            <h2 className="section-title mb-4">This Week — {format(parseISO(weekStartStr), 'MMM d')} to {format(parseISO(weekEndStr), 'MMM d, yyyy')}</h2>
            <div className="grid grid-cols-5 gap-2">
              {workDays.map(day => {
                const present = myAttendedDays.includes(day)
                const isPastDay = isPast(parseISO(day)) && !isToday(parseISO(day))
                const isTodayDay = isToday(parseISO(day))
                const dayName = format(parseISO(day), 'EEE')
                const dayNum = format(parseISO(day), 'd')
                return (
                  <div key={day} className={`text-center p-3 rounded-xl border-2 transition-all ${
                    present ? 'bg-green-50 border-green-400' :
                    isTodayDay ? 'bg-brand-50 border-brand-400' :
                    isPastDay ? 'bg-red-50 border-red-200' :
                    'bg-gray-50 border-gray-200'
                  }`}>
                    <div className="text-xs font-semibold text-gray-500">{dayName}</div>
                    <div className="text-lg font-extrabold mt-0.5">{dayNum}</div>
                    <div className="mt-1">
                      {present ? <CheckCircle size={16} className="text-green-500 mx-auto" /> :
                       isTodayDay ? <Clock size={16} className="text-brand-500 mx-auto" /> :
                       isPastDay ? <XCircle size={16} className="text-red-400 mx-auto" /> :
                       <div className="w-4 h-4 rounded-full border-2 border-gray-300 mx-auto" />}
                    </div>
                  </div>
                )
              })}
            </div>

            {!canStillPass && (
              <div className="mt-4 flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
                <AlertTriangle size={16} className="flex-shrink-0 mt-0.5" />
                <span>You have missed too many days this week. You may need to repeat Week {currentWeekNumber}. Contact your SM or the admin.</span>
              </div>
            )}
          </div>

          {/* This week's assessment */}
          {curriculum && isTrackable && (
            <div className="card p-5">
              <div className="flex items-center justify-between mb-4 flex-wrap gap-2">
                <h2 className="section-title">Week {currentWeekNumber} Assessment</h2>
                <div className={`badge ${currentAssessment?.graded ? 'bg-green-100 text-green-700' : currentAssessment?.submitted ? 'bg-blue-100 text-blue-700' : 'bg-amber-100 text-amber-700'}`}>
                  {currentAssessment?.graded ? '✓ Graded' : currentAssessment?.submitted ? '✓ Submitted' : '⏳ Pending Submission'}
                </div>
              </div>

              <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 mb-4 text-sm text-amber-800">
                <strong>Due: Monday before 11:45 AM</strong> — Submit your assessment physically to the admin before this deadline to advance to Week {Math.min(currentWeekNumber + 1, 12)}.
              </div>

              <div className="space-y-2">
                {curriculum.assessments.map((a, i) => (
                  <div key={i} className="flex items-start gap-3 p-3 rounded-lg bg-gray-50 border border-gray-100">
                    <div className={`w-6 h-6 rounded-full flex-shrink-0 flex items-center justify-center text-xs font-bold ${currentAssessment?.graded ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-600'}`}>
                      {currentAssessment?.graded ? '✓' : i + 1}
                    </div>
                    <p className="text-sm text-gray-700 leading-relaxed">{a}</p>
                  </div>
                ))}
              </div>

              {currentAssessment?.grade && (
                <div className="mt-3 p-3 bg-green-50 border border-green-200 rounded-lg text-sm">
                  <span className="font-medium text-green-700">Grade: {currentAssessment.grade}</span>
                  {currentAssessment.admin_notes && <p className="text-green-600 mt-1">{currentAssessment.admin_notes}</p>}
                </div>
              )}
            </div>
          )}

          {/* Advancement requirements */}
          <div className="card p-5">
            <h2 className="section-title mb-4">Requirements to Advance to Week {Math.min(currentWeekNumber + 1, 12)}</h2>
            <div className="space-y-2">
              {[
                { label: `Attend at least 4 out of 5 days this week (${daysPresent}/4)`, done: daysPresent >= 4 },
                { label: 'Submit your assessment before Monday 11:45 AM', done: !!currentAssessment?.submitted },
                { label: 'Assessment graded by admin', done: !!currentAssessment?.graded },
                { label: 'Admin confirms week advancement', done: false },
              ].map((req, i) => (
                <div key={i} className={`flex items-center gap-3 p-3 rounded-lg border ${req.done ? 'bg-green-50 border-green-200' : 'bg-gray-50 border-gray-100'}`}>
                  {req.done ? <Check size={16} className="text-green-600 flex-shrink-0" /> : <div className="w-4 h-4 rounded-full border-2 border-gray-300 flex-shrink-0" />}
                  <span className={`text-sm ${req.done ? 'text-green-700 font-medium' : 'text-gray-600'}`}>{req.label}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ── CURRICULUM ── */}
      {tab === 'curriculum' && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-1">12-Week Curriculum</h2>
            <p className="text-sm text-gray-500 mb-4">Your complete 90-day plan. Complete every assessment every week — no shortcuts, no exceptions.</p>
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 text-sm text-amber-800 mb-4">
              <strong>Non-Negotiable Rule:</strong> Any member absent during any week of this program must repeat that week before advancing. Completing all knowledge modules and assessments each week is the only requirement to unlock the next week. No exceptions.
            </div>
          </div>

          {[1, 2, 3].map(phase => {
            const weeks = CURRICULUM.filter(w => w.phase === phase)
            return (
              <div key={phase} className="card overflow-hidden">
                <div className="bg-brand-900 text-white px-5 py-3">
                  <div className="text-xs text-brand-300 font-semibold uppercase tracking-wider">Phase {phase}</div>
                  <div className="font-bold">{weeks[0].phase_title}</div>
                </div>
                <div className="divide-y divide-gray-100">
                  {weeks.map(w => {
                    const isCurrent = w.week === currentWeekNumber
                    const isPast = w.week < currentWeekNumber
                    const myAssessment = myAssessments.find(a => a.week_number === w.week)
                    return (
                      <div key={w.week} className={`p-5 ${isCurrent ? 'bg-brand-50' : ''}`}>
                        <div className="flex items-start justify-between gap-3 flex-wrap">
                          <div className="flex items-start gap-3 flex-1">
                            <div className={`w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center text-sm font-extrabold ${
                              isPast ? 'bg-green-100 text-green-700' :
                              isCurrent ? 'bg-brand-600 text-white' :
                              'bg-gray-100 text-gray-400'
                            }`}>
                              {isPast ? '✓' : w.week}
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center gap-2 flex-wrap">
                                <div className="font-bold text-gray-900">Week {w.week} — {w.title}</div>
                                {isCurrent && <span className="badge bg-brand-100 text-brand-700">Current</span>}
                                {myAssessment?.graded && <span className="badge bg-green-100 text-green-700">✓ Graded</span>}
                                {myAssessment?.submitted && !myAssessment?.graded && <span className="badge bg-blue-100 text-blue-700">Submitted</span>}
                              </div>
                              <p className="text-sm text-gray-500 mt-1 leading-relaxed">{w.focus}</p>
                              {(isCurrent || isPast) && (
                                <div className="mt-3 space-y-1">
                                  <div className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Assessments</div>
                                  {w.assessments.map((a, i) => (
                                    <div key={i} className="text-sm text-gray-600 flex items-start gap-2">
                                      <span className="text-gray-300 flex-shrink-0">•</span>
                                      {a}
                                    </div>
                                  ))}
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            )
          })}

          {/* Skills weeks 7-12 */}
          <div className="card p-5">
            <h2 className="section-title mb-3">Skills Taught in Weeks 7–12</h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
              {WEEK_SKILLS_7_12.map(skill => (
                <div key={skill} className="flex items-center gap-2 p-2.5 rounded-lg bg-brand-50 border border-brand-100 text-sm font-medium text-brand-700">
                  <ChevronRight size={14} className="flex-shrink-0" />
                  {skill}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ── SCHEDULE ── */}
      {tab === 'schedule' && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-1">Daily Schedule</h2>
            <p className="text-sm text-gray-500 mb-4">Whether you attend the day or night session, the structure is identical. Arrive on time. Stay focused. Execute without excuses.</p>
            <div className="grid sm:grid-cols-2 gap-4">
              {(['day', 'night'] as const).map(session => (
                <div key={session} className={`rounded-xl overflow-hidden border ${session === 'day' ? 'border-amber-200' : 'border-brand-200'}`}>
                  <div className={`px-4 py-3 font-bold text-sm flex items-center gap-2 ${session === 'day' ? 'bg-amber-50 text-amber-800' : 'bg-brand-900 text-white'}`}>
                    {session === 'day' ? '☀ Day Session' : '🌙 Night Session'}
                  </div>
                  <div className="divide-y divide-gray-100">
                    {DAILY_SCHEDULE[session].map((item, i) => (
                      <div key={i} className="flex justify-between items-center px-4 py-2.5 text-sm">
                        <span className="font-mono text-xs text-gray-400 w-28 flex-shrink-0">{item.time}</span>
                        <span className="text-gray-700 font-medium flex-1 text-right">{item.activity}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
            <div className="mt-4 p-3 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-600">
              <strong>Before going home</strong> — complete your Evaluation. Early prayer is observed for both Muslim and Christian members before going home after night sessions.
            </div>
          </div>
        </div>
      )}

      {/* ── HISTORY ── */}
      {tab === 'history' && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-4">Attendance History</h2>
            {myAllAttendance.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No attendance records yet</p>
            ) : (
              <div className="space-y-2">
                {myAllAttendance.slice(0, 60).map(a => (
                  <div key={a.id} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
                    <div>
                      <div className="font-medium text-sm text-gray-900">{format(parseISO(a.date), 'EEEE, MMMM d yyyy')}</div>
                      <div className="text-xs text-gray-400">
                        In: {a.sign_in_time ? format(parseISO(a.sign_in_time), 'h:mm a') : '—'}
                        {a.sign_out_time && ` · Out: ${format(parseISO(a.sign_out_time), 'h:mm a')}`}
                        {a.is_night_session && ' · Night'}
                      </div>
                    </div>
                    <CheckCircle size={16} className="text-green-500" />
                  </div>
                ))}
              </div>
            )}
          </div>

          {myAdvancementLog.length > 0 && (
            <div className="card p-5">
              <h2 className="section-title mb-4">Week Advancement History</h2>
              <div className="space-y-2">
                {myAdvancementLog.map(log => (
                  <div key={log.id} className={`flex items-start gap-3 p-3 rounded-lg border ${
                    log.action === 'advanced' ? 'bg-green-50 border-green-200' :
                    log.action === 'pardoned' ? 'bg-blue-50 border-blue-200' :
                    'bg-amber-50 border-amber-200'
                  }`}>
                    <div className={`text-lg flex-shrink-0 ${log.action === 'advanced' ? 'text-green-600' : log.action === 'pardoned' ? 'text-blue-600' : 'text-amber-600'}`}>
                      {log.action === 'advanced' ? '🎯' : log.action === 'pardoned' ? '🙏' : '🔄'}
                    </div>
                    <div>
                      <div className="font-medium text-sm capitalize">
                        {log.action === 'advanced' ? `Advanced: Week ${log.from_week} → Week ${log.to_week}` :
                         log.action === 'pardoned' ? `Pardoned: Advanced to Week ${log.to_week}` :
                         `Repeated Week ${log.from_week}`}
                      </div>
                      <div className="text-xs text-gray-500 mt-0.5">
                        {format(parseISO(log.created_at), 'MMM d, yyyy')} · {log.attendance_days} days attended
                      </div>
                      {log.admin_notes && <p className="text-xs text-gray-500 mt-1 italic">{log.admin_notes}</p>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ── ADMIN ── */}
      {tab === 'admin' && isAdmin && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-1">Member Week Tracker</h2>
            <p className="text-sm text-gray-500 mb-4">
              Week runs Monday–Friday. Assessment deadline: Monday 11:45 AM. Min 4 days attendance required to advance.
            </p>
          </div>

          {memberSummary.length === 0 ? (
            <div className="card p-8 text-center text-gray-400 text-sm">No trackable members yet</div>
          ) : (
            <div className="space-y-3">
              {memberSummary.map(m => {
                const weekCurr = getWeekCurriculum(m.week_number)
                return (
                  <div key={m.id} className={`card p-5 ${m.atRisk ? 'border-red-200 bg-red-50/30' : ''}`}>
                    <div className="flex items-start justify-between gap-3 flex-wrap">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl flex items-center justify-center text-white font-bold text-sm flex-shrink-0"
                          style={{ backgroundColor: m.color_groups?.hex_color ?? '#4f46e5' }}>
                          {m.full_name.slice(0, 1)}
                        </div>
                        <div>
                          <div className="font-bold text-gray-900">{m.full_name}</div>
                          <div className="text-xs text-gray-400">{m.member_id} · Week {m.week_number} — {weekCurr?.title}</div>
                        </div>
                      </div>

                      <div className="flex items-center gap-2 flex-wrap">
                        {/* Attendance badge */}
                        <span className={`badge ${m.attended >= 4 ? 'bg-green-100 text-green-700' : m.atRisk ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'}`}>
                          {m.attended}/5 days
                        </span>

                        {/* Assessment badge */}
                        <span className={`badge ${m.assessment?.graded ? 'bg-green-100 text-green-700' : m.assessment?.submitted ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-500'}`}>
                          {m.assessment?.graded ? '✓ Graded' : m.assessment?.submitted ? 'Submitted' : 'No assessment'}
                        </span>

                        {m.atRisk && <span className="badge bg-red-100 text-red-700">⚠ At Risk</span>}
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="mt-4 flex gap-2 flex-wrap">
                      {/* Assessment actions */}
                      {!m.assessment?.submitted && (
                        <button onClick={() => markAssessmentSubmitted(m.id, m.week_number)}
                          disabled={loading === `submit-${m.id}-${m.week_number}`}
                          className="btn-secondary btn-sm">
                          Mark Assessment Submitted
                        </button>
                      )}
                      {m.assessment?.submitted && !m.assessment?.graded && (
                        <div className="flex gap-2">
                          <button onClick={() => gradeAssessment(m.id, m.week_number, 'pass')}
                            disabled={!!loading} className="btn-secondary btn-sm text-green-700 border-green-300">
                            Grade: Pass
                          </button>
                          <button onClick={() => gradeAssessment(m.id, m.week_number, 'excellent')}
                            disabled={!!loading} className="btn-secondary btn-sm text-brand-700 border-brand-300">
                            Grade: Excellent
                          </button>
                          <button onClick={() => gradeAssessment(m.id, m.week_number, 'fail')}
                            disabled={!!loading} className="btn-secondary btn-sm text-red-700 border-red-300">
                            Grade: Fail
                          </button>
                        </div>
                      )}

                      {/* Week advancement */}
                      {m.assessment?.graded && m.attended >= 4 && m.week_number < 12 && (
                        <button onClick={() => advanceMember(m.id, m.week_number, 'advanced')}
                          disabled={loading === `advance-${m.id}`}
                          className="btn-primary btn-sm flex items-center gap-1">
                          <ChevronRight size={14} /> Advance to Week {m.week_number + 1}
                        </button>
                      )}

                      {/* Repeat week */}
                      {(m.atRisk || m.missedDays >= 2) && (
                        <button onClick={() => advanceMember(m.id, m.week_number, 'repeated')}
                          disabled={!!loading}
                          className="btn-secondary btn-sm text-amber-700 border-amber-300">
                          🔄 Repeat Week {m.week_number}
                        </button>
                      )}

                      {/* Pardon */}
                      {(m.atRisk || m.missedDays >= 2) && m.week_number < 12 && (
                        <button onClick={() => advanceMember(m.id, m.week_number, 'pardoned', 'Admin pardon')}
                          disabled={!!loading}
                          className="btn-secondary btn-sm text-blue-700 border-blue-300">
                          🙏 Pardon & Advance
                        </button>
                      )}

                      {/* Send absence email */}
                      {m.missedDays > 0 && (
                        <button onClick={() => sendAbsenceEmail(m.id)}
                          disabled={loading === `email-${m.id}`}
                          className="btn-secondary btn-sm text-gray-600">
                          📧 Send Absence Email
                        </button>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/weeks"
cat > "app/(app)/weeks/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format, startOfWeek, endOfWeek, eachDayOfInterval, isWeekend } from 'date-fns'
import { getEffectiveProfile } from '@/lib/view-as'
import WeeksClient from './WeeksClient'

export default async function WeeksPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: realProfile } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*)')
    .eq('id', user.id)
    .single()
  if (!realProfile) redirect('/login')

  const { profile, isViewingAs, viewAsName } = await getEffectiveProfile(supabase, realProfile)

  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin
  const isAdminTier = isAdmin
  const isTrackable = !isAdminTier && ['member', 'distributor', 'manager'].includes(profile.status)

  // Get current week bounds (Mon–Fri)
  const now = new Date()
  const weekStart = startOfWeek(now, { weekStartsOn: 1 })
  const weekEnd = endOfWeek(now, { weekStartsOn: 1 })
  const weekStartStr = format(weekStart, 'yyyy-MM-dd')
  const weekEndStr = format(weekEnd, 'yyyy-MM-dd')

  // My attendance this week
  const { data: myWeekAttendance } = await supabase
    .from('attendance')
    .select('*')
    .eq('user_id', profile.id)
    .gte('date', weekStartStr)
    .lte('date', weekEndStr)
    .not('sign_in_time', 'is', null)

  // My full attendance history
  const { data: myAllAttendance } = await supabase
    .from('attendance')
    .select('*')
    .eq('user_id', profile.id)
    .not('sign_in_time', 'is', null)
    .order('date', { ascending: false })

  // My assessments
  const { data: myAssessments } = await supabase
    .from('week_assessments')
    .select('*')
    .eq('user_id', profile.id)
    .order('week_number')

  // My advancement log
  const { data: myAdvancementLog } = await supabase
    .from('week_advancement_log')
    .select('*')
    .eq('user_id', profile.id)
    .order('created_at', { ascending: false })

  // Admin: all trackable members with their week data
  let allMembers: any[] = []
  let allAssessments: any[] = []
  let allWeekAttendance: any[] = []

  if (isAdmin) {
    const { data: members } = await supabase
      .from('profiles')
      .select('*, color_groups!profiles_color_group_id_fkey(name, hex_color)')
      .in('status', ['member', 'distributor', 'manager'])
      .eq('approved', true)
      .order('week_number', { ascending: false })

    allMembers = members ?? []

    const memberIds = allMembers.map(m => m.id)

    if (memberIds.length > 0) {
      const { data: assessments } = await supabase
        .from('week_assessments')
        .select('*')
        .in('user_id', memberIds)

      const { data: weekAtt } = await supabase
        .from('attendance')
        .select('user_id, date')
        .in('user_id', memberIds)
        .gte('date', weekStartStr)
        .lte('date', weekEndStr)
        .not('sign_in_time', 'is', null)

      allAssessments = assessments ?? []
      allWeekAttendance = weekAtt ?? []
    }
  }

  // Work days this week (Mon-Fri only)
  const workDays = eachDayOfInterval({ start: weekStart, end: weekEnd })
    .filter(d => !isWeekend(d))
    .map(d => format(d, 'yyyy-MM-dd'))

  return (
    <WeeksClient
      profile={profile}
      isAdmin={isAdmin}
      isTrackable={isTrackable}
      currentWeekNumber={profile.week_number}
      myWeekAttendance={myWeekAttendance ?? []}
      myAllAttendance={myAllAttendance ?? []}
      myAssessments={myAssessments ?? []}
      myAdvancementLog={myAdvancementLog ?? []}
      allMembers={allMembers}
      allAssessments={allAssessments}
      allWeekAttendance={allWeekAttendance}
      workDays={workDays}
      weekStartStr={weekStartStr}
      weekEndStr={weekEndStr}
      isViewingAs={isViewingAs}
      viewAsName={viewAsName}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/api/admin/view-as"
cat > "app/api/admin/view-as/route.ts" << 'CLAUDE_EOF_MARKER'
import { NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { createClient } from '@/lib/supabase/server'
import { VIEW_AS_COOKIE } from '@/lib/view-as'

export async function POST(request: Request) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Not logged in' }, { status: 401 })

  const { data: actor } = await supabase
    .from('profiles')
    .select('is_admin, is_director, is_co_admin')
    .eq('id', user.id)
    .single()

  if (!actor || (!actor.is_admin && !actor.is_director && !actor.is_co_admin)) {
    return NextResponse.json({ error: 'Not authorized' }, { status: 403 })
  }

  const { target_id } = await request.json()
  if (!target_id) return NextResponse.json({ error: 'Missing target_id' }, { status: 400 })

  cookies().set(VIEW_AS_COOKIE, target_id, {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 4, // 4 hours, auto-expires so it can't be forgotten
  })

  return NextResponse.json({ ok: true })
}

export async function DELETE() {
  cookies().delete(VIEW_AS_COOKIE)
  return NextResponse.json({ ok: true })
}
CLAUDE_EOF_MARKER

mkdir -p "components/admin"
cat > "components/admin/ViewAsBanner.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useRouter } from 'next/navigation'
import { Eye, X } from 'lucide-react'

export default function ViewAsBanner({ name }: { name: string }) {
  const router = useRouter()

  async function exit() {
    await fetch('/api/admin/view-as', { method: 'DELETE' })
    router.push('/people')
    router.refresh()
  }

  return (
    <div className="bg-amber-500 text-white px-4 py-2 flex items-center justify-between gap-3 text-sm font-medium sticky top-0 z-50">
      <div className="flex items-center gap-2">
        <Eye size={16} />
        <span>Viewing as <strong>{name}</strong> — this is what they see, not you.</span>
      </div>
      <button onClick={exit} className="flex items-center gap-1 bg-white/20 hover:bg-white/30 rounded-md px-2.5 py-1">
        <X size={14} /> Exit
      </button>
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "lib"
cat > "lib/view-as.ts" << 'CLAUDE_EOF_MARKER'
import { cookies } from 'next/headers'
import type { SupabaseClient } from '@supabase/supabase-js'

export const VIEW_AS_COOKIE = 'view_as_id'

/**
 * Admin-only "View As" — lets an admin see the app exactly as a given member
 * would see it (dashboard, 12-week program, etc.) without logging in as them.
 * Only takes effect if the REAL logged-in user is an admin/director/co-admin;
 * everyone else's view is always their own regardless of any stray cookie.
 */
export async function getEffectiveProfile(supabase: SupabaseClient, realProfile: any) {
  const isAdminTier = realProfile?.is_admin || realProfile?.is_director || realProfile?.is_co_admin
  if (!isAdminTier) {
    return { profile: realProfile, isViewingAs: false, viewAsName: null as string | null }
  }

  const cookieStore = cookies()
  const viewAsId = cookieStore.get(VIEW_AS_COOKIE)?.value
  if (!viewAsId || viewAsId === realProfile.id) {
    return { profile: realProfile, isViewingAs: false, viewAsName: null as string | null }
  }

  const { data: viewProfile } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*)')
    .eq('id', viewAsId)
    .single()

  if (!viewProfile) {
    return { profile: realProfile, isViewingAs: false, viewAsName: null as string | null }
  }

  return { profile: viewProfile, isViewingAs: true, viewAsName: viewProfile.full_name as string }
}
CLAUDE_EOF_MARKER

echo "Staging and committing..."
git add .
git commit -m "feat: view-as impersonation for admin, fix 12-week program gating, add sponsor edit"
git push origin main
echo "Done. Vercel should start redeploying now."
