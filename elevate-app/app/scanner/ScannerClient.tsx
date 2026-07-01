'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { format } from 'date-fns'
import { CheckCircle, Clock, LogIn, LogOut } from 'lucide-react'

export default function ScannerPage({ today, sessionToken }: { today: string; sessionToken: string }) {
  const [memberId, setMemberId] = useState('')
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState<{ type: 'success' | 'error'; name?: string; action?: string; time?: string; text?: string } | null>(null)
  const [recentScans, setRecentScans] = useState<{ name: string; action: string; time: string }[]>([])

  async function handleScan(e: React.FormEvent) {
    e.preventDefault()
    if (!memberId.trim()) return
    setLoading(true)
    setResult(null)

    const supabase = createClient()
    const id = memberId.trim().toUpperCase()

    // Find the member by ID
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, full_name, member_id, approved, activity_status')
      .eq('member_id', id)
      .single()

    if (profileError || !profile) {
      setResult({ type: 'error', text: `Member ID "${id}" not found. Please check the ID and try again.` })
      setLoading(false)
      setMemberId('')
      return
    }

    if (!profile.approved) {
      setResult({ type: 'error', text: `${profile.full_name} is not yet approved.` })
      setLoading(false)
      setMemberId('')
      return
    }

    const now = new Date()
    const timeStr = format(now, 'HH:mm:ss')

    // Check today's attendance record
    const { data: existing } = await supabase
      .from('attendance')
      .select('*')
      .eq('user_id', profile.id)
      .eq('date', today)
      .eq('is_night_session', false)
      .single()

    if (!existing) {
      // Sign IN
      const { error } = await supabase.from('attendance').insert({
        user_id: profile.id,
        date: today,
        sign_in_time: now.toISOString(),
        is_night_session: false,
        sign_in_note: 'Scanned in via office scanner',
      })
      if (error) {
        setResult({ type: 'error', text: error.message })
      } else {
        setResult({ type: 'success', name: profile.full_name, action: 'SIGNED IN', time: timeStr })
        setRecentScans(prev => [{ name: profile.full_name, action: 'IN', time: timeStr }, ...prev.slice(0, 9)])
      }
    } else if (existing.sign_in_time && !existing.sign_out_time) {
      // Sign OUT
      const { error } = await supabase.from('attendance')
        .update({ sign_out_time: now.toISOString(), sign_out_note: 'Scanned out via office scanner' })
        .eq('id', existing.id)
      if (error) {
        setResult({ type: 'error', text: error.message })
      } else {
        setResult({ type: 'success', name: profile.full_name, action: 'SIGNED OUT', time: timeStr })
        setRecentScans(prev => [{ name: profile.full_name, action: 'OUT', time: timeStr }, ...prev.slice(0, 9)])
      }
    } else {
      setResult({ type: 'error', text: `${profile.full_name} has already completed attendance for today.` })
    }

    setLoading(false)
    setMemberId('')

    // Auto-clear result after 4 seconds
    setTimeout(() => setResult(null), 4000)
  }

  return (
    <div className="min-h-screen bg-gray-950 flex flex-col items-center justify-center p-4">
      {/* Header */}
      <div className="text-center mb-8">
        <div className="text-4xl mb-2">⚡</div>
        <h1 className="text-2xl font-extrabold text-white">Elevate Office Scanner</h1>
        <p className="text-gray-400 text-sm mt-1">{format(new Date(), 'EEEE, MMMM d yyyy')}</p>
        <div className="mt-2 text-xs text-gray-600 font-mono">Session: {sessionToken}</div>
      </div>

      {/* Result display */}
      {result && (
        <div className={`w-full max-w-md mb-6 rounded-2xl p-6 text-center transition-all ${
          result.type === 'success' ? 'bg-green-900 border-2 border-green-500' : 'bg-red-900 border-2 border-red-500'
        }`}>
          {result.type === 'success' ? (
            <>
              <CheckCircle className="mx-auto mb-3 text-green-400" size={48} />
              <div className="text-3xl font-black text-white mb-1">{result.name}</div>
              <div className={`text-lg font-bold mb-1 ${result.action === 'SIGNED IN' ? 'text-green-400' : 'text-orange-400'}`}>
                {result.action === 'SIGNED IN' ? <LogIn className="inline mr-2" size={20} /> : <LogOut className="inline mr-2" size={20} />}
                {result.action}
              </div>
              <div className="text-gray-300 text-sm"><Clock className="inline mr-1" size={14} />{result.time}</div>
            </>
          ) : (
            <>
              <div className="text-4xl mb-3">❌</div>
              <div className="text-white font-semibold">{result.text}</div>
            </>
          )}
        </div>
      )}

      {/* Input form */}
      <form onSubmit={handleScan} className="w-full max-w-md">
        <div className="bg-gray-900 rounded-2xl p-6 border border-gray-800">
          <label className="block text-gray-300 text-sm font-semibold mb-3 text-center">
            Enter Member ID
          </label>
          <input
            type="text"
            value={memberId}
            onChange={e => setMemberId(e.target.value.toUpperCase())}
            placeholder="e.g. RED001"
            autoFocus
            autoComplete="off"
            className="w-full bg-gray-800 border border-gray-700 text-white text-center text-2xl font-mono font-bold rounded-xl px-4 py-4 mb-4 focus:outline-none focus:border-indigo-500 placeholder-gray-600 tracking-widest uppercase"
          />
          <button
            type="submit"
            disabled={loading || !memberId.trim()}
            className="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-4 rounded-xl text-lg disabled:opacity-40 disabled:cursor-not-allowed transition-all"
          >
            {loading ? 'Processing…' : 'Submit'}
          </button>
        </div>
      </form>

      {/* Recent scans */}
      {recentScans.length > 0 && (
        <div className="w-full max-w-md mt-6">
          <h3 className="text-gray-500 text-xs font-semibold mb-2 text-center">RECENT SCANS THIS SESSION</h3>
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

      <p className="text-gray-700 text-xs mt-8 text-center max-w-xs">
        This page is for office use only. Members enter their ID to sign in or out. First scan = sign in, second scan = sign out.
      </p>
    </div>
  )
}
