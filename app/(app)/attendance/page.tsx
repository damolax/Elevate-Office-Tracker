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
