import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { format } from 'date-fns'

function buildAbsenceEmail(name: string, missCount: number, weekNumber: number, type: 'daily' | 'weekly'): string {
  if (type === 'daily') {
    return `
<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;color:#374151">
<div style="background:#1e1b4b;border-radius:12px;padding:24px;margin-bottom:24px;text-align:center">
  <h1 style="color:white;font-size:24px;margin:0">Elevate Office</h1>
  <p style="color:#a5b4fc;margin:8px 0 0">Week ${weekNumber} · Day Absence Notice</p>
</div>
<p style="font-size:16px">Hi <strong>${name}</strong>,</p>
<p style="line-height:1.7;color:#4b5563">
  We at Elevate Office noticed you were not with us today, and we genuinely wanted to check in on you. 
  We hope everything is alright on your end, and that whatever kept you away today is nothing serious.
</p>
<p style="line-height:1.7;color:#4b5563">
  We want you to know that your presence in the office genuinely matters — not just for the learning, 
  but for the energy and momentum you bring to the team. Every session is building on the last, and 
  we want to make sure you don't miss out on anything that could shape your success in this program.
</p>
<p style="line-height:1.7;color:#4b5563">
  Please remember: <strong>missing more than one day this week may require you to repeat Week ${weekNumber}</strong>. 
  We know that's not what you want, and it's not what we want for you either. So if there's any way 
  you can make it in for the remaining days, please do — we'll be here, ready to pick up right where we left off.
</p>
<p style="line-height:1.7;color:#4b5563">
  If there's something going on that we should know about, please don't hesitate to reach out. 
  We are here to support you, not just to train you.
</p>
<p style="margin-top:24px;color:#374151">Best regards,</p>
<p style="font-weight:bold;color:#1e1b4b;margin:4px 0">Olalekan</p>
<p style="color:#6b7280;font-size:13px;margin:2px 0">Elevate Office Team Leader</p>
<hr style="border:none;border-top:1px solid #e5e7eb;margin:24px 0">
<p style="font-size:12px;color:#9ca3af;text-align:center">
  Elevate Office · Building the next generation of entrepreneurs
</p>
</body></html>`
  }

  return `
<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;color:#374151">
<div style="background:#1e1b4b;border-radius:12px;padding:24px;margin-bottom:24px;text-align:center">
  <h1 style="color:white;font-size:24px;margin:0">Elevate Office</h1>
  <p style="color:#a5b4fc;margin:8px 0 0">Week ${weekNumber} · Weekly Attendance Summary</p>
</div>
<p style="font-size:16px">Hi <strong>${name}</strong>,</p>
<p style="line-height:1.7;color:#4b5563">
  We're reaching out as we close out this week to share something important with you. 
  Our records show that you missed <strong>${missCount} day${missCount > 1 ? 's' : ''}</strong> this week — and we want to be straightforward with you about what that means.
</p>
<div style="background:#fef3c7;border:1px solid #f59e0b;border-radius:8px;padding:16px;margin:20px 0">
  <p style="color:#92400e;margin:0;font-weight:600">⚠ Week ${weekNumber} Attendance Status</p>
  <p style="color:#92400e;margin:8px 0 0">You attended ${5 - missCount} out of 5 days this week. The minimum required is 4 days. Based on your attendance this week, you may be required to <strong>repeat Week ${weekNumber}</strong>.</p>
</div>
<p style="line-height:1.7;color:#4b5563">
  We want you to know that this decision will be reviewed by the admin, and there may be circumstances 
  that are taken into account. But we also want to be honest: consistency is the foundation of this program, 
  and the people who show up every day are the ones who see the biggest results.
</p>
<p style="line-height:1.7;color:#4b5563">
  If there are genuine circumstances that kept you away, please speak to your SM or reach out to the admin 
  directly. Transparency goes a long way, and we want to work with you — not against you.
</p>
<p style="line-height:1.7;color:#4b5563">
  Regardless of what happens with this week, we want to see you back in the office, fully committed, 
  and ready to push through. You are in this program for a reason. Don't let it slip away.
</p>
<p style="margin-top:24px;color:#374151">With respect and belief in your potential,</p>
<p style="font-weight:bold;color:#1e1b4b;margin:4px 0">Olalekan</p>
<p style="color:#6b7280;font-size:13px;margin:2px 0">Elevate Office Team Leader</p>
<hr style="border:none;border-top:1px solid #e5e7eb;margin:24px 0">
<p style="font-size:12px;color:#9ca3af;text-align:center">
  Elevate Office · Building the next generation of entrepreneurs
</p>
</body></html>`
}

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const { user_id, type, admin_id } = body

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
    const resendKey = process.env.RESEND_API_KEY
    const fromEmail = process.env.FROM_EMAIL ?? 'noreply@elevateoffice.com'

    if (!supabaseUrl || !serviceKey) {
      return NextResponse.json({ error: 'Server configuration error' }, { status: 500 })
    }

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const { data: profile } = await supabase
      .from('profiles')
      .select('id, full_name, email, week_number')
      .eq('id', user_id)
      .single()

    if (!profile) return NextResponse.json({ error: 'Member not found' }, { status: 404 })

    const today = format(new Date(), 'yyyy-MM-dd')
    const emailType = type === 'weekly' ? 'weekly_summary' : 'daily_miss'

    // Check already sent today for daily
    if (emailType === 'daily_miss') {
      const { data: existing } = await supabase
        .from('absence_emails')
        .select('id')
        .eq('user_id', user_id)
        .eq('email_type', 'daily_miss')
        .eq('date_missed', today)
        .maybeSingle()
      if (existing) return NextResponse.json({ ok: true, skipped: true, reason: 'already sent today' })
    }

    // Get this week's miss count
    const weekStart = new Date()
    weekStart.setDate(weekStart.getDate() - weekStart.getDay() + 1)
    const { data: weekAtt } = await supabase
      .from('attendance')
      .select('date')
      .eq('user_id', user_id)
      .gte('date', format(weekStart, 'yyyy-MM-dd'))
      .not('sign_in_time', 'is', null)

    const attendedDays = (weekAtt ?? []).length
    const missCount = Math.max(0, 5 - attendedDays)

    const subject = emailType === 'daily_miss'
      ? `We missed you today, ${profile.full_name.split(' ')[0]} — Week ${profile.week_number}`
      : `Week ${profile.week_number} Attendance Summary — ${missCount} day${missCount !== 1 ? 's' : ''} missed`

    const html = buildAbsenceEmail(
      profile.full_name.split(' ')[0],
      missCount,
      profile.week_number,
      emailType === 'daily_miss' ? 'daily' : 'weekly'
    )

    // Send via Resend if API key available, otherwise log
    if (resendKey) {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${resendKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: `Elevate Office <${fromEmail}>`,
          to: [profile.email],
          subject,
          html,
        }),
      })
      if (!res.ok) {
        const err = await res.json()
        return NextResponse.json({ error: err.message ?? 'Email send failed' }, { status: 400 })
      }
    } else {
      // No Resend key yet — log it but don't fail
      console.log(`[Absence Email] Would send to ${profile.email}: ${subject}`)
    }

    // Log the email
    await supabase.from('absence_emails').upsert({
      user_id, email_type: emailType,
      date_missed: emailType === 'daily_miss' ? today : null,
      week_number: profile.week_number,
      miss_count: missCount,
    }, { onConflict: 'user_id,email_type,date_missed' })

    return NextResponse.json({ ok: true, sent_to: profile.email })
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Unknown error' }, { status: 500 })
  }
}
