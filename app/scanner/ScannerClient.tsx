'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { format } from 'date-fns'
import { CheckCircle, Clock, LogIn, LogOut, AlertCircle } from 'lucide-react'

type SessionType = 'day' | 'friday' | 'night' | null

function getSessionType(): SessionType {
  const now = new Date()
  const day = now.getDay() // 0=Sun, 1=Mon, ..., 5=Fri, 6=Sat
  const h = now.getHours()
  const m = now.getMinutes()
  const timeNum = h * 60 + m // minutes since midnight

  const t = (hh: number, mm: number) => hh * 60 + mm

  // Night session: 10pm (22:00) to 6am next day
  if (timeNum >= t(22, 0) || timeNum < t(6, 0)) return 'night'
  // Friday day session: 2pm - 8pm
  if (day === 5 && timeNum >= t(14, 0) && timeNum < t(20, 0)) return 'friday'
  // Weekday session: Mon-Thu 11am - 8pm
  if (day >= 1 && day <= 4 && timeNum >= t(11, 0) && timeNum < t(20, 0)) return 'day'
  return null
}

function isSignInAllowed(session: SessionType): { ok: boolean; reason?: string } {
  if (!session) return { ok: false, reason: 'Office is currently closed. No active session.' }
  const now = new Date()
  const h = now.getHours()
  const m = now.getMinutes()
  const timeNum = h * 60 + m
  const t = (hh: number, mm: number) => hh * 60 + mm
  const day = now.getDay()

  if (session === 'night') {
    // Night sign-in: 10pm to 6am
    if (timeNum >= t(22, 0) || timeNum < t(6, 0)) return { ok: true }
    return { ok: false, reason: 'Night session sign-in is between 10:00 PM and 6:00 AM.' }
  }
  if (session === 'friday') {
    if (timeNum >= t(14, 0) && timeNum < t(19, 0)) return { ok: true }
    return { ok: false, reason: 'Friday sign-in is between 2:00 PM and 7:00 PM.' }
  }
  if (session === 'day') {
    if (timeNum >= t(11, 0) && timeNum < t(17, 0)) return { ok: true }
    return { ok: false, reason: 'Weekday sign-in is between 11:00 AM and 5:00 PM (Mon–Thu).' }
  }
  return { ok: false, reason: 'Outside office hours.' }
}

function isSignOutAllowed(session: SessionType): { ok: boolean; reason?: string } {
  if (!session) return { ok: false, reason: 'No active session.' }
  const now = new Date()
  const h = now.getHours()
  const m = now.getMinutes()
  const timeNum = h * 60 + m
  const t = (hh: number, mm: number) => hh * 60 + mm

  if (session === 'night') {
    // Night sign-out: after sign-in, before 11am
    if (timeNum < t(11, 0)) return { ok: true }
    return { ok: false, reason: 'Night session sign-out must be done before 11:00 AM.' }
  }
  // Day sessions: must sign out before 8pm
  if (timeNum >= t(20, 0)) return { ok: false, reason: 'Sign-out must be completed before 8:00 PM.' }
  return { ok: true }
}

function isMonday(): boolean {
  return new Date().getDay() === 1
}

function getNoteRequirement(action: 'in' | 'out', session: SessionType): { required: boolean; minChars: number; label: string } {
  if (action === 'in' && isMonday()) {
    return { required: true, minChars: 200, label: 'What did you do over the weekend? (min 200 characters)' }
  }
  if (action === 'out') {
    return { required: true, minChars: 100, label: 'What did you learn in the office today? (min 100 characters)' }
  }
  return { required: false, minChars: 0, label: '' }
}

