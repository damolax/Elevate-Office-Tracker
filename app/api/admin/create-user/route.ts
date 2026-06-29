import { createAdminClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function POST(request: Request) {
  const supabase = createAdminClient()

  // Verify requester is admin
  const { data: { user } } = await supabase.auth.getUser()
  // Note: admin client doesn't verify JWT from cookies — use anon client for auth check
  const { createClient } = await import('@/lib/supabase/server')
  const anonClient = createClient()
  const { data: { user: requester } } = await anonClient.auth.getUser()
  if (!requester) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { data: reqProfile } = await anonClient.from('profiles').select('is_admin, is_director').eq('id', requester.id).single()
  if (!reqProfile?.is_admin && !reqProfile?.is_director) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const body = await request.json()
  const { full_name, email, phone, status, color_group_id, sponsor_id, upline_sm_id, week_number, is_new_member, temp_password } = body

  // Determine color group
  let resolvedGroupId = color_group_id || null
  if (!resolvedGroupId) {
    // Auto-assign to smallest group
    const { data: groups } = await supabase.from('color_groups').select('id, member_count').order('member_count')
    if (groups && groups.length > 0) {
      const min = groups[0].member_count
      const smallest = groups.filter(g => g.member_count === min)
      resolvedGroupId = smallest[Math.floor(Math.random() * smallest.length)].id
    }
  }

  // Get color group code for member ID
  const { data: colorGroup } = await supabase.from('color_groups').select('code, member_count').eq('id', resolvedGroupId).single()

  // Generate member ID
  const { data: memberId } = await supabase.rpc('generate_member_id', { p_color_code: colorGroup?.code ?? 'GEN' })

  // Create auth user
  const { data: authData, error: authError } = await supabase.auth.admin.createUser({
    email,
    password: temp_password,
    email_confirm: true,
  })

  if (authError || !authData.user) {
    return NextResponse.json({ error: authError?.message ?? 'Failed to create user' }, { status: 400 })
  }

  // Update color group count
  if (colorGroup) {
    await supabase.from('color_groups').update({ member_count: colorGroup.member_count + 1 }).eq('id', resolvedGroupId)
  }

  // Create profile
  const { error: profileError } = await supabase.from('profiles').insert({
    id: authData.user.id,
    full_name,
    email,
    phone: phone || null,
    status,
    color_group_id: resolvedGroupId,
    sponsor_id: sponsor_id || null,
    upline_sm_id: upline_sm_id || null,
    week_number: week_number ?? 1,
    is_new_member: is_new_member ?? false,
    member_id: memberId,
    approved: true,
  })

  if (profileError) {
    return NextResponse.json({ error: profileError.message }, { status: 400 })
  }

  return NextResponse.json({ success: true, member_id: memberId, temp_password })
}
