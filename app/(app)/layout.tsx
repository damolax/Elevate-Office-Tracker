import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import Sidebar from '@/components/layout/Sidebar'
import Header from '@/components/layout/Header'
import ViewAsBanner from '@/components/admin/ViewAsBanner'
import { getEffectiveProfile } from '@/lib/view-as'

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  const { data: realProfile, error: profileError } = await supabase
    .from('profiles')
    .select('*, color_groups!profiles_color_group_id_fkey(*)')
    .eq('id', user.id)
    .single()

  // PGRST116 = no row found. Any other error is a real query/DB problem,
  // not "not yet approved" — don't mask it as pending-approval.
  if (profileError && profileError.code !== 'PGRST116') {
    console.error('AppLayout profile query failed:', profileError)
    throw new Error(`Failed to load profile: ${profileError.message}`)
  }

  if (!realProfile) redirect('/pending-approval')
  if (!realProfile.approved && !realProfile.is_admin && !realProfile.is_director && !realProfile.is_co_admin) redirect('/pending-approval')

  // Admin "View As": every page's nav, header, and content reflect whoever
  // the admin is currently viewing as — a true WYSIWYG preview of what that
  // person sees. The banner (with its Exit button) is always visible so
  // there's never any doubt this is a preview, not the admin's own account.
  const { profile, isViewingAs, viewAsName } = await getEffectiveProfile(supabase, realProfile)

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50">
      <Sidebar profile={profile} />
      <div className="flex-1 flex flex-col overflow-hidden">
        {isViewingAs && viewAsName && <ViewAsBanner name={viewAsName} />}
        <Header profile={profile} />
        <main className="flex-1 overflow-y-auto p-4 sm:p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
