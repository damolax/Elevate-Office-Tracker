'use client'

import { useState } from 'react'
import { format, parseISO } from 'date-fns'
import { createClient } from '@/lib/supabase/client'
import type { Profile, Attendance } from '@/lib/types'
import { formatTime, isSignInAllowed, isSignOutAllowed, getStatusLabel, getStatusColor } from '@/lib/utils'
import { Clock, CheckCircle, XCircle, QrCode, Download } from 'lucide-react'
import QRCodeDisplay from '@/components/attendance/QRCodeDisplay'
import QRScanner from '@/components/attendance/QRScanner'

export default function AttendanceClient({
  profile, isAdmin, myMonthAttendance, todayRecord, selectedDate, dateAttendance,
}: {
  profile: Profile
  isAdmin: boolean
  myMonthAttendance: Attendance[]
  todayRecord: Attendance | null
  selectedDate: string
  dateAttendance: (Attendance & { profiles: { full_name: string; member_id: string; status: string; color_groups: { name: string; hex_color: string } } })[]
}) {
  const [tab, setTab] = useState<'me' | 'qr' | 'office' | 'scanner'>('me')
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [signInNote, setSignInNote] = useState('')
  const [signOutNote, setSignOutNote] = useState('')
  const [isNight, setIsNight] = useState(false)
  const [showSignIn, setShowSignIn] = useState(false)
  const [showSignOut, setShowSignOut] = useState(false)
  const [scanDate, setScanDate] = useState(selectedDate)

  const today = format(new Date(), 'yyyy-MM-dd')
  const dayOfWeek = new Date().getDay()
  const isMonday = dayOfWeek === 1

  const minSignInChars = isMonday ? 200 : 100
  const signInLabel = isMonday
    ? 'What did you do with your business throughout the weekend? (min 200 chars)'
    : 'What did you do with your business throughout yesterday? (min 100 chars)'

  async function handleSignIn() {
    if (signInNote.length < minSignInChars) {
      setMsg({ type: 'error', text: `Please write at least ${minSignInChars} characters.` })
      return
    }
    const now = new Date()
    if (!isSignInAllowed(now, isNight)) {
      setMsg({ type: 'error', text: isNight ? 'Night sign-in opens at 10:00 PM' : dayOfWeek === 5 ? 'Friday sign-in opens at 2:00 PM' : 'Sign-in opens at 11:00 AM (Mon–Thu)' })
      return
    }
    setLoading(true)
    setMsg(null)
    const supabase = createClient()
    const { error } = await supabase.from('attendance').upsert({
      user_id: profile.id,
      date: today,
      sign_in_time: now.toISOString(),
      is_night_session: isNight,
      sign_in_note: signInNote,
    }, { onConflict: 'user_id,date,is_night_session' })

    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: 'Signed in successfully!' })
      setShowSignIn(false)
      setTimeout(() => window.location.reload(), 1000)
    }
    setLoading(false)
  }

  async function handleSignOut() {
    if (signOutNote.length < 100) {
      setMsg({ type: 'error', text: 'Please write at least 100 characters about what you did today.' })
      return
    }
    const now = new Date()
    if (!isSignOutAllowed(now, isNight)) {
      setMsg({ type: 'error', text: dayOfWeek === 5 ? 'Friday sign-out opens at 7:00 PM' : 'Sign-out opens at 5:00 PM (Mon–Thu)' })
      return
    }
    setLoading(true)
    setMsg(null)
    const supabase = createClient()
    const { error } = await supabase.from('attendance')
      .update({ sign_out_time: now.toISOString(), sign_out_note: signOutNote })
      .eq('user_id', profile.id)
      .eq('date', today)
      .eq('is_night_session', isNight)

    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: 'Signed out successfully!' })
      setShowSignOut(false)
      setTimeout(() => window.location.reload(), 1000)
    }
    setLoading(false)
  }

  const hasSigned = !!todayRecord?.sign_in_time
  const hasSignedOut = !!todayRecord?.sign_out_time

  const TABS = [
    { id: 'me', label: 'My Attendance' },
    ...(isAdmin ? [
      { id: 'qr', label: 'QR Code' },
      { id: 'office', label: 'Office View' },
      { id: 'scanner', label: 'QR Scanner' },
    ] : [
      { id: 'scanner', label: 'Scan QR' },
    ]),
  ]

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
        {TABS.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
              tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* My Attendance tab */}
      {tab === 'me' && (
        <div className="space-y-4">
          {/* Today's status */}
          <div className="card p-6">
            <h2 className="section-title mb-4">Today — {format(new Date(), 'EEEE, MMMM d')}</h2>

            {msg && (
              <div className={`mb-4 px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
                {msg.text}
              </div>
            )}

            <div className="grid grid-cols-2 gap-4 mb-4">
              <div className="text-center p-4 bg-blue-50 rounded-xl">
                <Clock className="mx-auto mb-1 text-blue-600" size={24} />
                <div className="text-xs text-gray-500 mb-0.5">Sign In</div>
                <div className="font-bold text-blue-700">{hasSigned ? formatTime(todayRecord!.sign_in_time) : '—'}</div>
              </div>
              <div className="text-center p-4 bg-orange-50 rounded-xl">
                <Clock className="mx-auto mb-1 text-orange-600" size={24} />
                <div className="text-xs text-gray-500 mb-0.5">Sign Out</div>
                <div className="font-bold text-orange-700">{hasSignedOut ? formatTime(todayRecord!.sign_out_time) : '—'}</div>
              </div>
            </div>

            <div className="flex items-center gap-2 mb-4">
              <input type="checkbox" id="night" checked={isNight} onChange={e => setIsNight(e.target.checked)} />
              <label htmlFor="night" className="text-sm text-gray-600">Night session (sign-in after 10 PM)</label>
            </div>

            <div className="flex gap-3">
              {!hasSigned && (
                <button onClick={() => setShowSignIn(true)} className="btn-primary flex-1">
                  Sign In
                </button>
              )}
              {hasSigned && !hasSignedOut && !isNight && (
                <button onClick={() => setShowSignOut(true)} className="btn-secondary flex-1">
                  Sign Out
                </button>
              )}
              {hasSigned && (
                <div className="flex items-center gap-1 text-green-600 text-sm font-medium">
                  <CheckCircle size={16} /> Signed in today
                </div>
              )}
            </div>

            {/* Sign In Modal */}
            {showSignIn && (
              <div className="mt-4 p-4 bg-gray-50 rounded-xl border border-gray-200 space-y-3">
                <label className="label">{signInLabel}</label>
                <textarea
                  className="input resize-none"
                  rows={4}
                  value={signInNote}
                  onChange={e => setSignInNote(e.target.value)}
                  placeholder={`Write at least ${minSignInChars} characters…`}
                />
                <div className="text-xs text-gray-400">{signInNote.length} / {minSignInChars} min</div>
                <div className="flex gap-2">
                  <button onClick={handleSignIn} className="btn-primary" disabled={loading}>
                    {loading ? 'Signing in…' : 'Confirm Sign In'}
                  </button>
                  <button onClick={() => setShowSignIn(false)} className="btn-secondary">Cancel</button>
                </div>
              </div>
            )}

            {/* Sign Out Modal */}
            {showSignOut && (
              <div className="mt-4 p-4 bg-gray-50 rounded-xl border border-gray-200 space-y-3">
                <label className="label">What did you do in the office today? (min 100 chars)</label>
                <textarea
                  className="input resize-none"
                  rows={4}
                  value={signOutNote}
                  onChange={e => setSignOutNote(e.target.value)}
                  placeholder="Write at least 100 characters…"
                />
                <div className="text-xs text-gray-400">{signOutNote.length} / 100 min</div>
                <div className="flex gap-2">
                  <button onClick={handleSignOut} className="btn-primary" disabled={loading}>
                    {loading ? 'Signing out…' : 'Confirm Sign Out'}
                  </button>
                  <button onClick={() => setShowSignOut(false)} className="btn-secondary">Cancel</button>
                </div>
              </div>
            )}
          </div>

          {/* Monthly calendar */}
          <div className="card p-5">
            <h2 className="section-title mb-4">This Month&apos;s Attendance</h2>
            {myMonthAttendance.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No attendance records this month</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-gray-100">
                      <th className="table-th">Date</th>
                      <th className="table-th">Sign In</th>
                      <th className="table-th">Sign Out</th>
                      <th className="table-th">Session</th>
                      <th className="table-th">Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    {myMonthAttendance.map(a => (
                      <tr key={a.id} className="table-row">
                        <td className="table-td font-medium">{format(parseISO(a.date), 'EEE, MMM d')}</td>
                        <td className="table-td">{a.sign_in_time ? formatTime(a.sign_in_time) : '—'}</td>
                        <td className="table-td">{a.sign_out_time ? formatTime(a.sign_out_time) : '—'}</td>
                        <td className="table-td">
                          <span className={`badge ${a.is_night_session ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700'}`}>
                            {a.is_night_session ? 'Night' : 'Day'}
                          </span>
                        </td>
                        <td className="table-td max-w-xs truncate text-gray-400 text-xs">
                          {a.sign_in_note?.slice(0, 50) ?? '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* QR Code tab (admin) */}
      {tab === 'qr' && isAdmin && (
        <QRCodeDisplay profile={profile} />
      )}

      {/* Office View tab (admin) */}
      {tab === 'office' && isAdmin && (
        <div className="card p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="section-title">Office Attendance</h2>
            <input
              type="date"
              className="input w-auto"
              defaultValue={selectedDate}
              onChange={e => {
                const url = new URL(window.location.href)
                url.searchParams.set('date', e.target.value)
                url.searchParams.set('view', 'office')
                window.location.href = url.toString()
              }}
            />
          </div>
          <p className="text-sm text-gray-500 mb-4">
            {dateAttendance.length} people signed in on {format(parseISO(selectedDate), 'EEEE, MMMM d, yyyy')}
          </p>
          {dateAttendance.length === 0 ? (
            <p className="text-gray-400 text-sm text-center py-8">No attendance for this date</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-100">
                    <th className="table-th">Name</th>
                    <th className="table-th">ID</th>
                    <th className="table-th">Status</th>
                    <th className="table-th">Group</th>
                    <th className="table-th">Sign In</th>
                    <th className="table-th">Sign Out</th>
                  </tr>
                </thead>
                <tbody>
                  {dateAttendance.map((a: any) => (
                    <tr key={a.id} className="table-row">
                      <td className="table-td font-medium">{a.profiles?.full_name}</td>
                      <td className="table-td text-gray-400">{a.profiles?.member_id}</td>
                      <td className="table-td">
                        <span className="badge bg-gray-100 text-gray-600">{getStatusLabel(a.profiles?.status)}</span>
                      </td>
                      <td className="table-td">
                        <div className="flex items-center gap-1.5">
                          <div className="w-3 h-3 rounded-full" style={{ backgroundColor: a.profiles?.color_groups?.hex_color ?? '#ccc' }} />
                          {a.profiles?.color_groups?.name ?? '—'}
                        </div>
                      </td>
                      <td className="table-td">{formatTime(a.sign_in_time)}</td>
                      <td className="table-td">{a.sign_out_time ? formatTime(a.sign_out_time) : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* QR Scanner tab */}
      {tab === 'scanner' && (
        <QRScanner isAdmin={isAdmin} adminProfileId={profile.id} />
      )}
    </div>
  )
}
