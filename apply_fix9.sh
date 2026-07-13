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
  topScoutsToday, groupScoutLeaderboard, consistentEarners, topPunctuality, topAttendance,
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
  topScoutsToday: any[]; groupScoutLeaderboard: any[]; consistentEarners: any[]; topPunctuality: any[]; topAttendance: any[]
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

        {/* MOST CONSISTENT ATTENDANCE LEADERBOARD */}
        <div className="card p-5 animate-slide-up">
          <SectionHeader title="📅 Most Consistent Attendance" sub={`Most days present · ${rangeLabel} · ties broken by punctuality`} />
          {topAttendance.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No sign-ins recorded {rangeLabel} yet.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b border-gray-100">
                  <th className="table-th w-10">#</th>
                  <th className="table-th">Member</th>
                  <th className="table-th hidden sm:table-cell">Group</th>
                  <th className="table-th">Days Present</th>
                  <th className="table-th hidden sm:table-cell">Avg. Ahead of Window</th>
                </tr></thead>
                <tbody>
                  {topAttendance.map((e, i) => (
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
                      <td className="table-td font-extrabold text-brand-600">{e.days} day{e.days !== 1 ? 's' : ''}</td>
                      <td className="table-td hidden sm:table-cell text-gray-400">
                        {e.avgMinutesEarly >= 0 ? `${e.avgMinutesEarly} min early` : `${Math.abs(e.avgMinutesEarly)} min late`}
                      </td>
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
    { data: allEarningsRaw },
    { count: newMembersCount },
    { data: groupEarningsRaw },
    { data: settings },
    { data: todayScouts },
    { data: groupScouts },
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

    // ALL earnings for EM-and-below, all-time — used to compute BOTH Top
    // Earners (range-aware) and Consistent Earners (live monthly ranking),
    // with zero dependency on any manual/batch calculation step.
    supabase.from('weekly_earnings')
      .select('amount_usd, week_start, user_id, profiles!inner(id, full_name, member_id, status, profile_picture, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .in('profiles.status', ['member','distributor','manager','executive_manager'])
      .then(res => {
        if (res.error) console.error('Dashboard allEarnings query failed:', res.error)
        return res
      }),

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

  // Top Earners: sum of earnings within the SELECTED range (not hardcoded to this month)
  const earnerMap = new Map<string, any>()
  for (const e of (allEarningsRaw ?? [])) {
    if (e.week_start < rangeStart || e.week_start > rangeEnd) continue
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

  // Consistent Earner points — computed LIVE from raw earnings, no manual
  // recalculation step needed ever. For each calendar month that has any
  // earnings, rank EM-and-below earners by that month's total and award
  // 1st=10pts, 2nd=9 ... 10th=1, 11th+=0 (same formula as before). Then sum
  // points only for months that fall within the selected date range, so a
  // "Last 3 Months" filter shows exactly the points earned in those months.
  const monthTotals = new Map<string, Map<string, number>>() // month_str -> user_id -> total
  const personById = new Map<string, any>()
  for (const e of (allEarningsRaw ?? [])) {
    const p = (e as any).profiles
    if (!p) continue
    personById.set(p.id, p)
    const monthStr = String(e.week_start).slice(0, 7) // YYYY-MM
    if (!monthTotals.has(monthStr)) monthTotals.set(monthStr, new Map())
    const userTotals = monthTotals.get(monthStr)!
    userTotals.set(p.id, (userTotals.get(p.id) ?? 0) + Number(e.amount_usd))
  }
  const pointsMap = new Map<string, any>()
  for (const [monthStr, userTotals] of monthTotals.entries()) {
    // Only count this month's points if the month falls within the selected range
    const monthDate = monthStr + '-01'
    if (monthDate < rangeStart.slice(0, 7) + '-01' || monthDate > rangeEnd) continue
    const ranked = Array.from(userTotals.entries()).sort((a, b) => b[1] - a[1])
    ranked.forEach(([userId, amount], i) => {
      const points = i < 10 ? 10 - i : 0
      if (points === 0) return
      const p = personById.get(userId)
      if (!p) return
      const ex = pointsMap.get(userId) ?? { id: userId, full_name: p.full_name, member_id: p.member_id, profile_picture: p.profile_picture, group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#999', totalPoints: 0, months: 0 }
      ex.totalPoints += points
      ex.months++
      pointsMap.set(userId, ex)
    })
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

  // Most Consistent Attendance: ranked by number of days present in the
  // selected range, tie-broken by punctuality (earlier average = wins ties) —
  // same underlying dataset as Top Punctuality, just ranked differently.
  const topAttendance = Array.from(punctualityMap.values())
    .map(e => ({ ...e, avgMinutesEarly: Math.round(e.totalMinutesEarly / e.days) }))
    .sort((a, b) => b.days - a.days || b.avgMinutesEarly - a.avgMinutesEarly)
    .slice(0, 20)

  const myTotalPoints = pointsMap.get(profile.id)?.totalPoints ?? 0

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
      topAttendance={topAttendance}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/money"
cat > "app/(app)/money/MoneyClient.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState, useMemo } from 'react'
import { format, startOfWeek, endOfWeek, parseISO, startOfMonth, endOfMonth } from 'date-fns'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ColorGroup, WeeklyEarning } from '@/lib/types'
import { formatCurrency, getStatusLabel, getStatusColor } from '@/lib/utils'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts'

type EarningView = 'weekly' | 'monthly'

export default function MoneyClient({
  profile, isAdmin, isEmOrBelow, myWeeklyEarnings, allEarnings, colorGroups, allProfiles,
}: {
  profile: Profile; isAdmin: boolean; isEmOrBelow: boolean
  myWeeklyEarnings: WeeklyEarning[]
  allEarnings: any[]; colorGroups: ColorGroup[]; allProfiles: any[]
}) {
  const [tab, setTab] = useState<'me' | 'leaderboard' | 'groups' | 'record'>('me')
  const [earningView, setEarningView] = useState<EarningView>('monthly')
  const [recordForm, setRecordForm] = useState({
    user_id: '', date: format(new Date(), 'yyyy-MM-dd'), amount: '', notes: '',
  })
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState(false)
  const [editingEntry, setEditingEntry] = useState<any | null>(null)
  const [statusFilter, setStatusFilter] = useState('all')
  const [groupFilter, setGroupFilter] = useState('all')
  const [monthFilter, setMonthFilter] = useState(format(new Date(), 'yyyy-MM'))

  // My monthly earnings aggregation
  const myMonthlyEarnings = useMemo(() => {
    const map = new Map<string, number>()
    for (const e of myWeeklyEarnings) {
      const monthStr = e.week_start.slice(0, 7)
      map.set(monthStr, (map.get(monthStr) ?? 0) + Number(e.amount_usd))
    }
    return Array.from(map.entries())
      .map(([month, total]) => ({ month, total, label: format(parseISO(month + '-01'), 'MMM yyyy') }))
      .sort((a, b) => b.month.localeCompare(a.month))
  }, [myWeeklyEarnings])

  const myTotal = myWeeklyEarnings.reduce((s, e) => s + Number(e.amount_usd), 0)
  const myThisMonth = myMonthlyEarnings.find(m => m.month === format(new Date(), 'yyyy-MM'))?.total ?? 0
  const myBestWeek = myWeeklyEarnings.length > 0 ? Math.max(...myWeeklyEarnings.map(e => Number(e.amount_usd))) : 0

  // Leaderboard — filtered by selected month
  const leaderboard = useMemo(() => {
    const filtered = allEarnings.filter(e => {
      const monthStr = e.week_start.slice(0, 7)
      return monthStr === monthFilter
    })
    const map = new Map<string, { id: string; full_name: string; member_id: string; status: string; group_name: string; group_color: string; total: number }>()
    for (const e of filtered) {
      const p = e.profiles
      if (!p) continue
      if (statusFilter !== 'all' && p.status !== statusFilter) continue
      if (groupFilter !== 'all' && p.color_groups?.code !== groupFilter) continue
      const ex = map.get(p.id) ?? {
        id: p.id, full_name: p.full_name, member_id: p.member_id, status: p.status,
        group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#ccc', total: 0,
      }
      ex.total += Number(e.amount_usd)
      map.set(p.id, ex)
    }
    return Array.from(map.values()).sort((a, b) => b.total - a.total)
  }, [allEarnings, monthFilter, statusFilter, groupFilter])

  // Group totals for selected month
  const groupTotals = useMemo(() => {
    const filtered = allEarnings.filter(e => e.week_start.slice(0, 7) === monthFilter)
    const map = new Map<string, { name: string; hex_color: string; total: number; count: number }>()
    for (const e of filtered) {
      const g = e.profiles?.color_groups
      if (!g) continue
      const ex = map.get(g.name) ?? { name: g.name, hex_color: g.hex_color, total: 0, count: 0 }
      ex.total += Number(e.amount_usd)
      ex.count++
      map.set(g.name, ex)
    }
    return Array.from(map.values()).sort((a, b) => b.total - a.total)
  }, [allEarnings, monthFilter])

  // Available months for filter
  const availableMonths = useMemo(() => {
    const months = new Set<string>()
    allEarnings.forEach(e => months.add(e.week_start.slice(0, 7)))
    return Array.from(months).sort().reverse()
  }, [allEarnings])

  // Most recent individual earning entries — used for the editable list
  const recentEntries = useMemo(() => {
    return [...allEarnings]
      .sort((a, b) => b.week_start.localeCompare(a.week_start))
      .slice(0, 30)
  }, [allEarnings])

  function startEdit(entry: any) {
    setEditingEntry(entry)
    setRecordForm({
      user_id: entry.user_id,
      date: entry.week_start,
      amount: String(entry.amount_usd),
      notes: entry.notes ?? '',
    })
    setTab('record')
  }

  async function recordEarning() {
    if (!recordForm.user_id || !recordForm.amount || !recordForm.date) return
    setLoading(true); setMsg(null)
    const supabase = createClient()
    // Determine week bounds from the selected date
    const selectedDate = new Date(recordForm.date)
    const weekStart = startOfWeek(selectedDate, { weekStartsOn: 6 })
    const weekEnd = endOfWeek(selectedDate, { weekStartsOn: 6 })

    const { error } = await supabase.from('weekly_earnings').upsert({
      user_id: recordForm.user_id,
      week_start: format(weekStart, 'yyyy-MM-dd'),
      week_end: format(weekEnd, 'yyyy-MM-dd'),
      amount_usd: Number(recordForm.amount),
      recorded_by: profile.id,
      notes: recordForm.notes || null,
    }, { onConflict: 'user_id,week_start' })

    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: `${editingEntry ? 'Earnings updated' : 'Earnings recorded'} for ${format(weekStart, 'MMM d')} – ${format(weekEnd, 'MMM d, yyyy')}` })
      setRecordForm(p => ({ ...p, amount: '', notes: '' }))
      setEditingEntry(null)
      setTimeout(() => window.location.reload(), 1200)
    }
    setLoading(false)
  }

  const monthLabel = (m: string) => format(parseISO(m + '-01'), 'MMMM yyyy')

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {[
          { id: 'me', label: 'My Earnings' },
          ...(isAdmin ? [
            { id: 'leaderboard', label: 'Top Earners' },
            { id: 'groups', label: 'Group Rankings' },
            { id: 'record', label: 'Record Earnings' },
          ] : []),
        ].map(t => (
          <button key={t.id} onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* ── MY EARNINGS ── */}
      {tab === 'me' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            <div className="card p-4 bg-green-50">
              <div className="text-xs text-gray-500 mb-1">This Month</div>
              <div className="text-2xl font-extrabold text-green-700">{formatCurrency(myThisMonth)}</div>
            </div>
            <div className="card p-4 bg-blue-50">
              <div className="text-xs text-gray-500 mb-1">All Time Total</div>
              <div className="text-2xl font-extrabold text-blue-700">{formatCurrency(myTotal)}</div>
            </div>
            <div className="card p-4 bg-purple-50">
              <div className="text-xs text-gray-500 mb-1">Best Single Week</div>
              <div className="text-2xl font-extrabold text-purple-700">{formatCurrency(myBestWeek)}</div>
            </div>
          </div>

          {/* View toggle */}
          <div className="flex gap-2">
            {(['monthly', 'weekly'] as EarningView[]).map(v => (
              <button key={v} onClick={() => setEarningView(v)}
                className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-all border ${earningView === v ? 'bg-brand-600 text-white border-brand-600' : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300'}`}>
                {v === 'monthly' ? 'Monthly View' : 'Weekly View'}
              </button>
            ))}
          </div>

          {earningView === 'monthly' ? (
            <div className="card overflow-x-auto">
              <div className="p-4 border-b border-gray-100"><h2 className="section-title">Monthly Earnings</h2></div>
              {myMonthlyEarnings.length === 0 ? (
                <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
              ) : (
                <>
                  <div className="p-4">
                    <ResponsiveContainer width="100%" height={200}>
                      <BarChart data={[...myMonthlyEarnings].reverse()}>
                        <XAxis dataKey="label" tick={{ fontSize: 11 }} />
                        <YAxis tick={{ fontSize: 11 }} tickFormatter={v => `$${v}`} />
                        <Tooltip formatter={(v: number) => formatCurrency(v)} />
                        <Bar dataKey="total" fill="#4f46e5" radius={[4,4,0,0]} />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                  <table className="w-full text-sm">
                    <thead className="border-t border-gray-100"><tr>
                      <th className="table-th">Month</th>
                      <th className="table-th">Total Earned</th>
                    </tr></thead>
                    <tbody>
                      {myMonthlyEarnings.map(m => (
                        <tr key={m.month} className={`table-row ${m.month === format(new Date(), 'yyyy-MM') ? 'bg-green-50' : ''}`}>
                          <td className="table-td font-medium">{m.label}</td>
                          <td className="table-td font-bold text-green-700">{formatCurrency(m.total)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </>
              )}
            </div>
          ) : (
            <div className="card overflow-x-auto">
              <div className="p-4 border-b border-gray-100"><h2 className="section-title">Weekly Earnings History</h2></div>
              {myWeeklyEarnings.length === 0 ? (
                <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
              ) : (
                <table className="w-full text-sm">
                  <thead className="border-b border-gray-100"><tr>
                    <th className="table-th">Week</th>
                    <th className="table-th">Amount</th>
                    <th className="table-th">Notes</th>
                  </tr></thead>
                  <tbody>
                    {myWeeklyEarnings.map(e => (
                      <tr key={e.id} className="table-row">
                        <td className="table-td">{format(parseISO(e.week_start), 'MMM d')} – {format(parseISO(e.week_end ?? e.week_start), 'MMM d, yyyy')}</td>
                        <td className="table-td font-bold text-green-700">{formatCurrency(Number(e.amount_usd))}</td>
                        <td className="table-td text-gray-400 text-xs">{e.notes ?? '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}
        </div>
      )}

      {/* ── TOP EARNERS ── */}
      {tab === 'leaderboard' && isAdmin && (
        <div className="space-y-4">
          <div className="flex gap-3 flex-wrap items-center">
            <select className="input w-auto" value={monthFilter} onChange={e => setMonthFilter(e.target.value)}>
              {availableMonths.length === 0
                ? <option value={format(new Date(), 'yyyy-MM')}>{monthLabel(format(new Date(), 'yyyy-MM'))}</option>
                : availableMonths.map(m => <option key={m} value={m}>{monthLabel(m)}</option>)
              }
            </select>
            <select className="input w-auto" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
              <option value="all">All Statuses</option>
              {['member','distributor','manager','executive_manager'].map(s => (
                <option key={s} value={s}>{getStatusLabel(s as any)}</option>
              ))}
            </select>
            <select className="input w-auto" value={groupFilter} onChange={e => setGroupFilter(e.target.value)}>
              <option value="all">All Groups</option>
              {colorGroups.map(g => <option key={g.code} value={g.code}>{g.name}</option>)}
            </select>
          </div>

          <div className="card p-4 bg-brand-50 border-brand-200">
            <div className="text-xs text-brand-600 font-semibold">Top Earners — {monthLabel(monthFilter)}</div>
            <div className="text-xs text-brand-400 mt-0.5">Executive Manager and below only</div>
          </div>

          <div className="card overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-gray-100"><tr>
                <th className="table-th">Rank</th>
                <th className="table-th">Name</th>
                <th className="table-th">ID</th>
                <th className="table-th">Status</th>
                <th className="table-th">Group</th>
                <th className="table-th">Earned This Month</th>
              </tr></thead>
              <tbody>
                {leaderboard.length === 0 ? (
                  <tr><td colSpan={6} className="table-td text-center text-gray-400 py-8">No earnings recorded for {monthLabel(monthFilter)}</td></tr>
                ) : leaderboard.map((p, i) => (
                  <tr key={p.id} className={`table-row ${p.id === profile.id ? 'bg-brand-50' : ''}`}>
                    <td className="table-td">
                      <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold ${i < 3 ? 'bg-yellow-100 text-yellow-700' : 'bg-gray-100 text-gray-500'}`}>{i + 1}</div>
                    </td>
                    <td className="table-td font-medium">{p.full_name} {p.id === profile.id && <span className="text-brand-600 text-xs">(You)</span>}</td>
                    <td className="table-td text-gray-400">{p.member_id}</td>
                    <td className="table-td"><span className={`badge ${getStatusColor(p.status as any)}`}>{getStatusLabel(p.status as any)}</span></td>
                    <td className="table-td">
                      <div className="flex items-center gap-1.5">
                        <div className="w-3 h-3 rounded-full" style={{ backgroundColor: p.group_color }} />
                        {p.group_name}
                      </div>
                    </td>
                    <td className="table-td font-bold text-green-700">{formatCurrency(p.total)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── GROUP RANKINGS ── */}
      {tab === 'groups' && isAdmin && (
        <div className="space-y-4">
          <div className="flex gap-3">
            <select className="input w-auto" value={monthFilter} onChange={e => setMonthFilter(e.target.value)}>
              {availableMonths.length === 0
                ? <option value={format(new Date(), 'yyyy-MM')}>{monthLabel(format(new Date(), 'yyyy-MM'))}</option>
                : availableMonths.map(m => <option key={m} value={m}>{monthLabel(m)}</option>)
              }
            </select>
          </div>

          {groupTotals.length > 0 && (
            <div className="card p-5">
              <h2 className="section-title mb-4">Group Earnings — {monthLabel(monthFilter)}</h2>
              <ResponsiveContainer width="100%" height={240}>
                <BarChart data={groupTotals}>
                  <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                  <YAxis tick={{ fontSize: 11 }} tickFormatter={v => `$${v}`} />
                  <Tooltip formatter={(v: number) => formatCurrency(v)} />
                  <Bar dataKey="total" radius={[4,4,0,0]}>
                    {groupTotals.map((g, i) => <Cell key={i} fill={g.hex_color} />)}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}

          <div className="card overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-gray-100"><tr>
                <th className="table-th">Rank</th>
                <th className="table-th">Group</th>
                <th className="table-th">Total Earned</th>
                <th className="table-th">Earners</th>
              </tr></thead>
              <tbody>
                {groupTotals.length === 0 ? (
                  <tr><td colSpan={4} className="table-td text-center text-gray-400 py-8">No data for {monthLabel(monthFilter)}</td></tr>
                ) : groupTotals.map((g, i) => (
                  <tr key={g.name} className="table-row">
                    <td className="table-td font-bold text-gray-500">{i + 1}</td>
                    <td className="table-td">
                      <div className="flex items-center gap-2">
                        <div className="w-4 h-4 rounded-full" style={{ backgroundColor: g.hex_color }} />
                        <span className="font-medium">{g.name}</span>
                      </div>
                    </td>
                    <td className="table-td font-bold text-green-700">{formatCurrency(g.total)}</td>
                    <td className="table-td text-gray-500">{g.count}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── RECORD EARNINGS ── */}
      {tab === 'record' && isAdmin && (
        <div className="space-y-6">
          <div className="card p-6 max-w-lg">
            <div className="flex items-center justify-between mb-1">
              <h2 className="section-title">{editingEntry ? 'Edit Earnings Entry' : 'Record Earnings'}</h2>
              {editingEntry && (
                <button onClick={() => { setEditingEntry(null); setRecordForm({ user_id: '', date: format(new Date(), 'yyyy-MM-dd'), amount: '', notes: '' }) }}
                  className="text-xs text-gray-400 hover:text-gray-600">Cancel Edit</button>
              )}
            </div>
            <p className="text-sm text-gray-500 mb-4">
              {editingEntry
                ? 'Editing an existing entry — saving will overwrite the amount/notes for this person\'s week.'
                : 'Select the member and the date the earnings were made. The app will automatically assign it to the correct week and month.'}
            </p>
            <div className="space-y-4">
              <div>
                <label className="label">Member *</label>
                <select className="input" value={recordForm.user_id} disabled={!!editingEntry} onChange={e => setRecordForm(p => ({ ...p, user_id: e.target.value }))}>
                  <option value="">Select member…</option>
                  {allProfiles.map((p: any) => (
                    <option key={p.id} value={p.id}>{p.full_name} ({p.member_id ?? 'No ID'})</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="label">Date Earned *</label>
                <input className="input" type="date" value={recordForm.date} disabled={!!editingEntry}
                  onChange={e => setRecordForm(p => ({ ...p, date: e.target.value }))} />
                {recordForm.date && (
                  <p className="text-xs text-gray-400 mt-1">
                    This will be recorded under: <strong>{format(startOfWeek(new Date(recordForm.date), { weekStartsOn: 6 }), 'MMM d')} – {format(endOfWeek(new Date(recordForm.date), { weekStartsOn: 6 }), 'MMM d, yyyy')}</strong>
                    {' '} · Month: <strong>{format(new Date(recordForm.date), 'MMMM yyyy')}</strong>
                  </p>
                )}
              </div>

              <div>
                <label className="label">Amount (USD) *</label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 font-medium">$</span>
                  <input className="input pl-7" type="number" step="0.01" min="0"
                    value={recordForm.amount} onChange={e => setRecordForm(p => ({ ...p, amount: e.target.value }))}
                    placeholder="0.00" />
                </div>
              </div>

              <div>
                <label className="label">Notes (optional)</label>
                <input className="input" value={recordForm.notes}
                  onChange={e => setRecordForm(p => ({ ...p, notes: e.target.value }))}
                  placeholder="e.g. Fiverr order, client payment…" />
              </div>

              {msg && (
                <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
                  {msg.text}
                </div>
              )}

              <button onClick={recordEarning} disabled={loading || !recordForm.user_id || !recordForm.amount || !recordForm.date}
                className="btn-primary w-full py-3">
                {loading ? (editingEntry ? 'Updating…' : 'Recording…') : (editingEntry ? 'Update Earnings' : 'Record Earnings')}
              </button>
            </div>
          </div>

          {/* Recent entries — click Edit to adjust amount/notes on any past entry */}
          <div className="card overflow-x-auto max-w-3xl">
            <div className="p-4 border-b border-gray-100"><h2 className="section-title">Recent Entries</h2></div>
            {recentEntries.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="border-b border-gray-100"><tr>
                  <th className="table-th">Person</th>
                  <th className="table-th">Week</th>
                  <th className="table-th">Amount</th>
                  <th className="table-th"></th>
                </tr></thead>
                <tbody>
                  {recentEntries.map((e: any) => (
                    <tr key={e.id ?? `${e.user_id}-${e.week_start}`} className="table-row">
                      <td className="table-td font-medium">{e.profiles?.full_name ?? '—'}</td>
                      <td className="table-td text-gray-400">{format(parseISO(e.week_start), 'MMM d')} – {format(parseISO(e.week_end ?? e.week_start), 'MMM d, yyyy')}</td>
                      <td className="table-td font-bold text-green-700">{formatCurrency(Number(e.amount_usd))}</td>
                      <td className="table-td text-right">
                        <button onClick={() => startEdit(e)} className="text-xs font-semibold text-brand-600 hover:text-brand-700">Edit</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
CLAUDE_EOF_MARKER

echo "Staging and committing..."
git add .
git commit -m "feat: editable earnings entries, Most Consistent Attendance leaderboard, dashboard earnings error logging"
git push origin main
echo "Done. Vercel should start redeploying now."
