import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import MoneyClient from './MoneyClient'

export default async function MoneyPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director
  const isEmOrBelow = ['member','distributor','manager','executive_manager'].includes(profile.status)

  const [
    { data: myWeeklyEarnings },
    { data: allEarnings },
    { data: colorGroups },
    { data: allProfiles },
  ] = await Promise.all([
    supabase.from('weekly_earnings')
      .select('*')
      .eq('user_id', user.id)
      .order('week_start', { ascending: false }),

    isAdmin
      ? supabase.from('weekly_earnings')
          .select('*, profiles!inner(id, full_name, member_id, status, color_group_id, color_groups!profiles_color_group_id_fkey(name, hex_color, code))')
          .in('profiles.status', ['member','distributor','manager','executive_manager'])
          .order('week_start', { ascending: false })
      : { data: [] },

    supabase.from('color_groups').select('*').order('name'),

    isAdmin
      ? supabase.from('profiles')
          .select('id, full_name, member_id, status, color_groups!profiles_color_group_id_fkey(name)')
          .eq('approved', true)
          .in('status', ['member','distributor','manager','executive_manager'])
          .order('full_name')
      : { data: [] },
  ])

  return (
    <MoneyClient
      profile={profile}
      isAdmin={isAdmin}
      isEmOrBelow={isEmOrBelow}
      myWeeklyEarnings={myWeeklyEarnings ?? []}
      allEarnings={(allEarnings ?? []) as any[]}
      colorGroups={colorGroups ?? []}
      allProfiles={(allProfiles ?? []) as any[]}
    />
  )
}
