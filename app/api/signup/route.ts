import { createAdminClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const {
      id, full_name, email, phone, status,
      color_group_id, sponsor_id, is_office_already,
      is_new_member, new_member_month, week_number,
    } = body

    if (!id || !full_name || !email) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    const supabase = createAdminClient()

    const { error } = await supabase.from('profiles').insert({
      id,
      full_name: full_name.trim(),
      email: email.toLowerCase().trim(),
      phone: phone || null,
      status,
      color_group_id: color_group_id || null,
      sponsor_id: sponsor_id || null,
      is_office_already,
      is_new_member,
      new_member_month: new_member_month || null,
      approved: false,
      week_number: week_number ?? 1,
    })

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 400 })
    }

    return NextResponse.json({ success: true })
  } catch (err: unknown) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : 'Unknown error' },
      { status: 500 }
    )
  }
}
