import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format, startOfWeek, endOfWeek, eachDayOfInterval, isWeekend } from 'date-fns'
import WeeksClient from './WeeksClient'

export default async function WeeksPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*)')
    .eq('id', user.id)
    .single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director
  const isTrackable = ['member', 'distributor', 'manager'].includes(profile.status)

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
    .eq('user_id', user.id)
    .gte('date', weekStartStr)
    .lte('date', weekEndStr)
    .not('sign_in_time', 'is', null)

  // My full attendance history
  const { data: myAllAttendance } = await supabase
    .from('attendance')
    .select('*')
    .eq('user_id', user.id)
    .not('sign_in_time', 'is', null)
    .order('date', { ascending: false })

  // My assessments
  const { data: myAssessments } = await supabase
    .from('week_assessments')
    .select('*')
    .eq('user_id', user.id)
    .order('week_number')

  // My advancement log
  const { data: myAdvancementLog } = await supabase
    .from('week_advancement_log')
    .select('*')
    .eq('user_id', user.id)
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
    />
  )
}
