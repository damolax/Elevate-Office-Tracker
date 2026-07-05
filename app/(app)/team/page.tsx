import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import TeamClient from './TeamClient'
import { computeTeam, STATUS_ORDER, UserStatus } from '@/lib/types'
import type { Profile } from '@/lib/types'

export default async function TeamPage({ searchParams }: { searchParams: { filter?: string; member?: string } }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin

  const { data: allProfiles } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(name, hex_color, code), sponsor:sponsor_id(id, full_name, member_id)')
    .eq('approved', true)
    .order('full_name')

  const profiles = allProfiles ?? []

  // Compute all team filter options for this person
  const teamFilters: Record<string, string[]> = {}
  teamFilters['all'] = computeTeam(user.id, 'member' as UserStatus, profiles as Profile[])

  // Build available filter levels based on what statuses exist in my downline
  const myFullDownline = teamFilters['all']
  const statusesInDownline = new Set(
    profiles.filter(p => myFullDownline.includes(p.id)).map(p => p.status)
  )

  STATUS_ORDER.forEach(status => {
    if (statusesInDownline.has(status)) {
      teamFilters[status] = computeTeam(user.id, status as UserStatus, profiles as Profile[])
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
