import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

export async function POST(request: Request) {
  try {
    const { approved_by_name, new_member_name, new_member_email, new_member_status, member_id } = await request.json()

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
    const resendKey = process.env.RESEND_API_KEY
    const fromEmail = process.env.FROM_EMAIL ?? 'noreply@elevateoffice.org'
    const adminEmail = process.env.ADMIN_EMAIL ?? 'oyekunleolalekan3168@gmail.com'

    if (!supabaseUrl || !serviceKey) {
      return NextResponse.json({ error: 'Server config error' }, { status: 500 })
    }

    const html = `
<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;color:#374151">
<div style="background:#1e1b4b;border-radius:12px;padding:24px;margin-bottom:24px">
  <h1 style="color:white;font-size:20px;margin:0">New Member Approved</h1>
  <p style="color:#a5b4fc;margin:8px 0 0">Elevate Office — Admin Notification</p>
</div>
<p>Hi Olalekan,</p>
<p>A new member has been approved by one of your directors.</p>
<table style="width:100%;border-collapse:collapse;margin:20px 0">
  <tr><td style="padding:10px;border:1px solid #e5e7eb;background:#f9fafb;font-weight:600;width:140px">Approved by</td><td style="padding:10px;border:1px solid #e5e7eb">${approved_by_name}</td></tr>
  <tr><td style="padding:10px;border:1px solid #e5e7eb;background:#f9fafb;font-weight:600">New Member</td><td style="padding:10px;border:1px solid #e5e7eb">${new_member_name}</td></tr>
  <tr><td style="padding:10px;border:1px solid #e5e7eb;background:#f9fafb;font-weight:600">Email</td><td style="padding:10px;border:1px solid #e5e7eb">${new_member_email}</td></tr>
  <tr><td style="padding:10px;border:1px solid #e5e7eb;background:#f9fafb;font-weight:600">Status</td><td style="padding:10px;border:1px solid #e5e7eb">${new_member_status}</td></tr>
  <tr><td style="padding:10px;border:1px solid #e5e7eb;background:#f9fafb;font-weight:600">Member ID</td><td style="padding:10px;border:1px solid #e5e7eb">${member_id ?? 'Not assigned yet'}</td></tr>
</table>
<p style="color:#6b7280;font-size:13px">This is an automated notification from Elevate Office Tracker.</p>
</body></html>`

    if (resendKey) {
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: `Elevate Office <${fromEmail}>`,
          to: [adminEmail],
          subject: `New member approved by ${approved_by_name}: ${new_member_name}`,
          html,
        }),
      })
    } else {
      console.log(`[Admin Notification] ${approved_by_name} approved ${new_member_name} (${new_member_email})`)
    }

    return NextResponse.json({ ok: true })
  } catch (err: unknown) {
    return NextResponse.json({ error: err instanceof Error ? err.message : 'Unknown error' }, { status: 500 })
  }
}
