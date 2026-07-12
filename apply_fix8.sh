#!/usr/bin/env bash
set -e
echo "Writing updated files..."

mkdir -p "app/(app)/attendance"
cat > "app/(app)/attendance/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format, startOfMonth, endOfMonth } from 'date-fns'
import AttendanceClient from './AttendanceClient'
import { getEffectiveProfile } from '@/lib/view-as'

export default async function AttendancePage({
  searchParams,
}: {
  searchParams: { date?: string }
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: realProfile } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*)')
    .eq('id', user.id)
    .single()
  if (!realProfile) redirect('/login')

  const { profile } = await getEffectiveProfile(supabase, realProfile)

  // Admin = main admin, director, or co-admin
  // Only these can see sign-in features and office view
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin
  const selectedDate = searchParams.date ?? format(new Date(), 'yyyy-MM-dd')

  // My attendance for current month (everyone sees this)
  const { data: myMonthAttendance } = await supabase
    .from('attendance')
    .select('*')
    .eq('user_id', profile.id)
    .gte('date', format(startOfMonth(new Date()), 'yyyy-MM-dd'))
    .lte('date', format(endOfMonth(new Date()), 'yyyy-MM-dd'))
    .order('date', { ascending: false })

  // Today's record (everyone sees their own)
  const today = format(new Date(), 'yyyy-MM-dd')
  const { data: todayRecord } = await supabase
    .from('attendance')
    .select('*')
    .eq('user_id', profile.id)
    .eq('date', today)
    .maybeSingle()

  // Office view — admin/director/co-admin only
  let dateAttendance: unknown[] = []
  let allApprovedProfiles: { id: string; full_name: string; member_id: string | null }[] = []
  if (isAdmin) {
    const { data } = await supabase
      .from('attendance')
      .select('*, profiles!inner(id, full_name, member_id, status, color_group_id, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .eq('date', selectedDate)
      .not('sign_in_time', 'is', null)
      .order('sign_in_time')
    dateAttendance = data ?? []

    const { data: people } = await supabase
      .from('profiles')
      .select('id, full_name, member_id')
      .eq('approved', true)
      .order('full_name')
    allApprovedProfiles = people ?? []
  }

  return (
    <AttendanceClient
      profile={profile}
      isAdmin={isAdmin}
      myMonthAttendance={myMonthAttendance ?? []}
      todayRecord={todayRecord}
      selectedDate={selectedDate}
      dateAttendance={dateAttendance as any[]}
      allApprovedProfiles={allApprovedProfiles}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/community"
cat > "app/(app)/community/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import CommunityClient from './CommunityClient'

export default async function CommunityPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const { data: posts } = await supabase
    .from('community_posts')
    .select('*, profiles(id, full_name, member_id, profile_picture, status, color_groups!profiles_color_group_id_fkey(name, hex_color))')
    .order('created_at', { ascending: false })
    .limit(100)

  return (
    <CommunityClient
      profile={profile}
      initialPosts={(posts ?? []) as any[]}
      isAdmin={profile.is_admin || profile.is_director || profile.is_co_admin}
    />
  )
}
CLAUDE_EOF_MARKER

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
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/events"
cat > "app/(app)/events/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import EventsClient from './EventsClient'

export default async function EventsPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const { data: events } = await supabase
    .from('events')
    .select('*, profiles(full_name)')
    .order('event_date', { ascending: true })

  return (
    <EventsClient
      profile={profile}
      events={(events ?? []) as any[]}
      isAdmin={profile.is_admin || profile.is_director || profile.is_co_admin}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/feedback"
cat > "app/(app)/feedback/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import FeedbackClient from './FeedbackClient'

export default async function FeedbackPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin

  // My own feedback
  const { data: myFeedback } = await supabase
    .from('feedback')
    .select('*, responder:responded_by(full_name)')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })

  // Admin: all feedback with user info
  const { data: allFeedback } = isAdmin
    ? await supabase
        .from('feedback')
        .select('*, user:user_id(full_name, member_id, email), responder:responded_by(full_name)')
        .order('created_at', { ascending: false })
    : { data: null }

  return (
    <FeedbackClient
      profile={profile}
      isAdmin={isAdmin}
      myFeedback={(myFeedback ?? []) as any[]}
      allFeedback={(allFeedback ?? []) as any[]}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/group"
cat > "app/(app)/group/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import GroupClient from './GroupClient'
import { getEffectiveProfile } from '@/lib/view-as'

export default async function GroupPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: realProfile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!realProfile) redirect('/login')

  const { profile } = await getEffectiveProfile(supabase, realProfile)
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

