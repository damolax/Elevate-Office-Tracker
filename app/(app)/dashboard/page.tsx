import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format, startOfMonth, endOfMonth, startOfWeek, endOfWeek, subMonths, parseISO } from 'date-fns'
import { formatCurrency, getStatusLabel } from '@/lib/utils'
import DashboardClient from './DashboardClient'

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: { range?: string }
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('*, color_groups(*), sponsor:sponsor_id(id, full_name, member_id)')
    .eq('id', user.id)
    .single()

  if (!profile) redirect('/login')

  const range = searchParams.range ?? 'this_month'
  const now = new Date()

  // Date range
  let rangeStart: Date
  let rangeEnd: Date = now

  switch (range) {
    case 'this_week':
      rangeStart = startOfWeek(now, { weekStartsOn: 6 })
      rangeEnd = endOfWeek(now, { weekStartsOn: 6 })
      break
    case 'last_month':
      rangeStart = startOfMonth(subMonths(now, 1))
      rangeEnd = endOfMonth(subMonths(now, 1))
      break
    case 'last_3_months':
      rangeStart = startOfMonth(subMonths(now, 3))
      break
    case 'last_6_months':
      rangeStart = startOfMonth(subMonths(now, 6))
      break
    case 'last_year':
      rangeStart = new Date(now.getFullYear() - 1, now.getMonth(), 1)
      break
    default: // this_month
      rangeStart = startOfMonth(now)
      rangeEnd = endOfMonth(now)
  }

  const isAdmin = profile.is_admin || profile.is_director

  // Fetch data based on role
  const [
    { data: myAttendance },
    { data: myEarnings },
    { data: myScouting, count: myScoutingCount },
    { data: officeAttendanceToday },
    { data: colorGroups },
    { data: topEarners },
    { data: newMembersMonth },
    { data: groupEarnings },
    { data: settings },
    { data: lastMonthTopEarners },
  ] = await Promise.all([
    // My attendance in range
    supabase.from('attendance')
      .select('date, sign_in_time, sign_out_time')
      .eq('user_id', user.id)
      .gte('date', format(rangeStart, 'yyyy-MM-dd'))
      .lte('date', format(rangeEnd, 'yyyy-MM-dd'))
      .not('sign_in_time', 'is', null),

    // My earnings in range
    supabase.from('weekly_earnings')
      .select('amount_usd, week_start')
      .eq('user_id', user.id)
      .gte('week_start', format(rangeStart, 'yyyy-MM-dd'))
      .lte('week_start', format(rangeEnd, 'yyyy-MM-dd')),

    // My scouting
    supabase.from('scouting_records')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('scouted_at', rangeStart.toISOString()),

    // Today's office attendance (admin only)
    isAdmin
      ? supabase.from('attendance')
          .select('id, profiles!inner(full_name, status, member_id)')
          .eq('date', format(now, 'yyyy-MM-dd'))
          .not('sign_in_time', 'is', null)
      : { data: null },

    // Color groups with member counts
    supabase.from('color_groups').select('*').order('member_count', { ascending: false }),

    // Top earners (managers and below only, current month)
    supabase.from('weekly_earnings')
      .select('amount_usd, profiles!inner(id, full_name, member_id, status, color_group_id, color_groups(name, hex_color))')
      .gte('week_start', format(startOfMonth(now), 'yyyy-MM-dd'))
      .lte('week_start', format(endOfMonth(now), 'yyyy-MM-dd'))
      .in('profiles.status', ['member', 'distributor', 'manager']),

    // New members this month
    supabase.from('profiles')
      .select('id', { count: 'exact', head: true })
      .eq('is_new_member', true)
      .eq('new_member_month', format(now, 'yyyy-MM')),

    // Earnings by color group this month
    supabase.from('weekly_earnings')
      .select('amount_usd, profiles!inner(color_group_id, color_groups(name, hex_color))')
      .gte('week_start', format(startOfMonth(now), 'yyyy-MM-dd')),

    // App settings
    supabase.from('app_settings').select('key, value'),

    // Last month top earners
    supabase.from('weekly_earnings')
      .select('amount_usd, profiles!inner(id, full_name, member_id, status, color_groups(name, hex_color))')
      .gte('week_start', format(startOfMonth(subMonths(now, 1)), 'yyyy-MM-dd'))
      .lte('week_start', format(endOfMonth(subMonths(now, 1)), 'yyyy-MM-dd'))
      .in('profiles.status', ['member', 'distributor', 'manager']),
  ])

  const myTotalEarnings = (myEarnings ?? []).reduce((s, e) => s + Number(e.amount_usd), 0)
  const myAttendanceDays = (myAttendance ?? []).length
  const settingsMap = Object.fromEntries((settings ?? []).map(s => [s.key, s.value]))

  // Aggregate top earners
  const earnerMap = new Map<string, { id: string; full_name: string; member_id: string; status: string; total: number; group_name: string; group_color: string }>()
  for (const e of (topEarners ?? [])) {
    const p = (e as any).profiles
    if (!p) continue
    const existing = earnerMap.get(p.id) ?? {
      id: p.id, full_name: p.full_name, member_id: p.member_id, status: p.status,
      total: 0, group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#999',
    }
    existing.total += Number(e.amount_usd)
    earnerMap.set(p.id, existing)
  }
  const sortedEarners = Array.from(earnerMap.values()).sort((a, b) => b.total - a.total).slice(0, 20)

  // Last month top earners
  const lastMonthMap = new Map<string, { id: string; full_name: string; member_id: string; total: number; group_name: string }>()
  for (const e of (lastMonthTopEarners ?? [])) {
    const p = (e as any).profiles
    if (!p) continue
    const existing = lastMonthMap.get(p.id) ?? {
      id: p.id, full_name: p.full_name, member_id: p.member_id, total: 0, group_name: p.color_groups?.name ?? '—',
    }
    existing.total += Number(e.amount_usd)
    lastMonthMap.set(p.id, existing)
  }
  const lastMonthSorted = Array.from(lastMonthMap.values()).sort((a, b) => b.total - a.total).slice(0, 3)

  // Group earnings
  const groupMap = new Map<string, { name: string; hex_color: string; total: number }>()
  for (const e of (groupEarnings ?? [])) {
    const p = (e as any).profiles
    if (!p?.color_groups) continue
    const key = p.color_groups.name
    const existing = groupMap.get(key) ?? { name: p.color_groups.name, hex_color: p.color_groups.hex_color, total: 0 }
    existing.total += Number(e.amount_usd)
    groupMap.set(key, existing)
  }
  const sortedGroups = Array.from(groupMap.values()).sort((a, b) => b.total - a.total)

  // My ranking
  const myRank = sortedEarners.findIndex(e => e.id === user.id) + 1

  return (
    <DashboardClient
      profile={profile}
      range={range}
      myAttendanceDays={myAttendanceDays}
      myTotalEarnings={myTotalEarnings}
      myScoutingCount={myScoutingCount ?? 0}
      myRank={myRank}
      todayAttendanceCount={officeAttendanceToday?.length ?? 0}
      newMembersCount={newMembersMonth?.length ?? 0}
      topEarners={sortedEarners}
      lastMonthTopEarners={lastMonthSorted}
      groupEarnings={sortedGroups}
      colorGroups={colorGroups ?? []}
      isAdmin={isAdmin}
      settingsMap={settingsMap}
    />
  )
}
