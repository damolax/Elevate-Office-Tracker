import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format, startOfMonth, endOfMonth, startOfWeek, endOfWeek } from 'date-fns'
import EarningsClient from './EarningsClient'
import { computeTeam, statusRank, isSmOrAbove } from '@/lib/types'
import type { Profile } from '@/lib/types'

export default async function EarningsPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*, color_groups(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin

  // My earnings — all time
  const { data: myEarnings } = await supabase
    .from('earnings').select('*').eq('user_id', user.id).order('week_start', { ascending: false })

  // All profiles for team computation + logging
  const { data: allProfiles } = await supabase
    .from('profiles').select('*').eq('approved', true).order('full_name')

  // Team earnings — SM+ and admins
  let teamEarnings: any[] = []
  if (isAdmin || isSmOrAbove(profile.status)) {
    // Get team member IDs
    const teamIds = isAdmin
      ? (allProfiles ?? []).map((p: any) => p.id)
      : computeTeam(user.id, profile.status, allProfiles ?? [])

    if (teamIds.length > 0) {
      const { data } = await supabase
        .from('earnings')
        .select('*, profiles(full_name, member_id, status)')
        .in('user_id', teamIds)
        .order('week_start', { ascending: false })
        .limit(200)
      teamEarnings = data ?? []
    }
  }

  return (
    <EarningsClient
      profile={profile}
      allProfiles={allProfiles ?? []}
      myEarnings={myEarnings ?? []}
      teamEarnings={teamEarnings}
      isAdmin={isAdmin}
    />
  )
}
