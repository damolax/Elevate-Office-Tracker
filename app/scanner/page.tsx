import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { format } from 'date-fns'
import ScannerPage from './ScannerClient'

export default async function Scanner() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // If logged in, check if admin/director/co-admin
  // If not admin — redirect to dashboard
  // If not logged in — scanner is publicly accessible (shared tablet)
  if (user) {
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_admin, is_director, is_co_admin')
      .eq('id', user.id)
      .single()

    if (profile && !profile.is_admin && !profile.is_director && !profile.is_co_admin) {
      redirect('/dashboard')
    }
  }

  const today = format(new Date(), 'yyyy-MM-dd')

  // Ensure today's scanner session exists
  const { data: existing } = await supabase
    .from('scanner_sessions')
    .select('token')
    .eq('date', today)
    .single()

  if (!existing) {
    await supabase.from('scanner_sessions').insert({
      date: today,
      token: Math.random().toString(36).slice(2, 10).toUpperCase(),
    })
  }

  return <ScannerPage today={today} />
}
