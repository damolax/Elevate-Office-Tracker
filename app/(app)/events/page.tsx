import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import EventsClient from './EventsClient'

export default async function EventsPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase
    .from('profiles').select('*').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const { data: events } = await supabase
    .from('events')
    .select('*, profiles(full_name)')
    .order('event_date', { ascending: true })

  return (
    <EventsClient
      profile={profile}
      events={(events ?? []) as any[]}
      isAdmin={profile.is_admin || profile.is_director}
    />
  )
}
