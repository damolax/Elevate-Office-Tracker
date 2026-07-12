import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import CommunityClient from './CommunityClient'

export default async function CommunityPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const { data: posts } = await supabase
    .from('community_posts')
    .select('*, profiles(id, full_name, member_id, profile_picture, status, color_groups!profiles_color_group_id_fkey(name, hex_color))')
    .order('created_at', { ascending: false })
    .limit(100)

  return (
    <CommunityClient
      profile={profile}
      initialPosts={(posts ?? []) as any[]}
      isAdmin={profile.is_admin || profile.is_director || profile.is_co_admin}
    />
  )
}
