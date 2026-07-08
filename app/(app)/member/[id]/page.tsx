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
