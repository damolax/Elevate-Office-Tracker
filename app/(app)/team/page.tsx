import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import TeamClient from './TeamClient'

export default async function TeamPage({ searchParams }: { searchParams: { member?: string } }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('*, color_groups(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director

  // Get all profiles to build tree
  const { data: allProfiles } = await supabase
    .from('profiles')
    .select('*, color_groups(name, hex_color, code), sponsor:sponsor_id(id, full_name, member_id)')
    .eq('approved', true)
    .order('full_name')

  // Find my direct downlines (people who have me as sponsor)
  const directDownlines = (allProfiles ?? []).filter(p => p.sponsor_id === user.id)

  // Find everyone in my team recursively
  function getAllTeam(profileId: string, profiles: typeof allProfiles): typeof allProfiles {
    const direct = (profiles ?? []).filter(p => p.sponsor_id === profileId)
    return direct.flatMap(p => [p, ...getAllTeam(p.id, profiles)])
  }

  const myTeam = isAdmin ? (allProfiles ?? []) : getAllTeam(user.id, allProfiles)

  // For admin: if viewing a specific member's tree
  let viewingMember = null
  if (isAdmin && searchParams.member) {
    viewingMember = (allProfiles ?? []).find(p => p.id === searchParams.member)
  }

  // My SM team (non-SM members under me)
  const mySmTeam = myTeam.filter(p =>
    ['member','distributor','manager'].includes(p.status) && p.id !== user.id
  )

  return (
    <TeamClient
      profile={profile}
      isAdmin={isAdmin}
      myTeam={myTeam as any[]}
      mySmTeam={mySmTeam as any[]}
      directDownlines={directDownlines as any[]}
      allProfiles={(allProfiles ?? []) as any[]}
      viewingMember={viewingMember as any}
    />
  )
}