mkdir -p "app/(app)"
cat > "app/(app)/layout.tsx" << 'CLAUDE_EOF_MARKER'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import Sidebar from '@/components/layout/Sidebar'
import Header from '@/components/layout/Header'
import ViewAsBanner from '@/components/admin/ViewAsBanner'
import { getEffectiveProfile } from '@/lib/view-as'

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  const { data: realProfile, error: profileError } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*)')
    .eq('id', user.id)
    .single()

  // PGRST116 = no row found. Any other error is a real query/DB problem,
  // not "not yet approved" — don't mask it as pending-approval.
  if (profileError && profileError.code !== 'PGRST116') {
    console.error('AppLayout profile query failed:', profileError)
    throw new Error(`Failed to load profile: ${profileError.message}`)
  }

  if (!realProfile) redirect('/pending-approval')
  if (!realProfile.approved && !realProfile.is_admin && !realProfile.is_director && !realProfile.is_co_admin) redirect('/pending-approval')

  // Admin "View As": every page's nav, header, and content reflect whoever
  // the admin is currently viewing as — a true WYSIWYG preview of what that
  // person sees. The banner (with its Exit button) is always visible so
  // there's never any doubt this is a preview, not the admin's own account.
  const { profile, isViewingAs, viewAsName } = await getEffectiveProfile(supabase, realProfile)

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50">
      <Sidebar profile={profile} />
      <div className="flex-1 flex flex-col overflow-hidden">
        {isViewingAs && viewAsName && <ViewAsBanner name={viewAsName} />}
        <Header profile={profile} />
        <main className="flex-1 overflow-y-auto p-4 sm:p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/money"
cat > "app/(app)/money/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import MoneyClient from './MoneyClient'
import { getEffectiveProfile } from '@/lib/view-as'

