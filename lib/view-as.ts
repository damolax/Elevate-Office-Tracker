import { cookies } from 'next/headers'
import type { SupabaseClient } from '@supabase/supabase-js'

export const VIEW_AS_COOKIE = 'view_as_id'

/**
 * Admin-only "View As" — lets an admin see the app exactly as a given member
 * would see it (dashboard, 12-week program, etc.) without logging in as them.
 * Only takes effect if the REAL logged-in user is an admin/director/co-admin;
 * everyone else's view is always their own regardless of any stray cookie.
 */
export async function getEffectiveProfile(supabase: SupabaseClient, realProfile: any) {
  const isAdminTier = realProfile?.is_admin || realProfile?.is_director || realProfile?.is_co_admin
  if (!isAdminTier) {
    return { profile: realProfile, isViewingAs: false, viewAsName: null as string | null }
  }

  const cookieStore = cookies()
  const viewAsId = cookieStore.get(VIEW_AS_COOKIE)?.value
  if (!viewAsId || viewAsId === realProfile.id) {
    return { profile: realProfile, isViewingAs: false, viewAsName: null as string | null }
  }

  const { data: viewProfile } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*)')
    .eq('id', viewAsId)
    .single()

  if (!viewProfile) {
    return { profile: realProfile, isViewingAs: false, viewAsName: null as string | null }
  }

  return { profile: viewProfile, isViewingAs: true, viewAsName: viewProfile.full_name as string }
}
