import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format, startOfMonth, endOfMonth } from 'date-fns'
import AttendanceClient from './AttendanceClient'

export default async function AttendancePage({
  searchParams,
}: {
  searchParams: { date?: string }
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('*, color_groups(*)')
    .eq('id', user.id)
    .single()
  if (!profile) redirect('/login')

  // Admin = main admin, director, or co-admin
  // Only these can see sign-in features and office view
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin
  const selectedDate = searchParams.date ?? format(new Date(), 'yyyy-MM-dd')

  // My attendance for current month (everyone sees this)
  const { data: myMonthAttendance } = await supabase
    .from('attendance')
    .select('*')
    .eq('user_id', user.id)
    .gte('date', format(startOfMonth(new Date()), 'yyyy-MM-dd'))
    .lte('date', format(endOfMonth(new Date()), 'yyyy-MM-dd'))
    .order('date', { ascending: false })

  // Today's record (everyone sees their own)
  const today = format(new Date(), 'yyyy-MM-dd')
  const { data: todayRecord } = await supabase
    .from('attendance')
    .select('*')
    .eq('user_id', user.id)
    .eq('date', today)
    .maybeSingle()

  // Office view — admin/director/co-admin only
  let dateAttendance: unknown[] = []
  if (isAdmin) {
    const { data } = await supabase
      .from('attendance')
      .select('*, profiles!inner(id, full_name, member_id, status, color_group_id, color_groups(name, hex_color))')
      .eq('date', selectedDate)
      .not('sign_in_time', 'is', null)
      .order('sign_in_time')
    dateAttendance = data ?? []
  }

  return (
    <AttendanceClient
      profile={profile}
      isAdmin={isAdmin}
      myMonthAttendance={myMonthAttendance ?? []}
      todayRecord={todayRecord}
      selectedDate={selectedDate}
      dateAttendance={dateAttendance as any[]}
    />
  )
}
