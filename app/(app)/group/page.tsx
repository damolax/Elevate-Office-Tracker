import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { isSmOrAbove } from '@/lib/utils'
import GroupClient from './GroupClient'

export default async function GroupPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')
  if (!isSmOrAbove(profile.status) && !profile.is_admin && !profile.is_director) redirect('/dashboard')

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
