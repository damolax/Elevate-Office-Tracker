import { NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { createClient } from '@/lib/supabase/server'
import { VIEW_AS_COOKIE } from '@/lib/view-as'

export async function POST(request: Request) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Not logged in' }, { status: 401 })

  const { data: actor } = await supabase
    .from('profiles')
    .select('is_admin, is_director, is_co_admin')
    .eq('id', user.id)
    .single()

  if (!actor || (!actor.is_admin && !actor.is_director && !actor.is_co_admin)) {
    return NextResponse.json({ error: 'Not authorized' }, { status: 403 })
  }

  const { target_id } = await request.json()
  if (!target_id) return NextResponse.json({ error: 'Missing target_id' }, { status: 400 })

  cookies().set(VIEW_AS_COOKIE, target_id, {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 4, // 4 hours, auto-expires so it can't be forgotten
  })

  return NextResponse.json({ ok: true })
}

export async function DELETE() {
  cookies().delete(VIEW_AS_COOKIE)
  return NextResponse.json({ ok: true })
}
