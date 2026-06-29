'use client'

import { useEffect, useRef, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { format } from 'date-fns'
import { isSignInAllowed, isSignOutAllowed } from '@/lib/utils'

export default function QRScanner({
  isAdmin,
  adminProfileId,
}: {
  isAdmin: boolean
  adminProfileId: string
}) {
  const [scannedId, setScannedId] = useState('')
  const [mode, setMode] = useState<'in' | 'out'>('in')
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState(false)
  const [note, setNote] = useState('')
  const inputRef = useRef<HTMLInputElement>(null)

  // For QR scanning we support manual ID entry (the QR links to this page)
  // The page can also be opened directly from the QR code URL

  async function handleRecord() {
    if (!scannedId.trim()) return
    if (note.length < 100) {
      setMsg({ type: 'error', text: 'Please write at least 100 characters in your note.' })
      return
    }

    setLoading(true)
    setMsg(null)
    const supabase = createClient()
    const today = format(new Date(), 'yyyy-MM-dd')
    const now = new Date()

    // Look up user by member_id
    const { data: user } = await supabase
      .from('profiles')
      .select('id, full_name, member_id')
      .ilike('member_id', scannedId.trim())
      .single()

    if (!user) {
      setMsg({ type: 'error', text: `No member found with ID "${scannedId}"` })
      setLoading(false)
      return
    }

    if (mode === 'in') {
      if (!isSignInAllowed(now)) {
        setMsg({ type: 'error', text: 'Sign-in is not open yet for this session.' })
        setLoading(false)
        return
      }
      const { error } = await supabase.from('attendance').upsert({
        user_id: user.id,
        date: today,
        sign_in_time: now.toISOString(),
        sign_in_note: note,
        is_night_session: now.getHours() >= 21,
      }, { onConflict: 'user_id,date,is_night_session' })

      if (error) setMsg({ type: 'error', text: error.message })
      else {
        setMsg({ type: 'success', text: `✓ ${user.full_name} (${user.member_id}) signed IN at ${format(now, 'h:mm a')}` })
        setScannedId('')
        setNote('')
      }
    } else {
      if (!isSignOutAllowed(now)) {
        setMsg({ type: 'error', text: 'Sign-out is not open yet.' })
        setLoading(false)
        return
      }
      const { error } = await supabase.from('attendance')
        .update({ sign_out_time: now.toISOString(), sign_out_note: note })
        .eq('user_id', user.id)
        .eq('date', today)

      if (error) setMsg({ type: 'error', text: error.message })
      else {
        setMsg({ type: 'success', text: `✓ ${user.full_name} (${user.member_id}) signed OUT at ${format(now, 'h:mm a')}` })
        setScannedId('')
        setNote('')
      }
    }
    setLoading(false)
    inputRef.current?.focus()
  }

  return (
    <div className="card p-6 max-w-md mx-auto space-y-5">
      <h2 className="section-title">Sign In / Out by ID</h2>
      <p className="text-sm text-gray-500">
        Members enter their ID here to sign in or out. This page also opens from the office QR code.
      </p>

      <div className="flex gap-2">
        {(['in', 'out'] as const).map(m => (
          <button
            key={m}
            onClick={() => setMode(m)}
            className={`flex-1 py-2 rounded-lg text-sm font-semibold transition-colors ${
              mode === m ? 'bg-brand-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            Sign {m === 'in' ? 'In' : 'Out'}
          </button>
        ))}
      </div>

      <div>
        <label className="label">Member ID</label>
        <input
          ref={inputRef}
          className="input"
          value={scannedId}
          onChange={e => setScannedId(e.target.value.toUpperCase())}
          placeholder="e.g. RED001"
          onKeyDown={e => e.key === 'Enter' && inputRef.current?.blur()}
        />
      </div>

      <div>
        <label className="label">
          {mode === 'in'
            ? 'What did you do with your business yesterday? (min 100 chars)'
            : 'What did you do in the office today? (min 100 chars)'}
        </label>
        <textarea
          className="input resize-none"
          rows={3}
          value={note}
          onChange={e => setNote(e.target.value)}
          placeholder="Write at least 100 characters…"
        />
        <div className="text-xs text-gray-400 mt-1">{note.length} / 100 min</div>
      </div>

      {msg && (
        <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      <button
        onClick={handleRecord}
        className="btn-primary w-full py-3"
        disabled={loading || !scannedId.trim()}
      >
        {loading ? 'Processing…' : `Record Sign ${mode === 'in' ? 'In' : 'Out'}`}
      </button>
    </div>
  )
}
