import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { format } from 'date-fns'

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

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

    if (!supabaseUrl || !serviceKey) {
      return NextResponse.json({ error: 'Server configuration error — missing env vars' }, { status: 500 })
    }

    // Create admin client directly — avoids cookie dependency in API routes
    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const { error } = await supabase.from('profiles').insert({
      id,
      full_name: String(full_name).trim(),
      email: String(email).toLowerCase().trim(),
      phone: phone || null,
      status: status || 'member',
      color_group_id: color_group_id || null,
      sponsor_id: sponsor_id || null,
      is_office_already: is_office_already ?? true,
      is_new_member: is_new_member ?? false,
      new_member_month: new_member_month || null,
      approved: false,
      week_number: week_number ?? 1,
    })

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 400 })
    }

    return NextResponse.json({ success: true })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown server error'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