export default async function MoneyPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: realProfile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!realProfile) redirect('/login')

  const { profile } = await getEffectiveProfile(supabase, realProfile)

  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin
  const isEmOrBelow = ['member','distributor','manager','executive_manager'].includes(profile.status)

  const [
    { data: myWeeklyEarnings },
    { data: allEarnings },
    { data: colorGroups },
    { data: allProfiles },
  ] = await Promise.all([
    supabase.from('weekly_earnings')
      .select('*')
      .eq('user_id', profile.id)
      .order('week_start', { ascending: false }),

    isAdmin
      ? supabase.from('weekly_earnings')
          .select('*, profiles!inner(id, full_name, member_id, status, color_group_id, color_groups!profiles_color_group_id_fkey(name, hex_color, code))')
          .order('week_start', { ascending: false })
      : { data: [] },

    supabase.from('color_groups').select('*').order('name'),

    // Everyone approved can have earnings recorded against them — not just EM and below.
    // (The "Executive Manager and below" restriction only applies to the public
    // Top Earners / Consistent Earners leaderboards on the dashboard.)
    isAdmin
      ? supabase.from('profiles')
          .select('id, full_name, member_id, status, color_groups!profiles_color_group_id_fkey(name)')
          .eq('approved', true)
          .order('full_name')
      : { data: [] },
  ])

  return (
    <MoneyClient
      profile={profile}
      isAdmin={isAdmin}
      isEmOrBelow={isEmOrBelow}
      myWeeklyEarnings={myWeeklyEarnings ?? []}
      allEarnings={(allEarnings ?? []) as any[]}
      colorGroups={colorGroups ?? []}
      allProfiles={(allProfiles ?? []) as any[]}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/my-group"
cat > "app/(app)/my-group/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import MyGroupClient from './MyGroupClient'

export default async function MyGroupPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  // Only group leaders can access this page
  const isGroupLeader = profile.member_id?.endsWith('-001') ?? false
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin
  if (!isGroupLeader && !isAdmin) redirect('/dashboard')

  // Get all members in the same color group
  const { data: groupMembers } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(name, hex_color), sponsor:sponsor_id(id, full_name, member_id)')
    .eq('color_group_id', profile.color_group_id)
    .eq('approved', true)
    .neq('id', user.id)
    .order('full_name')

  // Get tasks assigned by this user
  const { data: myTasks } = await supabase
    .from('tasks')
    .select('*, assignee:assigned_to(id, full_name, member_id)')
    .eq('assigned_by', user.id)
    .order('created_at', { ascending: false })

  // Get this week's attendance for group members
  const today = new Date()
  const weekStart = new Date(today); weekStart.setDate(today.getDate() - today.getDay() + 1)
  const { data: groupAttendance } = await supabase
    .from('attendance')
    .select('user_id, date, sign_in_time')
    .in('user_id', [user.id, ...(groupMembers ?? []).map(m => m.id)])
    .gte('date', weekStart.toISOString().slice(0, 10))
    .not('sign_in_time', 'is', null)

  // Get downline (personal line)
  function getDownline(rootId: string, profiles: any[]): string[] {
    const direct = profiles.filter(p => p.sponsor_id === rootId).map(p => p.id)
    return [...direct, ...direct.flatMap(id => getDownline(id, profiles))]
  }

  const { data: allProfiles } = await supabase
    .from('profiles')
    .select('id, full_name, member_id, status, sponsor_id, profile_picture, color_groups!profiles_color_group_id_fkey(name, hex_color)')
    .eq('approved', true)
  const downlineIds = getDownline(user.id, allProfiles ?? [])
  const myDownline = (allProfiles ?? []).filter(p => downlineIds.includes(p.id))

  return (
    <MyGroupClient
      profile={profile}
      groupMembers={groupMembers ?? []}
      myTasks={myTasks ?? []}
      groupAttendance={groupAttendance ?? []}
      myDownline={myDownline}
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
import { ACTIVITY_STATUS_LABELS, ACTIVITY_STATUS_COLORS, statusRank } from '@/lib/types'
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

  // A co-admin's own downline (used for the "can view upline only if it's my downline" rule)
  function getDownlineIds(rootId: string): string[] {
    const direct = allProfiles.filter(p => p.sponsor_id === rootId).map(p => p.id)
    return [...direct, ...direct.flatMap(id => getDownlineIds(id))]
  }
  const myDownlineIds = isCoAdmin ? getDownlineIds(currentProfile.id) : []

  // The one co-admin this person (if Director/Co-Admin, not main admin) has personally assigned
  const myAssignedCoAdmin = allProfiles.find(p => p.co_admin_assigned_by === currentProfile.id && p.is_co_admin)

  // Hide main admin from everyone but main admin; hide Directors from Co-Admins.
  // Co-Admins additionally cannot view anyone ABOVE them in status rank unless
  // that person is in their own downline — but can always view anyone at or
  // below their rank, downline or not.
  const visibleProfiles = allProfiles.filter(p => {
    if (!isMainAdmin && p.id === mainAdminId) return false
    if (isCoAdmin && p.is_director) return false
    if (isCoAdmin && statusRank(p.status) > statusRank(currentProfile.status) && !myDownlineIds.includes(p.id)) return false
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
    if (!isMainAdmin && !isDirector && !isCoAdmin) return

    if (!isMainAdmin) {
      // Directors and Co-Admins may each assign exactly ONE co-admin of their own
      if (!current) {
        if (myAssignedCoAdmin) {
          setMsg({ type: 'error', text: `You can only assign one Co-Admin. You already made ${myAssignedCoAdmin.full_name} a Co-Admin — remove them first if you want to choose someone else.` })
          return
        }
      } else {
        const target = allProfiles.find(p => p.id === profileId)
        if (target?.co_admin_assigned_by !== currentProfile.id) {
          setMsg({ type: 'error', text: 'You can only remove a Co-Admin that you personally assigned.' })
          return
        }
      }
    }

    await updateProfile(profileId, {
      is_co_admin: !current,
      co_admin_assigned_by: !current ? currentProfile.id : null,
    })
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

        {/* Co-admin toggle — main admin unrestricted; Directors/Co-Admins may
            each assign exactly one of their own and can only remove that one */}
        {(isMainAdmin || isDirector || isCoAdmin) && p.id !== currentProfile.id && (() => {
          const canRemoveThis = isMainAdmin || p.co_admin_assigned_by === currentProfile.id
          const canGrantMore = isMainAdmin || !myAssignedCoAdmin
          const disabled = p.is_co_admin ? !canRemoveThis : !canGrantMore
          return (
            <div className="flex items-center gap-3 pt-2 border-t border-gray-100">
              <Shield size={15} className="text-purple-500" />
              <span className="text-sm text-gray-700 flex-1">Co-Admin Access</span>
              <button onClick={() => toggleCoAdmin(p.id, p.is_co_admin)} disabled={disabled}
                title={disabled ? (p.is_co_admin ? "Only who assigned this Co-Admin can remove them" : "You've already assigned your one Co-Admin") : undefined}
                className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all ${disabled ? 'bg-gray-50 text-gray-300 cursor-not-allowed' : p.is_co_admin ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-purple-50'}`}>
                {p.is_co_admin ? 'Remove Co-Admin' : 'Make Co-Admin'}
              </button>
            </div>
          )
        })()}
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

mkdir -p "app/(app)/scouting"
cat > "app/(app)/scouting/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import ScoutingClient from './ScoutingClient'
import { getEffectiveProfile } from '@/lib/view-as'

export default async function ScoutingPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: realProfile } = await supabase.from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!realProfile) redirect('/login')

  const { profile } = await getEffectiveProfile(supabase, realProfile)
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin

  const [
    { data: myRecords, count: myCount },
    { data: allRecords },
    { data: groupStats },
  ] = await Promise.all([
    supabase.from('scouting_records')
      .select('*', { count: 'exact' })
      .eq('user_id', profile.id)
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
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/settings"
cat > "app/(app)/settings/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import SettingsClient from './SettingsClient'

export default async function SettingsPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const { data: settings } = await supabase.from('app_settings').select('*')
  const settingsMap = Object.fromEntries((settings ?? []).map(s => [s.key, s.value]))

  const { data: myTasks } = await supabase
    .from('tasks')
    .select('*, assigner:assigned_by(id, full_name)')
    .eq('assigned_to', user.id)
    .eq('completed', false)
    .order('created_at', { ascending: false })

  return (
    <SettingsClient
      profile={profile}
      settings={settingsMap}
      isAdmin={profile.is_admin || profile.is_director || profile.is_co_admin}
      myTasks={(myTasks ?? []) as any[]}
    />
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/team"
cat > "app/(app)/team/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import TeamClient from './TeamClient'
import { computeTeam, STATUS_ORDER, UserStatus } from '@/lib/types'
import type { Profile } from '@/lib/types'
import { getEffectiveProfile } from '@/lib/view-as'

export default async function TeamPage({ searchParams }: { searchParams: { filter?: string; member?: string } }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: realProfile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!realProfile) redirect('/login')

  const { profile } = await getEffectiveProfile(supabase, realProfile)
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin

  const { data: allProfiles } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(name, hex_color, code), sponsor:sponsor_id(id, full_name, member_id)')
    .eq('approved', true)
    .order('full_name')

  const profiles = allProfiles ?? []

  // Compute all team filter options for this person
  const teamFilters: Record<string, string[]> = {}
  teamFilters['all'] = computeTeam(profile.id, 'member' as UserStatus, profiles as Profile[])

  // Build available filter levels based on what statuses exist in my downline
  const myFullDownline = teamFilters['all']
  const statusesInDownline = new Set(
    profiles.filter(p => myFullDownline.includes(p.id)).map(p => p.status)
  )

  STATUS_ORDER.forEach(status => {
    if (statusesInDownline.has(status)) {
      teamFilters[status] = computeTeam(profile.id, status as UserStatus, profiles as Profile[])
    }
  })

  const activeFilter = (searchParams.filter as UserStatus) || 'all'
  const filteredTeamIds = teamFilters[activeFilter] ?? teamFilters['all']
  const myTeam = profiles.filter(p => filteredTeamIds.includes(p.id))

  // Viewing a specific member's tree
  const viewingMember = searchParams.member
    ? profiles.find(p => p.id === searchParams.member) ?? null
    : null

  return (
    <TeamClient
      profile={profile as Profile}
      isAdmin={isAdmin}
      myTeam={myTeam as Profile[]}
      allProfiles={profiles as Profile[]}
      viewingMember={viewingMember as Profile | null}
      availableFilters={Object.keys(teamFilters)}
      activeFilter={activeFilter}
      teamCounts={Object.fromEntries(Object.entries(teamFilters).map(([k, v]) => [k, v.length]))}
    />
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

mkdir -p "app/attendance/scan"
cat > "app/attendance/scan/page.tsx" << 'CLAUDE_EOF_MARKER'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import QRScanner from '@/components/attendance/QRScanner'

export default async function ScanPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, is_admin, is_director')
    .eq('id', user.id)
    .single()

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-6">
          <div className="w-12 h-12 bg-brand-600 rounded-xl flex items-center justify-center mx-auto mb-3">
            <span className="text-white font-black text-lg">E</span>
          </div>
          <h1 className="text-xl font-bold text-gray-900">Elevate Attendance</h1>
        </div>
        <QRScanner
          isAdmin={profile?.is_admin || profile?.is_director || profile?.is_co_admin || false}
          adminProfileId={user.id}
        />
      </div>
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "components/layout"
cat > "components/layout/Header.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Menu, X, Bell, LayoutDashboard, Users, UserCheck, DollarSign, Search, Calendar, MessageSquare, Settings, QrCode, Group, LogOut } from 'lucide-react'
import type { Profile } from '@/lib/types'
import { getStatusLabel, isSmOrAbove } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/attendance': 'Attendance',
  '/team': 'My Team',
  '/group': 'My Group',
  '/people': 'People',
  '/money': 'Money Making',
  '/scouting': 'Scouting',
  '/community': 'Community',
  '/events': 'Events',
  '/settings': 'Settings',
}

export default function Header({ profile }: { profile: Profile }) {
  const pathname = usePathname()
  const router = useRouter()
  const [mobileOpen, setMobileOpen] = useState(false)
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin
  const isSm = isSmOrAbove(profile.status)

  const title = Object.entries(PAGE_TITLES).find(([k]) =>
    pathname === k || pathname.startsWith(k + '/')
  )?.[1] ?? 'Elevate'

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
  }

  const navItems = [
    { href: '/dashboard', label: 'Dashboard', icon: <LayoutDashboard size={18} /> },
    { href: '/attendance', label: 'Attendance', icon: <QrCode size={18} /> },
    { href: '/team', label: 'My Team', icon: <Users size={18} /> },
    ...(isSm || isAdmin ? [{ href: '/group', label: 'My Group', icon: <Group size={18} /> }] : []),
    ...(isAdmin ? [{ href: '/people', label: 'People', icon: <UserCheck size={18} /> }] : []),
    { href: '/money', label: 'Money Making', icon: <DollarSign size={18} /> },
    { href: '/scouting', label: 'Scouting', icon: <Search size={18} /> },
    { href: '/community', label: 'Community', icon: <MessageSquare size={18} /> },
    { href: '/events', label: 'Events', icon: <Calendar size={18} /> },
    { href: '/settings', label: 'Settings', icon: <Settings size={18} /> },
  ]

  return (
    <>
      <header className="bg-white border-b border-gray-200 px-4 sm:px-6 py-3 flex items-center justify-between flex-shrink-0">
        {/* Mobile menu button */}
        <button
          className="md:hidden p-2 rounded-lg text-gray-500 hover:bg-gray-100"
          onClick={() => setMobileOpen(true)}
        >
          <Menu size={20} />
        </button>

        <h1 className="text-lg font-bold text-gray-900">{title}</h1>

        <div className="flex items-center gap-2">
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold cursor-pointer"
            style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}
            title={profile.full_name ?? ''}
          >
            {(profile.full_name ?? '?').split(' ').filter(Boolean).map(n => n[0]).join('').slice(0, 2).toUpperCase()}
          </div>
        </div>
      </header>

      {/* Mobile sidebar */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div className="absolute inset-0 bg-black/40" onClick={() => setMobileOpen(false)} />
          <aside className="absolute left-0 top-0 bottom-0 w-72 bg-white flex flex-col overflow-y-auto shadow-2xl">
            <div className="flex items-center justify-between p-4 border-b border-gray-100">
              <div className="font-bold text-gray-900">Elevate</div>
              <button onClick={() => setMobileOpen(false)} className="p-2 rounded-lg hover:bg-gray-100">
                <X size={18} />
              </button>
            </div>

            <div className="px-4 py-3 border-b border-gray-100">
              <div className="text-sm font-semibold text-gray-900">{profile.full_name}</div>
              <div className="text-xs text-gray-400">{profile.member_id} · {getStatusLabel(profile.status)}</div>
            </div>

            <nav className="flex-1 p-3 space-y-0.5">
              {navItems.map(item => {
                const active = pathname === item.href
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    onClick={() => setMobileOpen(false)}
                    className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                      active ? 'bg-brand-600 text-white' : 'text-gray-600 hover:bg-gray-100'
                    }`}
                  >
                    {item.icon}
                    {item.label}
                  </Link>
                )
              })}
            </nav>

            <div className="p-3 border-t border-gray-100">
              <button onClick={handleSignOut} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-gray-500 hover:bg-red-50 hover:text-red-600">
                <LogOut size={18} />
                Sign Out
              </button>
            </div>
          </aside>
        </div>
      )}
    </>
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
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin || profile.is_co_admin
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
          {(profile.is_admin || profile.is_director || profile.is_co_admin) && (
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

mkdir -p "supabase"
cat > "supabase/schema.sql" << 'CLAUDE_EOF_MARKER'
-- =============================================
-- ELEVATE OFFICE TRACKER — COMPLETE SCHEMA
-- Run this in Supabase SQL Editor
-- =============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- =============================================
-- COLOR GROUPS
-- =============================================
create table if not exists color_groups (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  code text not null unique,        -- RED, GRN, BLU, etc.
  hex_color text not null default '#6366f1',
  member_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- Insert default color groups
insert into color_groups (name, code, hex_color) values
  ('Red',    'RED', '#ef4444'),
  ('Blue',   'BLU', '#3b82f6'),
  ('Green',  'GRN', '#22c55e'),
  ('Orange', 'ORG', '#f97316'),
  ('Yellow', 'YEL', '#eab308'),
  ('Purple', 'PRP', '#a855f7'),
  ('White',  'WHT', '#e5e7eb'),
  ('Gold',   'GLD', '#f59e0b'),
  ('Silver', 'SLV', '#94a3b8'),
  ('Black',  'BLK', '#1e293b')
on conflict do nothing;

-- =============================================
-- PROFILES (extends Supabase auth.users)
-- =============================================
do $$ begin
  create type user_status as enum (
    'member', 'distributor', 'manager',
    'senior_manager', 'executive_manager', 'director'
  );
exception when duplicate_object then null;
end $$;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  member_id text unique,             -- e.g. RED001
  status user_status not null default 'member',
  color_group_id uuid references color_groups(id),
  sponsor_id uuid references profiles(id),
  upline_sm_id uuid references profiles(id),
  is_admin boolean not null default false,
  is_director boolean not null default false,
  approved boolean not null default false,
  rejected boolean not null default false,
  rejection_reason text,
  profile_picture text,              -- storage URL
  about text,
  phone text,
  week_number integer not null default 1 check (week_number between 1 and 12),
  week_confirmed boolean not null default false,
  is_new_member boolean not null default false,
  new_member_month text,             -- YYYY-MM
  is_office_already boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trigger: auto-update updated_at
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create trigger profiles_updated_at before update on profiles
  for each row execute function update_updated_at();

-- =============================================
-- ATTENDANCE
-- =============================================
create table if not exists attendance (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  date date not null,
  sign_in_time timestamptz,
  sign_out_time timestamptz,
  is_night_session boolean not null default false,
  sign_in_note text,                 -- what did you do with your business yesterday/weekend
  sign_out_note text,                -- what did you do in the office today
  late_in boolean not null default false,
  late_out boolean not null default false,
  created_at timestamptz not null default now(),
  unique(user_id, date, is_night_session)
);

-- =============================================
-- WEEKLY EARNINGS
-- =============================================
create table if not exists weekly_earnings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  week_start date not null,          -- Saturday
  week_end date not null,            -- Friday
  amount_usd numeric(12,2) not null default 0,
  recorded_by uuid references profiles(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, week_start)
);

create trigger weekly_earnings_updated_at before update on weekly_earnings
  for each row execute function update_updated_at();

-- =============================================
-- SCOUTING RECORDS
-- =============================================
create table if not exists scouting_records (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  business_name text not null,
  rating text,
  reviews text,
  band text,
  profile_link text,
  industry text,
  email text,
  match_score text,
  issues_found text,
  status text default 'Pending',
  message_sent text,
  their_reply text,
  source text default 'Scout App',
  scouted_at timestamptz not null default now(),
  upload_batch_id uuid,
  unique(user_id, profile_link)
);

-- =============================================
-- EVENTS
-- =============================================
create table if not exists events (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  event_date date not null,
  event_time time,
  location text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

-- =============================================
-- COMMUNITY POSTS
-- =============================================
create table if not exists community_posts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  attachment_url text,
  attachment_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger community_posts_updated_at before update on community_posts
  for each row execute function update_updated_at();

-- =============================================
-- TASKS (assigned by SM to team)
-- =============================================
create table if not exists tasks (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  assigned_to uuid not null references profiles(id) on delete cascade,
  assigned_by uuid references profiles(id),
  due_date date,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

-- =============================================
-- APP SETTINGS
-- =============================================
create table if not exists app_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);

insert into app_settings (key, value) values
  ('app_name', 'Elevate Office Tracker'),
  ('app_logo', ''),
  ('about_us', 'Welcome to Elevate — where excellence meets accountability.'),
  ('primary_color', '#4f46e5'),
  ('font_family', 'Inter')
on conflict do nothing;

-- =============================================
-- MEMBER ID SEQUENCE per color group
-- =============================================
create table if not exists member_id_sequences (
  color_code text primary key,
  next_number integer not null default 1
);

insert into member_id_sequences (color_code, next_number)
select code, 1 from color_groups
on conflict do nothing;

-- Function to generate next member ID
create or replace function generate_member_id(p_color_code text)
returns text language plpgsql as $$
declare
  v_num integer;
  v_id text;
begin
  update member_id_sequences
  set next_number = next_number + 1
  where color_code = p_color_code
  returning next_number - 1 into v_num;

  if not found then
    insert into member_id_sequences (color_code, next_number) values (p_color_code, 2);
    v_num := 1;
  end if;

  v_id := p_color_code || lpad(v_num::text, 3, '0');
  return v_id;
end; $$;

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================

alter table profiles enable row level security;
alter table attendance enable row level security;
alter table weekly_earnings enable row level security;
alter table scouting_records enable row level security;
alter table events enable row level security;
alter table community_posts enable row level security;
alter table tasks enable row level security;
alter table color_groups enable row level security;
alter table app_settings enable row level security;

-- Helper: get current user's profile
create or replace function get_my_profile()
returns profiles language sql security definer stable as $$
  select * from profiles where id = auth.uid();
$$;

-- Helper: is admin or director
create or replace function is_admin_or_director()
returns boolean language sql security definer stable as $$
  select coalesce(
    (select is_admin or is_director or is_co_admin from profiles where id = auth.uid()),
    false
  );
$$;

-- Helper: is senior manager or above
create or replace function is_sm_or_above()
returns boolean language sql security definer stable as $$
  select coalesce(
    (select status in ('senior_manager','executive_manager','director')
     from profiles where id = auth.uid()),
    false
  );
$$;

-- PROFILES policies
create policy "Anyone can view approved profiles" on profiles
  for select using (approved = true);

create policy "Users can view own profile" on profiles
  for select using (id = auth.uid());

create policy "Admins view all profiles" on profiles
  for select using (is_admin_or_director());

create policy "Users update own profile" on profiles
  for update using (id = auth.uid())
  with check (id = auth.uid());

create policy "Admins manage all profiles" on profiles
  for all using (is_admin_or_director());

create policy "Allow insert on signup" on profiles
  for insert with check (id = auth.uid());

-- COLOR GROUPS policies
create policy "Anyone can view color groups" on color_groups
  for select using (true);

create policy "Admins manage color groups" on color_groups
  for all using (is_admin_or_director());

-- ATTENDANCE policies
create policy "Users view own attendance" on attendance
  for select using (user_id = auth.uid());

create policy "SM+ view team attendance" on attendance
  for select using (is_sm_or_above());

create policy "Admins view all attendance" on attendance
  for select using (is_admin_or_director());

create policy "Users manage own attendance" on attendance
  for all using (user_id = auth.uid());

create policy "Admins manage all attendance" on attendance
  for all using (is_admin_or_director());

-- WEEKLY EARNINGS policies
create policy "Members view own earnings" on weekly_earnings
  for select using (user_id = auth.uid());

create policy "SM+ view team earnings" on weekly_earnings
  for select using (is_sm_or_above());

create policy "Admins manage earnings" on weekly_earnings
  for all using (is_admin_or_director());

-- SCOUTING policies
create policy "Users view own scouting" on scouting_records
  for select using (user_id = auth.uid());

create policy "SM+ view team scouting" on scouting_records
  for select using (is_sm_or_above());

create policy "Users manage own scouting" on scouting_records
  for all using (user_id = auth.uid());

create policy "Admins manage all scouting" on scouting_records
  for all using (is_admin_or_director());

-- EVENTS policies
create policy "Anyone authenticated can view events" on events
  for select using (auth.uid() is not null);

create policy "Admins manage events" on events
  for all using (is_admin_or_director());

-- COMMUNITY policies
create policy "Anyone authenticated can view posts" on community_posts
  for select using (auth.uid() is not null);

create policy "Users manage own posts" on community_posts
  for all using (user_id = auth.uid());

create policy "Admins manage all posts" on community_posts
  for all using (is_admin_or_director());

-- TASKS policies
create policy "Users view own tasks" on tasks
  for select using (assigned_to = auth.uid() or assigned_by = auth.uid());

create policy "SM+ view and create tasks" on tasks
  for all using (is_sm_or_above());

-- APP SETTINGS policies
create policy "Anyone can read settings" on app_settings
  for select using (true);

create policy "Admins update settings" on app_settings
  for all using (is_admin_or_director());

-- =============================================
-- FEEDBACK
-- =============================================
create table if not exists feedback (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  message text not null,
  category text not null default 'general',  -- general, bug, feature, complaint
  status text not null default 'open',        -- open, in_review, resolved
  admin_response text,
  responded_by uuid references profiles(id),
  responded_at timestamptz,
  created_at timestamptz not null default now()
);

alter table feedback enable row level security;

create policy "Users view own feedback" on feedback
  for select using (user_id = auth.uid());

create policy "Users create feedback" on feedback
  for insert with check (user_id = auth.uid());

create policy "Admins manage all feedback" on feedback
  for all using (is_admin_or_director());

-- =============================================
-- STORAGE BUCKETS (run separately in dashboard)
-- =============================================
-- Create buckets: 'avatars' (public), 'attachments' (public)
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('attachments', 'attachments', true) on conflict (id) do nothing;

-- =============================================
-- SEED: Admin user setup
-- After running this schema, sign up normally, then run this in SQL Editor:
-- UPDATE profiles SET is_admin = true, is_director = true, approved = true,
--   status = 'director', week_number = 12
--   WHERE email = 'YOUR_ADMIN_EMAIL_HERE';
-- =============================================

-- =============================================
-- WEEK TRACKING SYSTEM
-- =============================================

-- Weekly assessment submissions
create table if not exists week_assessments (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  week_number integer not null check (week_number between 1 and 12),
  submitted boolean not null default false,
  submitted_at timestamptz,
  graded boolean not null default false,
  graded_at timestamptz,
  graded_by uuid references profiles(id),
  grade text,                          -- pass / fail / excellent
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, week_number)
);

alter table week_assessments enable row level security;

create policy "Users view own assessments" on week_assessments
  for select using (user_id = auth.uid());

create policy "Admins manage all assessments" on week_assessments
  for all using (is_admin_or_director());

create policy "SM view team assessments" on week_assessments
  for select using (is_sm_or_above());

-- Week advancement log (tracks who advanced, who repeated, pardons)
create table if not exists week_advancement_log (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  from_week integer not null,
  to_week integer not null,
  action text not null,               -- 'advanced' | 'repeated' | 'pardoned'
  attendance_days integer not null default 0,
  assessment_submitted boolean not null default false,
  assessment_graded boolean not null default false,
  admin_notes text,
  actioned_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

alter table week_advancement_log enable row level security;

create policy "Users view own advancement log" on week_advancement_log
  for select using (user_id = auth.uid());

create policy "Admins manage advancement log" on week_advancement_log
  for all using (is_admin_or_director());

-- Absence email log (tracks which emails were sent to avoid duplicates)
create table if not exists absence_emails (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  email_type text not null,           -- 'daily_miss' | 'weekly_summary'
  sent_at timestamptz not null default now(),
  date_missed date,                   -- for daily miss
  week_number integer,                -- for weekly summary
  miss_count integer,                 -- how many days missed that week
  delivered boolean not null default true,
  unique(user_id, email_type, date_missed)
);

alter table absence_emails enable row level security;

create policy "Admins manage absence emails" on absence_emails
  for all using (is_admin_or_director());

-- =============================================
-- ACTIVITY STATUS & MONTHLY EARNINGS
-- =============================================

-- Add activity_status to profiles
alter table profiles add column if not exists activity_status text not null default 'active'
  check (activity_status in ('active','suspended','inactive','left_office','another_location','moved_to_another_office'));

-- Monthly earnings view
create or replace view monthly_earnings as
select
  user_id,
  date_trunc('month', week_start::date)::date as month,
  to_char(week_start::date, 'YYYY-MM') as month_str,
  sum(amount_usd) as total_usd,
  count(*) as weeks_with_earnings
from weekly_earnings
group by user_id, date_trunc('month', week_start::date)::date, to_char(week_start::date, 'YYYY-MM');

-- =============================================
-- GROUP LEADER & CONSISTENT EARNER POINTS
-- =============================================

-- Add is_group_leader to profiles (set when member_id ends in 001)
alter table profiles add column if not exists is_group_leader boolean not null default false;

-- Consistent earner points table
create table if not exists earner_points (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  month_str text not null,           -- 'YYYY-MM'
  rank integer not null,             -- 1st, 2nd, 3rd etc
  points integer not null,           -- 10,9,8...1,0
  amount_usd numeric not null,
  created_at timestamptz not null default now(),
  unique(user_id, month_str)
);

alter table earner_points enable row level security;

create policy "Anyone can view earner points" on earner_points
  for select using (true);

create policy "Admins manage earner points" on earner_points
  for all using (is_admin_or_director());

-- Function: auto-calculate and upsert earner points for a month
create or replace function calculate_earner_points(p_month_str text)
returns void as $$
declare
  r record;
  v_rank integer := 1;
  v_points integer;
begin
  -- Delete existing points for this month
  delete from earner_points where month_str = p_month_str;

  -- Recalculate from weekly_earnings
  for r in (
    select
      p.id as user_id,
      sum(we.amount_usd) as total_usd
    from weekly_earnings we
    join profiles p on p.id = we.user_id
    where to_char(we.week_start::date, 'YYYY-MM') = p_month_str
      and p.status in ('member','distributor','manager','executive_manager')
      and p.approved = true
    group by p.id
    order by sum(we.amount_usd) desc
  ) loop
    v_points := greatest(0, 11 - v_rank); -- 1st=10, 2nd=9...10th=1, 11th+=0
    if v_rank > 10 then v_points := 0; end if;

    insert into earner_points (user_id, month_str, rank, points, amount_usd)
    values (r.user_id, p_month_str, v_rank, v_points, r.total_usd);

    v_rank := v_rank + 1;
  end loop;
end;
$$ language plpgsql security definer;

-- =============================================
-- FIX: is_co_admin column (referenced throughout the app code
-- but was missing from the schema — caused profile queries that
-- explicitly select it, e.g. app/scanner/page.tsx, to error out).
-- Safe to run multiple times.
-- =============================================
alter table profiles add column if not exists is_co_admin boolean not null default false;

-- =============================================
-- FIX: group_leader_id column on color_groups (exists live but was
-- missing from this schema file — documenting it here for consistency).
-- =============================================
alter table color_groups add column if not exists group_leader_id uuid references profiles(id);

-- =============================================
-- FEATURE: auto-create a color group when someone is promoted to
-- Senior Manager (or above) and doesn't already lead one. They become
-- the group's 001. No two Senior Managers ever share a color group
-- (enforced already in app code for manual assignment; this covers
-- the automatic case on promotion).
-- =============================================
create or replace function auto_create_sm_color_group()
returns trigger language plpgsql as $$
declare
  v_base_code text;
  v_code text;
  v_suffix int := 0;
  v_group_id uuid;
  v_group_name text;
  v_name_suffix int := 0;
begin
  if new.status in ('senior_manager','executive_manager','director')
     and (old.status is distinct from new.status)
     and old.status not in ('senior_manager','executive_manager','director') then

    -- Skip if they already lead a color group
    if exists (select 1 from color_groups where group_leader_id = new.id) then
      return new;
    end if;

    v_base_code := upper(regexp_replace(coalesce(split_part(new.full_name, ' ', 1), 'GRP'), '[^a-zA-Z]', '', 'g'));
    v_base_code := left(nullif(v_base_code, ''), 6);
    if v_base_code is null then v_base_code := 'GRP'; end if;
    v_code := v_base_code;
    while exists (select 1 from color_groups where code = v_code) loop
      v_suffix := v_suffix + 1;
      v_code := v_base_code || v_suffix::text;
    end loop;

    v_group_name := new.full_name || '''s Group';
    while exists (select 1 from color_groups where name = v_group_name) loop
      v_name_suffix := v_name_suffix + 1;
      v_group_name := new.full_name || '''s Group ' || v_name_suffix::text;
    end loop;

    insert into color_groups (name, code, hex_color, group_leader_id)
    values (v_group_name, v_code, '#' || substr(md5(random()::text), 1, 6), new.id)
    returning id into v_group_id;

    insert into member_id_sequences (color_code, next_number) values (v_code, 2)
    on conflict (color_code) do nothing;

    new.color_group_id := v_group_id;
    if new.member_id is null then
      new.member_id := v_code || '001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_auto_create_sm_color_group on profiles;
create trigger trg_auto_create_sm_color_group
before update on profiles
for each row execute function auto_create_sm_color_group();

-- =============================================
-- FEATURE: track who granted co-admin status, so Directors and Co-Admins
-- can each promote exactly one other co-admin from their own side, while
-- the main Admin can still remove anyone's co-admin status regardless of
-- who granted it.
-- =============================================
alter table profiles add column if not exists co_admin_assigned_by uuid references profiles(id);
CLAUDE_EOF_MARKER

echo "Staging and committing..."
git add .
git commit -m "feat: global view-as, live dashboard leaderboards, earnings picker fix, co-admin visibility and assignment rules"
git push origin main
echo "Done. Vercel should start redeploying now."
echo "IMPORTANT: also re-run supabase/schema.sql in the Supabase SQL Editor for the new co_admin_assigned_by column."
