import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { format, subMonths, startOfMonth } from 'date-fns'

export async function POST(request: Request) {
  try {
    const { months_back = 6 } = await request.json().catch(() => ({}))

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!
    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const now = new Date()
    const results = []

    for (let i = 0; i < months_back; i++) {
      const monthDate = subMonths(now, i)
      const monthStr = format(monthDate, 'yyyy-MM')
      const { error } = await supabase.rpc('calculate_earner_points', { p_month_str: monthStr })
      if (error) results.push({ month: monthStr, error: error.message })
      else results.push({ month: monthStr, ok: true })
    }

    return NextResponse.json({ ok: true, results })
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Unknown error' }, { status: 500 })
  }
}
