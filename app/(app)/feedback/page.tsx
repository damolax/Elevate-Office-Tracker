import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import FeedbackClient from './FeedbackClient'

export default async function FeedbackPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).single()
  if (!profile) redirect('/login')

  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin

  // My own feedback
  const { data: myFeedback } = await supabase
    .from('feedback')
    .select('*, responder:responded_by(full_name)')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })

  // Admin: all feedback with user info
  const { data: allFeedback } = isAdmin
    ? await supabase
        .from('feedback')
        .select('*, user:user_id(full_name, member_id, email), responder:responded_by(full_name)')
        .order('created_at', { ascending: false })
    : { data: null }

  return (
    <FeedbackClient
      profile={profile}
      isAdmin={isAdmin}
      myFeedback={(myFeedback ?? []) as any[]}
      allFeedback={(allFeedback ?? []) as any[]}
    />
  )
}
