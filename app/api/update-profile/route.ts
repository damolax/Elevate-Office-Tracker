import { NextResponse } from 'next/server'
import { createAdminClient, createClient } from '@/lib/supabase/server'

const SELF_EDITABLE_FIELDS = new Set(['full_name', 'phone', 'about'])
const ADMIN_EDITABLE_FIELDS = new Set(['full_name', 'status', 'week_number', 'sponsor_id'])

function pickAllowedFields(updates: Record<string, unknown>, allowed: Set<string>) {
  return Object.fromEntries(
    Object.entries(updates).filter(([key]) => allowed.has(key))
  )
}

export async function POST(request: Request) {
  try {
    const { user_id, updates } = await request.json()

    if (!user_id || !updates || typeof updates !== 'object' || Array.isArray(updates)) {
      return NextResponse.json({ error: 'Missing or invalid user_id/updates' }, { status: 400 })
    }

    // Authenticate from the signed session cookie. Never trust actor_id supplied
    // by the browser, because request bodies are user-controlled.
    const sessionClient = createClient()
    const { data: { user: requester } } = await sessionClient.auth.getUser()
    if (!requester) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const admin = createAdminClient()

    // Self-service profile edits are intentionally narrow.
    if (requester.id === user_id) {
      const safeUpdates = pickAllowedFields(updates, SELF_EDITABLE_FIELDS)
      if (Object.keys(safeUpdates).length === 0) {
        return NextResponse.json({ error: 'No permitted fields to update' }, { status: 400 })
      }

      const { data, error } = await admin
        .from('profiles')
        .update(safeUpdates)
        .eq('id', requester.id)
        .select()
        .single()

      if (error) return NextResponse.json({ error: error.message }, { status: 400 })
      return NextResponse.json({ ok: true, profile: data })
    }

    // Editing another member requires an authenticated admin-tier profile.
    const [{ data: actor }, { data: target }] = await Promise.all([
      admin
        .from('profiles')
        .select('is_admin, is_director, is_co_admin')
        .eq('id', requester.id)
        .single(),
      admin
        .from('profiles')
        .select('is_admin, is_director')
        .eq('id', user_id)
        .single(),
    ])

    if (!actor || (!actor.is_admin && !actor.is_director && !actor.is_co_admin)) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }
    if (!target) {
      return NextResponse.json({ error: 'Profile not found' }, { status: 404 })
    }

    if (!actor.is_admin) {
      if (target.is_admin) {
        return NextResponse.json({ error: 'You cannot edit the main Admin.' }, { status: 403 })
      }
      if (actor.is_co_admin && !actor.is_director && target.is_director) {
        return NextResponse.json({ error: 'Co-Admins cannot edit Directors.' }, { status: 403 })
      }
    }

    const safeUpdates = pickAllowedFields(updates, ADMIN_EDITABLE_FIELDS)
    if (Object.keys(safeUpdates).length === 0) {
      return NextResponse.json({ error: 'No permitted fields to update' }, { status: 400 })
    }

    const { data, error } = await admin
      .from('profiles')
      .update(safeUpdates)
      .eq('id', user_id)
      .select()
      .single()

    if (error) return NextResponse.json({ error: error.message }, { status: 400 })
    return NextResponse.json({ ok: true, profile: data })
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Unknown error' }, { status: 500 })
  }
}
