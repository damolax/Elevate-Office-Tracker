import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import MyGroupClient from './MyGroupClient'

export default async function MyGroupPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  // Only group leaders can access this page
  const isGroupLeader = profile.member_id?.endsWith('-001') ?? false
  const isAdmin = profile.is_admin || profile.is_director
  if (!isGroupLeader && !isAdmin) redirect('/dashboard')

  // Get all members in the same color group
  const { data: groupMembers } = await supabase
    .from('profiles')
    .select('*, color_groups(name, hex_color), sponsor:sponsor_id(id, full_name, member_id)')
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
    .select('id, full_name, member_id, status, sponsor_id, profile_picture, color_groups(name, hex_color)')
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
