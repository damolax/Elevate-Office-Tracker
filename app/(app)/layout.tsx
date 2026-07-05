import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import Sidebar from '@/components/layout/Sidebar'
import Header from '@/components/layout/Header'

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('*, color_groups(*)')
    .eq('id', user.id)
    .single()

  // PGRST116 = no row found. Any other error is a real query/DB problem,
  // not "not yet approved" — don't mask it as pending-approval.
  if (profileError && profileError.code !== 'PGRST116') {
    console.error('AppLayout profile query failed:', profileError)
    throw new Error(`Failed to load profile: ${profileError.message}`)
  }

  if (!profile) redirect('/pending-approval')
  if (!profile.approved && !profile.is_admin && !profile.is_director && !profile.is_co_admin) redirect('/pending-approval')

  return (
    <div className="flex h-screen overflow-hidden bg-gray-50">
      <Sidebar profile={profile} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <Header profile={profile} />
        <main className="flex-1 overflow-y-auto p-4 sm:p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
