import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format, startOfMonth, endOfMonth, startOfYear, endOfYear } from 'date-fns'
import MoneyClient from './MoneyClient'

export default async function MoneyPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('*, color_groups(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director
  const now = new Date()

  const [
    { data: myEarnings },
    { data: allEarnings },
    { data: colorGroups },
    { data: profiles },
  ] = await Promise.all([
    // My earnings all time
    supabase.from('weekly_earnings')
      .select('*')
      .eq('user_id', user.id)
      .order('week_start', { ascending: false }),

    // All earnings (admin) — managers and below only
    isAdmin
      ? supabase.from('weekly_earnings')
          .select('*, profiles!inner(id, full_name, member_id, status, color_group_id, color_groups(name, hex_color, code))')
          .in('profiles.status', ['member', 'distributor', 'manager'])
          .order('week_start', { ascending: false })
      : { data: null },

    supabase.from('color_groups').select('*').order('name'),

    isAdmin
      ? supabase.from('profiles').select('id, full_name, member_id, status, color_groups(name)')
          .eq('approved', true)
          .in('status', ['member', 'distributor', 'manager'])
      : { data: null },
  ])

  return (
    <MoneyClient
      profile={profile}
      isAdmin={isAdmin}
      myEarnings={myEarnings ?? []}
      allEarnings={(allEarnings ?? []) as any[]}
      colorGroups={colorGroups ?? []}
      allProfiles={(profiles ?? []) as any[]}
    />
  )
}
