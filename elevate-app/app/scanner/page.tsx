import ScannerPage from './ScannerClient'
import { createClient } from '@/lib/supabase/server'
import { format } from 'date-fns'

export default async function Scanner() {
  const supabase = createClient()
  const today = format(new Date(), 'yyyy-MM-dd')

  // Get or create today's scanner session
  let { data: session } = await supabase
    .from('scanner_sessions')
    .select('*')
    .eq('date', today)
    .single()

  // Auto-generate session token for today if not exists
  if (!session) {
    const token = Math.random().toString(36).slice(2, 10).toUpperCase()
    const { data: newSession } = await supabase
      .from('scanner_sessions')
      .insert({ date: today, token })
      .select()
      .single()
    session = newSession
  }

  return <ScannerPage today={today} sessionToken={session?.token ?? ''} />
}
