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
  memberStartsThisMonth, teamStartsThisMonth, isSMOrAbove,
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
import DashboardClient from './DashboardClient'

export default async function DashboardPage({ searchParams }: { searchParams: { range?: string } }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile, error: profileError } = await supabase
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

  if (!profile) redirect('/pending-approval')
  if (!profile.approved && !profile.is_admin && !profile.is_director && !profile.is_co_admin) redirect('/pending-approval')

  const range = searchParams.range ?? 'this_month'
  const now = new Date()
  const todayStr = format(now, 'yyyy-MM-dd')
  const thisMonthStart = format(startOfMonth(now), 'yyyy-MM-dd')
  const thisMonthEnd = format(endOfMonth(now), 'yyyy-MM-dd')
  const thisMonthStr = format(now, 'yyyy-MM')
  const isAdmin = profile.is_admin || profile.is_director
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
    supabase.from('attendance').select('date').eq('user_id', user.id)
      .gte('date', rangeStart).lte('date', rangeEnd).not('sign_in_time', 'is', null),

    supabase.from('weekly_earnings').select('amount_usd').eq('user_id', user.id)
      .gte('week_start', rangeStart).lte('week_start', rangeEnd),

    supabase.from('scouting_records').select('id', { count: 'exact', head: true })
      .eq('user_id', user.id).eq('status', 'contacted'),

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
      .select('points, month_str, rank').eq('user_id', user.id),

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
  const myRank = topEarners.findIndex(e => e.id === user.id) + 1

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
    p => p.sponsor_id === user.id && p.is_new_member && p.new_member_month === thisMonthStr
  ).length

  // Team Starts / SM Team Starts: everyone in your downline up to (not including) the
  // next Senior Manager boundary — same rule for members and Senior Managers alike.
  const isSMOrAbove = isSmOrAbove(profile.status)
  const myTeamIds = computeTeam(user.id, 'senior_manager' as any, allTeamProfiles as any)
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
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/group"
cat > "app/(app)/group/GroupClient.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import type { Profile } from '@/lib/types'
import { getStatusLabel, getStatusColor } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function GroupClient({
  profile, groupMembers, scoutingByMember, totalGroupScouting,
}: {
  profile: Profile
  groupMembers: Profile[]
  scoutingByMember: Record<string, number>
  totalGroupScouting: number
}) {
  const router = useRouter()
  const [taskForm, setTaskForm] = useState({ title: '', description: '', assignee: '', due_date: '' })
  const [taskMsg, setTaskMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState(false)

  async function assignTask() {
    if (!taskForm.title || !taskForm.assignee) return
    setLoading(true)
    setTaskMsg(null)
    const supabase = createClient()
    const { error } = await supabase.from('tasks').insert({
      title: taskForm.title,
      description: taskForm.description || null,
      assigned_to: taskForm.assignee,
      assigned_by: profile.id,
      due_date: taskForm.due_date || null,
    })
    if (error) setTaskMsg({ type: 'error', text: error.message })
    else {
      setTaskMsg({ type: 'success', text: 'Task assigned!' })
      setTaskForm({ title: '', description: '', assignee: '', due_date: '' })
    }
    setLoading(false)
  }

  const groupColor = profile.color_groups?.hex_color ?? '#4f46e5'
  const groupName = profile.color_groups?.name ?? 'Your Group'

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Group header */}
      <div className="card p-5 flex items-center gap-4">
        <div className="w-14 h-14 rounded-2xl flex items-center justify-center text-white font-black text-xl" style={{ backgroundColor: groupColor }}>
          {groupName[0]}
        </div>
        <div>
          <div className="text-xl font-bold text-gray-900">{groupName} Group</div>
          <div className="text-sm text-gray-500">{groupMembers.length} members · {totalGroupScouting.toLocaleString()} total businesses scouted</div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Total Members', value: groupMembers.length },
          { label: 'Total Scouted', value: totalGroupScouting.toLocaleString() },
          { label: 'Active Today', value: '—' },
          { label: 'New Members', value: groupMembers.filter(m => m.is_new_member).length },
        ].map(s => (
          <div key={s.label} className="card p-4 text-center">
            <div className="text-2xl font-extrabold text-gray-900">{s.value}</div>
            <div className="text-xs text-gray-400 mt-0.5">{s.label}</div>
          </div>
        ))}
      </div>

      {/* Group members table */}
      <div className="card overflow-x-auto">
        <div className="p-4 border-b border-gray-100">
          <h2 className="section-title">Group Members</h2>
        </div>
        <table className="w-full text-sm">
          <thead className="border-b border-gray-100">
            <tr>
              <th className="table-th">Name</th>
              <th className="table-th">ID</th>
              <th className="table-th">Status</th>
              <th className="table-th">Sponsor</th>
              <th className="table-th">Week</th>
              <th className="table-th">Scouted (All Time)</th>
            </tr>
          </thead>
          <tbody>
            {groupMembers.map(m => (
              <tr key={m.id} className="table-row">
                <td className="table-td">
                  <button className="font-medium text-brand-600 hover:text-brand-700 hover:underline text-left" onClick={() => router.push(`/member/${m.id}`)}>
                    {m.full_name}
                  </button>
                  {m.is_new_member && <span className="badge bg-brand-100 text-brand-700 text-xs ml-1.5">NEW</span>}
                </td>
                <td className="table-td text-gray-400">{m.member_id ?? '—'}</td>
                <td className="table-td"><span className={`badge ${getStatusColor(m.status)}`}>{getStatusLabel(m.status)}</span></td>
                <td className="table-td text-xs text-gray-400">{(m as any).sponsor?.full_name ?? '—'}</td>
                <td className="table-td">
                  {['member','distributor','manager'].includes(m.status)
                    ? <span className="badge bg-blue-100 text-blue-700">Wk {m.week_number}</span>
                    : '—'}
                </td>
                <td className="table-td font-medium">{(scoutingByMember[m.id] ?? 0).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Assign task */}
      <div className="card p-5">
        <h2 className="section-title mb-4">Assign Task to Group Member</h2>
        <div className="grid grid-cols-2 gap-4">
          <div className="col-span-2">
            <label className="label">Task Title *</label>
            <input className="input" value={taskForm.title} onChange={e => setTaskForm(p => ({ ...p, title: e.target.value }))} placeholder="e.g. Follow up with 5 prospects" />
          </div>
          <div className="col-span-2">
            <label className="label">Description</label>
            <textarea className="input resize-none" rows={2} value={taskForm.description} onChange={e => setTaskForm(p => ({ ...p, description: e.target.value }))} />
          </div>
          <div>
            <label className="label">Assign To *</label>
            <select className="input" value={taskForm.assignee} onChange={e => setTaskForm(p => ({ ...p, assignee: e.target.value }))}>
              <option value="">Select member…</option>
              {groupMembers.filter(m => m.id !== profile.id).map(m => (
                <option key={m.id} value={m.id}>{m.full_name} ({m.member_id})</option>
              ))}
            </select>
          </div>
          <div>
            <label className="label">Due Date</label>
            <input className="input" type="date" value={taskForm.due_date} onChange={e => setTaskForm(p => ({ ...p, due_date: e.target.value }))} />
          </div>
        </div>

        {taskMsg && (
          <div className={`mt-3 px-4 py-2.5 rounded-lg text-sm border ${taskMsg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
            {taskMsg.text}
          </div>
        )}

        <button onClick={assignTask} disabled={loading} className="btn-primary mt-4">
          {loading ? 'Assigning…' : 'Assign Task'}
        </button>
      </div>
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/group"
cat > "app/(app)/group/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import GroupClient from './GroupClient'

export default async function GroupPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')
  if (!profile.color_group_id) redirect('/dashboard')

  const { data: groupMembers } = await supabase
    .from('profiles')
    .select('*, sponsor:sponsor_id(id, full_name, member_id)')
    .eq('color_group_id', profile.color_group_id)
    .eq('approved', true)
    .order('status')

  // Scouting stats for group
  const memberIds = (groupMembers ?? []).map(m => m.id)
  const { data: groupScouting, count: groupScoutingCount } = await supabase
    .from('scouting_records')
    .select('user_id, scouted_at', { count: 'exact' })
    .in('user_id', memberIds)

  // Yesterday's scouting by person
  const yesterday = new Date()
  yesterday.setDate(yesterday.getDate() - 1)
  yesterday.setHours(0, 0, 0, 0)

  const scoutingByMember = (groupScouting ?? []).reduce((acc: Record<string, number>, r) => {
    acc[r.user_id] = (acc[r.user_id] ?? 0) + 1
    return acc
  }, {})

  return (
    <GroupClient
      profile={profile}
      groupMembers={(groupMembers ?? []) as any[]}
      scoutingByMember={scoutingByMember}
      totalGroupScouting={groupScoutingCount ?? 0}
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
import { Check, X, Search, ChevronDown, ChevronRight, Shield, UserX, UserCheck } from 'lucide-react'

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

mkdir -p "app/(app)/team"
cat > "app/(app)/team/TeamClient.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Profile, UserStatus } from '@/lib/types'
import { getStatusLabel, getStatusColor, STATUS_LABELS, STATUS_ORDER, isSmOrAbove } from '@/lib/types'
import { Users, ChevronDown, ChevronRight, Search, Calendar } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { format, subDays } from 'date-fns'

export default function TeamClient({
  profile, isAdmin, myTeam, allProfiles, viewingMember,
  availableFilters, activeFilter, teamCounts,
}: {
  profile: Profile
  isAdmin: boolean
  myTeam: Profile[]
  allProfiles: Profile[]
  viewingMember: Profile | null
  availableFilters: string[]
  activeFilter: string
  teamCounts: Record<string, number>
}) {
  const router = useRouter()
  const [search, setSearch] = useState('')
  const [activityFilter, setActivityFilter] = useState('active')
  const [expandedTree, setExpandedTree] = useState<Set<string>>(new Set())
  const [selectedMember, setSelectedMember] = useState<Profile | null>(viewingMember)
  const [memberAttendance, setMemberAttendance] = useState<any[]>([])
  const [loadingAttendance, setLoadingAttendance] = useState(false)

  function filtered(list: Profile[]) {
    return list.filter(p => {
      const matchSearch = !search ||
        p.full_name.toLowerCase().includes(search.toLowerCase()) ||
        (p.member_id ?? '').toLowerCase().includes(search.toLowerCase())
      const matchActivity = activityFilter === 'all' || p.activity_status === activityFilter
      return matchSearch && matchActivity
    })
  }

  async function viewMemberAttendance(p: Profile) {
    setSelectedMember(p)
    setLoadingAttendance(true)
    const supabase = createClient()
    const from = format(subDays(new Date(), 30), 'yyyy-MM-dd')
    const { data } = await supabase
      .from('attendance')
      .select('*')
      .eq('user_id', p.id)
      .gte('date', from)
      .order('date', { ascending: false })
    setMemberAttendance(data ?? [])
    setLoadingAttendance(false)
  }

  function toggleTree(id: string) {
    setExpandedTree(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  function renderTree(parentId: string, depth = 0): React.ReactNode {
    const children = allProfiles.filter(p => p.sponsor_id === parentId)
    if (!children.length) return null
    return children.map(p => {
      const hasChildren = allProfiles.some(c => c.sponsor_id === p.id)
      const expanded = expandedTree.has(p.id)
      const cg = (p as any).color_groups
      return (
        <div key={p.id} style={{ marginLeft: depth * 18 }}>
          <div className="flex items-center gap-2 py-2 px-3 rounded-lg hover:bg-gray-50 group">
            <button onClick={() => toggleTree(p.id)}
              className={`w-5 h-5 flex items-center justify-center flex-shrink-0 ${hasChildren ? 'text-gray-400' : 'text-transparent'}`}>
              {hasChildren ? (expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />) : null}
            </button>
            <div className="w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0"
              style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
              {p.full_name.charAt(0)}
            </div>
            <div className="flex-1 min-w-0 cursor-pointer" onClick={() => viewMemberAttendance(p)}>
              <div className="text-sm font-medium truncate">{p.full_name}</div>
              <div className="text-xs text-gray-400">{p.member_id} · {getStatusLabel(p.status)}</div>
            </div>
            <span className={`badge text-xs ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
          </div>
          {expanded && renderTree(p.id, depth + 1)}
        </div>
      )
    })
  }

  const displayList = filtered(myTeam)

  return (
    <div className="max-w-6xl mx-auto space-y-5">
      {/* Team filter pills — one per available status level */}
      <div className="flex gap-2 flex-wrap">
        {availableFilters.map(f => (
          <button key={f} onClick={() => router.push(`/team?filter=${f}`)}
            className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${activeFilter === f ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
            {f === 'all' ? 'All Team' : getStatusLabel(f as UserStatus) + ' Team'}
            <span className="ml-1.5 opacity-70">({teamCounts[f] ?? 0})</span>
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Team list */}
        <div className="lg:col-span-2 space-y-3">
          <div className="flex gap-3 flex-wrap">
            <div className="relative flex-1 min-w-48">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input className="input pl-8" placeholder="Search name or ID…" value={search} onChange={e => setSearch(e.target.value)} />
            </div>
            <select className="input w-auto" value={activityFilter} onChange={e => setActivityFilter(e.target.value)}>
              <option value="all">All</option>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
              <option value="suspended">Suspended</option>
            </select>
          </div>

          <div className="card divide-y divide-gray-50">
            {displayList.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No team members found</p>
            ) : displayList.map(p => {
              const cg = (p as any).color_groups
              const isSelected = selectedMember?.id === p.id
              return (
                <button key={p.id} type="button"
                  className={`w-full flex items-center gap-3 p-3 text-left hover:bg-gray-50 transition-colors ${isSelected ? 'bg-indigo-50' : ''}`}
                  onClick={() => viewMemberAttendance(p)}>
                  <div className="w-9 h-9 rounded-full flex items-center justify-center text-white text-sm font-bold flex-shrink-0"
                    style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
                    {p.full_name.charAt(0)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-sm text-gray-900 truncate">{p.full_name}</div>
                    <div className="text-xs text-gray-400">{p.member_id ?? 'No ID'} · {cg?.name ?? '—'}</div>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <span className={`badge text-xs ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                    <div className={`text-xs mt-0.5 ${p.activity_status === 'active' ? 'text-green-500' : 'text-gray-400'}`}>
                      {p.activity_status}
                    </div>
                  </div>
                </button>
              )
            })}
          </div>
        </div>

        {/* Member detail + attendance */}
        <div className="space-y-4">
          {selectedMember ? (
            <>
              <div className="card p-5">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-lg"
                      style={{ backgroundColor: (selectedMember as any).color_groups?.hex_color ?? '#6366f1' }}>
                      {selectedMember.full_name.charAt(0)}
                    </div>
                    <div>
                      <div className="font-bold text-gray-900">{selectedMember.full_name}</div>
                      <div className="text-xs text-gray-400">{selectedMember.member_id}</div>
                      <span className={`badge text-xs mt-1 ${getStatusColor(selectedMember.status)}`}>{getStatusLabel(selectedMember.status)}</span>
                    </div>
                  </div>
                </div>
                <button
                  className="w-full text-center text-xs font-semibold text-brand-600 hover:text-brand-700 bg-brand-50 rounded-lg py-2 mb-3"
                  onClick={() => router.push(`/member/${selectedMember.id}`)}>
                  View Full Profile →
                </button>
                <div className="text-xs text-gray-500 space-y-1">
                  <div>Week: {selectedMember.week_number ?? '—'}</div>
                  <div>Group: {(selectedMember as any).color_groups?.name ?? '—'}</div>
                  <div>Activity: {selectedMember.activity_status}</div>
                  {selectedMember.last_seen && (
                    <div>Last seen: {format(new Date(selectedMember.last_seen), 'MMM d, HH:mm')}</div>
                  )}
                </div>
              </div>

              <div className="card p-4">
                <div className="flex items-center gap-2 mb-3">
                  <Calendar size={15} className="text-gray-400" />
                  <span className="font-semibold text-sm text-gray-900">Last 30 Days Attendance</span>
                </div>
                {loadingAttendance ? (
                  <div className="text-xs text-gray-400 text-center py-4">Loading…</div>
                ) : memberAttendance.length === 0 ? (
                  <div className="text-xs text-gray-400 text-center py-4">No attendance in last 30 days</div>
                ) : (
                  <div className="space-y-1.5">
                    {memberAttendance.map(a => (
                      <div key={a.id} className="flex items-center justify-between text-xs">
                        <span className="text-gray-600 font-medium">{format(new Date(a.date), 'EEE, MMM d')}</span>
                        <div className="flex gap-2">
                          <span className="text-blue-600">{a.sign_in_time ? format(new Date(a.sign_in_time), 'HH:mm') : '—'}</span>
                          <span className="text-gray-400">→</span>
                          <span className="text-orange-600">{a.sign_out_time ? format(new Date(a.sign_out_time), 'HH:mm') : '—'}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="card p-6 text-center">
              <Users size={32} className="mx-auto mb-2 text-gray-300" />
              <p className="text-sm text-gray-400">Click a team member to view their details and attendance</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "components/layout"
cat > "components/layout/Sidebar.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  LayoutDashboard, Users, UserCheck, DollarSign, Search,
  Calendar, MessageSquare, Settings, QrCode, Group, LogOut, ChevronRight, Flag, GraduationCap
} from 'lucide-react'
import type { Profile } from '@/lib/types'
import { isSmOrAbove, getStatusLabel } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

interface NavItem {
  href: string
  label: string
  icon: React.ReactNode
  adminOnly?: boolean
  smOnly?: boolean
}

export default function Sidebar({ profile }: { profile: Profile }) {
  const pathname = usePathname()
  const router = useRouter()
  const isAdmin = profile.is_admin || profile.is_director
  const isSm = isSmOrAbove(profile.status)

  const navItems: NavItem[] = [
    { href: '/dashboard', label: 'Dashboard', icon: <LayoutDashboard size={18} /> },
    { href: '/attendance', label: 'Attendance', icon: <QrCode size={18} /> },
    { href: '/weeks', label: '12-Week Program', icon: <GraduationCap size={18} /> },
    { href: '/team', label: 'My Team', icon: <Users size={18} /> },
    { href: '/group', label: 'My Group', icon: <Group size={18} /> },
    { href: '/people', label: 'People', icon: <UserCheck size={18} />, adminOnly: true },
    { href: '/money', label: 'Money Making', icon: <DollarSign size={18} /> },
    { href: '/scouting', label: 'Scouting', icon: <Search size={18} /> },
    { href: '/community', label: 'Community', icon: <MessageSquare size={18} /> },
    { href: '/events', label: 'Events', icon: <Calendar size={18} /> },
    { href: '/feedback', label: 'Feedback', icon: <Flag size={18} /> },
    { href: '/settings', label: 'Settings', icon: <Settings size={18} /> },
  ]

  const visibleItems = navItems.filter(item => {
    if (item.adminOnly && !isAdmin) return false
    if (item.smOnly && !isSm && !isAdmin) return false
    return true
  })

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
  }

  return (
    <aside className="hidden md:flex w-60 flex-col bg-white border-r border-gray-200 h-screen overflow-y-auto flex-shrink-0">
      {/* Brand */}
      <div className="p-5 border-b border-gray-100">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 bg-brand-600 rounded-lg flex items-center justify-center">
            <span className="text-white font-black text-sm">E</span>
          </div>
          <div>
            <div className="font-bold text-sm text-gray-900 leading-tight">Elevate</div>
            <div className="text-xs text-gray-400">Office Tracker</div>
          </div>
        </div>
      </div>

      {/* User info */}
      <div className="px-4 py-3 border-b border-gray-100">
        <div className="flex items-center gap-2.5">
          <div
            className="w-9 h-9 rounded-full flex-shrink-0 flex items-center justify-center text-white text-sm font-bold"
            style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}
          >
            {(profile.full_name ?? '?').split(' ').filter(Boolean).map(n => n[0]).join('').slice(0, 2).toUpperCase()}
          </div>
          <div className="min-w-0">
            <div className="text-sm font-semibold text-gray-900 truncate">{profile.full_name ?? 'Member'}</div>
            <div className="text-xs text-gray-400 flex items-center gap-1">
              <span>{profile.member_id ?? 'Pending ID'}</span>
              {profile.is_new_member && (
                <span className="bg-brand-100 text-brand-700 px-1.5 py-0.5 rounded text-[10px] font-bold">NEW</span>
              )}
            </div>
          </div>
        </div>
        <div className="mt-2">
          <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full font-medium">
            {getStatusLabel(profile.status)}
          </span>
          {(profile.is_admin || profile.is_director) && (
            <span className="ml-1 text-xs bg-brand-100 text-brand-700 px-2 py-0.5 rounded-full font-medium">
              {profile.is_admin ? 'Admin' : 'Director'}
            </span>
          )}
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 p-3 space-y-0.5">
        {visibleItems.map(item => {
          const active = pathname === item.href || pathname.startsWith(item.href + '/')
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                active
                  ? 'bg-brand-600 text-white'
                  : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
              }`}
            >
              {item.icon}
              {item.label}
              {active && <ChevronRight size={14} className="ml-auto" />}
            </Link>
          )
        })}
      </nav>

      {/* Sign out */}
      <div className="p-3 border-t border-gray-100">
        <button
          onClick={handleSignOut}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-gray-500 hover:bg-red-50 hover:text-red-600 transition-colors"
        >
          <LogOut size={18} />
          Sign Out
        </button>
      </div>
    </aside>
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
  totalPoints, fullDownline,
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
}) {
  const router = useRouter()
  const [editing, setEditing] = useState(false)
  const [saving, setSaving] = useState(false)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [form, setForm] = useState({
    full_name: target.full_name,
    status: target.status,
    week_number: target.week_number ?? 1,
  })

  const cg = (target as any).color_groups

  function changeRange(r: string) {
    router.push(`/member/${target.id}?range=${r}`)
  }

  async function save() {
    setSaving(true)
    setMsg(null)
    const res = await fetch('/api/update-profile', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: target.id, actor_id: viewer.id, updates: form }),
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
          <button className="btn-primary text-sm" disabled={saving} onClick={save}>
            {saving ? 'Saving…' : 'Save Changes'}
          </button>
          {msg && <p className={`text-xs ${msg.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>{msg.text}</p>}
          <p className="text-xs text-gray-400">To change color, sponsor, or profile picture, use the People page.</p>
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

echo "Staging and committing..."
git add .
git commit -m "feat: member detail pages, top punctuality leaderboard, consolidated My Group"
git push origin main
echo "Done. Vercel should start redeploying now."
