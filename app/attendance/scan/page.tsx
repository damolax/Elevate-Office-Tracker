import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import QRScanner from '@/components/attendance/QRScanner'

export default async function ScanPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, is_admin, is_director')
    .eq('id', user.id)
    .single()

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-6">
          <div className="w-12 h-12 bg-brand-600 rounded-xl flex items-center justify-center mx-auto mb-3">
            <span className="text-white font-black text-lg">E</span>
          </div>
          <h1 className="text-xl font-bold text-gray-900">Elevate Attendance</h1>
        </div>
        <QRScanner
          isAdmin={profile?.is_admin || profile?.is_director || false}
          adminProfileId={user.id}
        />
      </div>
    </div>
  )
}
