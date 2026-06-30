import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import PeopleClient from './PeopleClient'

export default async function PeoplePage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*').eq('id', user.id).single()
  if (!profile || (!profile.is_admin && !profile.is_director)) redirect('/dashboard')

  // Main admin = admin with no sponsor (root node)
  const isMainAdmin = profile.is_admin && !profile.sponsor_id

  // Get main admin id to hide from directors
  const { data: mainAdmin } = await supabase
    .from('profiles').select('id').eq('is_admin', true).is('sponsor_id', null).single()
  const mainAdminId = mainAdmin?.id ?? null

  const [
    { data: allProfiles },
    { data: pendingProfiles },
    { data: colorGroups },
  ] = await Promise.all([
    supabase.from('profiles')
      .select('*, color_groups(name, hex_color, code), sponsor:sponsor_id(id, full_name, member_id)')
      .order('created_at', { ascending: false }),
    supabase.from('profiles')
      .select('*, color_groups(name, hex_color), sponsor:sponsor_id(id, full_name, member_id)')
      .eq('approved', false).eq('rejected', false)
      .order('created_at', { ascending: false }),
    supabase.from('color_groups').select('*').order('name'),
  ])

  return (
    <PeopleClient
      currentProfile={profile}
      allProfiles={allProfiles ?? []}
      pendingProfiles={pendingProfiles ?? []}
      colorGroups={colorGroups ?? []}
      isMainAdmin={isMainAdmin}
      mainAdminId={mainAdminId}
    />
  )
}