export default function ScannerPage({ today }: { today: string }) {
  const [step, setStep] = useState<'id' | 'note' | 'done'>('id')
  const [memberId, setMemberId] = useState('')
  const [note, setNote] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [pendingAction, setPendingAction] = useState<{
    profileId: string
    name: string
    action: 'in' | 'out'
    existingId?: string
    session: SessionType
  } | null>(null)
  const [result, setResult] = useState<{ name: string; action: string; time: string } | null>(null)
  const [recentScans, setRecentScans] = useState<{ name: string; action: string; time: string }[]>([])

  const session = getSessionType()

  async function handleIdSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!memberId.trim()) return
    setLoading(true)
    setError('')

    const supabase = createClient()
    const id = memberId.trim().toUpperCase()

    // Find member
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, full_name, member_id, approved, activity_status')
      .eq('member_id', id)
      .single()

    if (profileError || !profile) {
      setError(`Member ID "${id}" not found.`)
      setLoading(false)
      return
    }
    if (!profile.approved) {
      setError(`${profile.full_name} is not yet approved.`)
      setLoading(false)
      return
    }

    // Check today's record
    const isNight = session === 'night'
    const { data: existing } = await supabase
      .from('attendance')
      .select('*')
      .eq('user_id', profile.id)
      .eq('date', today)
      .eq('is_night_session', isNight)
      .maybeSingle()

    let action: 'in' | 'out'
    if (!existing || !existing.sign_in_time) {
      // Need to sign IN — check time
      const check = isSignInAllowed(session)
      if (!check.ok) {
        setError(check.reason ?? 'Sign-in not allowed at this time.')
        setLoading(false)
        setMemberId('')
        return
      }
      action = 'in'
    } else if (existing.sign_in_time && !existing.sign_out_time) {
      // Need to sign OUT — check time
      const check = isSignOutAllowed(session)
      if (!check.ok) {
        setError(check.reason ?? 'Sign-out not allowed at this time.')
        setLoading(false)
        setMemberId('')
        return
      }
      action = 'out'
    } else {
      setError(`${profile.full_name} has already completed attendance for this session.`)
      setLoading(false)
      setMemberId('')
      return
    }

    const noteReq = getNoteRequirement(action, session)
    setPendingAction({
      profileId: profile.id,
      name: profile.full_name,
      action,
      existingId: existing?.id,
      session,
    })

    if (noteReq.required) {
      setStep('note')
    } else {
      await completeAction(profile.id, profile.full_name, action, existing?.id, '', session)
    }

    setLoading(false)
    setMemberId('')
  }

  async function handleNoteSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!pendingAction) return
    const noteReq = getNoteRequirement(pendingAction.action, pendingAction.session)
    if (note.trim().length < noteReq.minChars) {
      setError(`Please write at least ${noteReq.minChars} characters. You have ${note.trim().length}.`)
      return
    }
    setLoading(true)
    await completeAction(
      pendingAction.profileId,
      pendingAction.name,
      pendingAction.action,
      pendingAction.existingId,
      note.trim(),
      pendingAction.session
    )
    setLoading(false)
  }

  async function completeAction(
    profileId: string,
    name: string,
    action: 'in' | 'out',
    existingId: string | undefined,
    noteText: string,
    sess: SessionType
  ) {
    const supabase = createClient()
    const now = new Date()
    const timeStr = format(now, 'HH:mm:ss')
    const isNight = sess === 'night'

    if (action === 'in') {
      await supabase.from('attendance').insert({
        user_id: profileId,
        date: today,
        sign_in_time: now.toISOString(),
        sign_in_note: noteText || null,
        is_night_session: isNight,
      })
    } else {
      await supabase.from('attendance').update({
        sign_out_time: now.toISOString(),
        sign_out_note: noteText || null,
      }).eq('id', existingId!)
    }

    // Check if inactive (not been in 2 weeks) and notify admins
    const twoWeeksAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)
    const { data: recentAttendance } = await supabase
      .from('attendance')
      .select('date')
      .eq('user_id', profileId)
      .gte('date', twoWeeksAgo)
      .not('id', 'eq', existingId ?? '00000000-0000-0000-0000-000000000000')
      .limit(1)

    if (!recentAttendance?.length && action === 'in') {
      // Was inactive — notify admins
      const { data: admins } = await supabase
        .from('profiles')
        .select('id')
        .or('is_admin.eq.true,is_director.eq.true,is_co_admin.eq.true')
        .eq('approved', true)
      if (admins?.length) {
        await supabase.from('notifications').insert(
          admins.map(a => ({
            user_id: a.id,
            title: '🔔 Inactive Member Returned',
            body: `${name} signed in after 2+ weeks absence.`,
            type: 'warning',
            link: '/people',
          }))
        )
      }
    }

    // Update last_seen
    await supabase.rpc('update_last_seen', { p_user_id: profileId })

    setResult({ name, action: action === 'in' ? 'SIGNED IN' : 'SIGNED OUT', time: timeStr })
    setRecentScans(prev => [{ name, action: action === 'in' ? 'IN' : 'OUT', time: timeStr }, ...prev.slice(0, 9)])
    setStep('id')
    setNote('')
    setPendingAction(null)
    setError('')
    setTimeout(() => setResult(null), 5000)
  }

  const noteReq = pendingAction ? getNoteRequirement(pendingAction.action, pendingAction.session) : null

  return (
    <div className="min-h-screen bg-gray-950 flex flex-col items-center justify-center p-4">
      <div className="text-center mb-8">
        <div className="text-4xl mb-2">⚡</div>
        <h1 className="text-2xl font-extrabold text-white">Elevate Office Scanner</h1>
        <p className="text-gray-400 text-sm mt-1">{format(new Date(), 'EEEE, MMMM d yyyy · HH:mm')}</p>
        {session ? (
          <span className="inline-block mt-2 px-3 py-1 rounded-full text-xs font-bold bg-green-900 text-green-300">
            {session === 'night' ? '🌙 Night Session' : session === 'friday' ? '📅 Friday Session' : '☀️ Day Session'} — Active
          </span>
        ) : (
          <span className="inline-block mt-2 px-3 py-1 rounded-full text-xs font-bold bg-red-900 text-red-300">
            ⛔ Office Closed
          </span>
        )}
      </div>

      {/* Result */}
      {result && (
        <div className="w-full max-w-md mb-6 rounded-2xl p-6 text-center bg-green-900 border-2 border-green-500">
          <CheckCircle className="mx-auto mb-3 text-green-400" size={48} />
          <div className="text-3xl font-black text-white mb-1">{result.name}</div>
          <div className={`text-lg font-bold mb-1 ${result.action === 'SIGNED IN' ? 'text-green-400' : 'text-orange-400'}`}>
            {result.action === 'SIGNED IN' ? <LogIn className="inline mr-2" size={20} /> : <LogOut className="inline mr-2" size={20} />}
            {result.action}
          </div>
          <div className="text-gray-300 text-sm"><Clock className="inline mr-1" size={14} />{result.time}</div>
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="w-full max-w-md mb-4 rounded-xl p-4 bg-red-900 border border-red-500 flex items-start gap-3">
          <AlertCircle className="text-red-400 flex-shrink-0 mt-0.5" size={18} />
          <div className="text-red-200 text-sm">{error}</div>
        </div>
      )}

      {/* Step: ID input */}
      {step === 'id' && (
        <form onSubmit={handleIdSubmit} className="w-full max-w-md">
          <div className="bg-gray-900 rounded-2xl p-6 border border-gray-800">
            <label className="block text-gray-300 text-sm font-semibold mb-3 text-center">
              Enter Member ID
            </label>
            <input
              type="text"
              value={memberId}
              onChange={e => { setMemberId(e.target.value.toUpperCase()); setError('') }}
              placeholder="e.g. RED001"
              autoFocus
              autoComplete="off"
              className="w-full bg-gray-800 border border-gray-700 text-white text-center text-2xl font-mono font-bold rounded-xl px-4 py-4 mb-4 focus:outline-none focus:border-indigo-500 placeholder-gray-600 tracking-widest uppercase"
            />
            <button type="submit" disabled={loading || !memberId.trim() || !session}
              className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-4 rounded-xl text-lg disabled:opacity-40 transition-all">
              {loading ? 'Processing…' : !session ? 'Office Closed' : 'Submit'}
            </button>
          </div>
        </form>
      )}

      {/* Step: Note input */}
      {step === 'note' && pendingAction && noteReq && (
        <form onSubmit={handleNoteSubmit} className="w-full max-w-md">
          <div className="bg-gray-900 rounded-2xl p-6 border border-gray-800">
            <div className="text-center mb-4">
              <div className="text-white font-bold text-lg">{pendingAction.name}</div>
              <div className={`text-sm font-semibold mt-1 ${pendingAction.action === 'in' ? 'text-green-400' : 'text-orange-400'}`}>
                {pendingAction.action === 'in' ? 'Signing In' : 'Signing Out'}
              </div>
            </div>
            <label className="block text-gray-300 text-sm font-semibold mb-2">{noteReq.label}</label>
            <textarea
              value={note}
              onChange={e => { setNote(e.target.value); setError('') }}
              rows={5}
              autoFocus
              className="w-full bg-gray-800 border border-gray-700 text-white rounded-xl px-4 py-3 mb-2 focus:outline-none focus:border-indigo-500 text-sm resize-none"
              placeholder="Write here…"
            />
            <div className={`text-xs mb-4 text-right ${note.trim().length >= noteReq.minChars ? 'text-green-400' : 'text-gray-500'}`}>
              {note.trim().length} / {noteReq.minChars} characters
            </div>
            <div className="flex gap-3">
              <button type="button" onClick={() => { setStep('id'); setPendingAction(null); setNote(''); setError('') }}
                className="flex-1 bg-gray-800 text-gray-300 font-bold py-3 rounded-xl hover:bg-gray-700 transition-all">
                Cancel
              </button>
              <button type="submit" disabled={loading || note.trim().length < noteReq.minChars}
                className="flex-2 flex-1 bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-3 rounded-xl disabled:opacity-40 transition-all">
                {loading ? 'Saving…' : 'Confirm'}
              </button>
            </div>
          </div>
        </form>
      )}

      {/* Recent scans */}
      {recentScans.length > 0 && (
        <div className="w-full max-w-md mt-6">
          <h3 className="text-gray-500 text-xs font-semibold mb-2 text-center">RECENT SCANS</h3>
          <div className="space-y-1">
            {recentScans.map((s, i) => (
              <div key={i} className="flex items-center gap-3 bg-gray-900 rounded-lg px-4 py-2">
                <div className={`w-2 h-2 rounded-full ${s.action === 'IN' ? 'bg-green-500' : 'bg-orange-500'}`} />
                <span className="text-white text-sm font-medium flex-1">{s.name}</span>
                <span className={`text-xs font-bold ${s.action === 'IN' ? 'text-green-400' : 'text-orange-400'}`}>{s.action}</span>
                <span className="text-gray-500 text-xs">{s.time}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
