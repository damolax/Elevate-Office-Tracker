import { NextResponse } from 'next/server'
import { createAdminClient, createClient } from '@/lib/supabase/server'

export async function POST(request: Request) {
  try {
    const { profile_id } = await request.json()
    if (!profile_id) {
      return NextResponse.json({ error: 'profile_id is required' }, { status: 400 })
    }

    const sessionClient = createClient()
    const { data: { user: requester } } = await sessionClient.auth.getUser()
    if (!requester) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const admin = createAdminClient()
    const [{ data: actor }, { data: profile }] = await Promise.all([
      admin
        .from('profiles')
        .select('is_admin, is_director')
        .eq('id', requester.id)
        .single(),
      admin
        .from('profiles')
        .select('id, email, is_admin')
        .eq('id', profile_id)
        .single(),
    ])

    // Account deletion is destructive and uses service-role privileges. Keep it
    // limited to the main Admin/Director tier rather than trusting client UI.
    if (!actor || (!actor.is_admin && !actor.is_director)) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }
    if (!profile) {
      return NextResponse.json({ error: 'Profile not found' }, { status: 404 })
    }
    if (requester.id === profile_id) {
      return NextResponse.json({ error: 'You cannot delete your own account here.' }, { status: 403 })
    }
    if (profile.is_admin && !actor.is_admin) {
      return NextResponse.json({ error: 'Directors cannot delete the main Admin.' }, { status: 403 })
    }

    // Delete the Auth user first. If this fails, keep the profile intact so the
    // app does not end up with a partially deleted account.
    const { error: authDeleteError } = await admin.auth.admin.deleteUser(profile_id)
    if (authDeleteError) {
      return NextResponse.json({ error: authDeleteError.message }, { status: 400 })
    }

    const { error: profileDeleteError } = await admin
      .from('profiles')
      .delete()
      .eq('id', profile_id)

    if (profileDeleteError) {
      return NextResponse.json({ error: profileDeleteError.message }, { status: 400 })
    }

    return NextResponse.json({ ok: true })
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Unknown error' }, { status: 500 })
  }
}
