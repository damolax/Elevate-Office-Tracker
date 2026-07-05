import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import SettingsClient from './SettingsClient'

export default async function SettingsPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('*, color_groups!profiles_color_group_id_fkey(*)').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const { data: settings } = await supabase.from('app_settings').select('*')
  const settingsMap = Object.fromEntries((settings ?? []).map(s => [s.key, s.value]))

  const { data: myTasks } = await supabase
    .from('tasks')
    .select('*, assigner:assigned_by(id, full_name)')
    .eq('assigned_to', user.id)
    .eq('completed', false)
    .order('created_at', { ascending: false })

  return (
    <SettingsClient
      profile={profile}
      settings={settingsMap}
      isAdmin={profile.is_admin || profile.is_director}
      myTasks={(myTasks ?? []) as any[]}
    />
  )
}
