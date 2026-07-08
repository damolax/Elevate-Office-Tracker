import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

export async function POST(request: Request) {
  try {
    const { user_id, updates, actor_id } = await request.json()

    if (!user_id || !updates) {
      return NextResponse.json({ error: 'Missing user_id or updates' }, { status: 400 })
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    // Enforce the hierarchy server-side: no one may edit someone above them.
    // (Co-admins can't touch Directors or the main Admin; Directors can't touch the main Admin.)
    if (actor_id) {
      const { data: actor } = await supabase
        .from('profiles')
        .select('is_admin, is_director, is_co_admin')
        .eq('id', actor_id)
        .single()
      const { data: target } = await supabase
        .from('profiles')
        .select('is_admin, is_director')
        .eq('id', user_id)
        .single()

      if (actor && target && !actor.is_admin) {
        const actorIsDirector = actor.is_director
        const actorIsCoAdminOnly = actor.is_co_admin && !actor.is_director
        if (target.is_admin) {
          return NextResponse.json({ error: 'You cannot edit the main Admin.' }, { status: 403 })
        }
        if (actorIsCoAdminOnly && target.is_director) {
          return NextResponse.json({ error: 'Co-Admins cannot edit Directors.' }, { status: 403 })
        }
      }
    }

    const { data, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', user_id)
      .select()
      .single()

    if (error) return NextResponse.json({ error: error.message }, { status: 400 })

    return NextResponse.json({ ok: true, profile: data })
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Unknown error' }, { status: 500 })
  }
}
