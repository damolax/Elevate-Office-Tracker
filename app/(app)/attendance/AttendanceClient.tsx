'use client'

import { useState } from 'react'
import { format, parseISO } from 'date-fns'
import { createClient } from '@/lib/supabase/client'
import type { Profile, Attendance } from '@/lib/types'
import { formatTime, getStatusLabel } from '@/lib/utils'
import { Clock, CheckCircle, QrCode, ExternalLink } from 'lucide-react'
import QRCodeDisplay from '@/components/attendance/QRCodeDisplay'

export default function AttendanceClient({
  profile, isAdmin, myMonthAttendance, todayRecord, selectedDate, dateAttendance, allApprovedProfiles,
}: {
  profile: Profile
  isAdmin: boolean
  myMonthAttendance: Attendance[]
  todayRecord: Attendance | null
  selectedDate: string
  dateAttendance: (Attendance & { profiles: { full_name: string; member_id: string; status: string; color_groups: { name: string; hex_color: string } } })[]
  allApprovedProfiles: { id: string; full_name: string; member_id: string | null }[]
}) {
  const [tab, setTab] = useState<'me' | 'qr' | 'office' | 'scanner-link'>('me')
  const [manualUserId, setManualUserId] = useState('')
  const [manualSignIn, setManualSignIn] = useState('09:00')
  const [manualSignOut, setManualSignOut] = useState('')
  const [manualLoading, setManualLoading] = useState(false)
  const [manualMsg, setManualMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const today = format(new Date(), 'yyyy-MM-dd')
  const hasSigned = !!todayRecord?.sign_in_time
  const hasSignedOut = !!todayRecord?.sign_out_time

  async function submitManualAttendance() {
    if (!manualUserId) {
      setManualMsg({ type: 'error', text: 'Pick a person first.' })
      return
    }
    setManualLoading(true)
    setManualMsg(null)
    const supabase = createClient()
    const signInIso = manualSignIn ? new Date(`${selectedDate}T${manualSignIn}:00`).toISOString() : null
    const signOutIso = manualSignOut ? new Date(`${selectedDate}T${manualSignOut}:00`).toISOString() : null
    const { error } = await supabase.from('attendance').upsert({
      user_id: manualUserId,
      date: selectedDate,
      is_night_session: false,
      sign_in_time: signInIso,
      sign_out_time: signOutIso,
    }, { onConflict: 'user_id,date,is_night_session' })
    setManualLoading(false)
    if (error) {
      setManualMsg({ type: 'error', text: error.message })
      return
    }
    setManualMsg({ type: 'success', text: 'Attendance saved.' })
    setTimeout(() => window.location.reload(), 800)
  }

  const TABS = [
    { id: 'me', label: 'My Attendance' },
    { id: 'qr', label: 'My QR Code' },
    ...(isAdmin ? [
      { id: 'office', label: 'Office View' },
      { id: 'scanner-link', label: '📱 Office Scanner' },
    ] : []),
  ]

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {TABS.map(t => (
          <button key={t.id} onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* MY ATTENDANCE — view only, no sign-in form */}
      {tab === 'me' && (
        <div className="space-y-4">
          <div className="card p-6">
            <h2 className="section-title mb-4">Today — {format(new Date(), 'EEEE, MMMM d')}</h2>

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

            {hasSigned ? (
              <div className="flex items-center gap-2 text-green-600 text-sm font-medium">
                <CheckCircle size={16} /> Attendance recorded today
              </div>
            ) : (
              <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-sm text-amber-700">
                <strong>No attendance today.</strong> Visit the office and sign in using the office scanner. Ask your admin for the scanner link.
              </div>
            )}
          </div>

          {/* Monthly calendar */}
          <div className="card p-5">
            <h2 className="section-title mb-4">This Month</h2>
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
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* QR CODE — personal */}
      {tab === 'qr' && (
        <div className="card p-6 max-w-sm mx-auto text-center">
          <h2 className="section-title mb-4">Your QR Code</h2>
          <p className="text-sm text-gray-500 mb-4">Scan this at the office scanner or show it to the admin.</p>
          <QRCodeDisplay profile={profile} />
          <div className="mt-4 font-mono font-bold text-2xl text-gray-700 tracking-widest">{profile.member_id}</div>
        </div>
      )}

      {/* OFFICE VIEW — admin only */}
      {tab === 'office' && isAdmin && (
        <div className="card p-5">
          <div className="flex items-center justify-between mb-4">
            <h2 className="section-title">Office Attendance</h2>
            <input type="date" className="input w-auto" defaultValue={selectedDate}
              onChange={e => {
                const url = new URL(window.location.href)
                url.searchParams.set('date', e.target.value)
                window.location.href = url.toString()
              }} />
          </div>
          <p className="text-sm text-gray-500 mb-4">
            {dateAttendance.length} people signed in on {format(parseISO(selectedDate), 'EEEE, MMMM d, yyyy')}
          </p>

          {/* Manual entry — for forgotten sign-ins on past (or current) dates */}
          <div className="border border-gray-200 rounded-lg p-4 mb-5 bg-gray-50">
            <p className="text-xs font-semibold text-gray-500 mb-2 uppercase tracking-wide">Manual Entry / Edit</p>
            <div className="flex flex-wrap gap-2 items-center">
              <select className="input w-auto" value={manualUserId} onChange={e => setManualUserId(e.target.value)}>
                <option value="">Select person…</option>
                {allApprovedProfiles.map(p => (
                  <option key={p.id} value={p.id}>{p.full_name} {p.member_id ? `(${p.member_id})` : ''}</option>
                ))}
              </select>
              <label className="text-xs text-gray-500">Sign in
                <input type="time" className="input w-auto ml-1" value={manualSignIn} onChange={e => setManualSignIn(e.target.value)} />
              </label>
              <label className="text-xs text-gray-500">Sign out
                <input type="time" className="input w-auto ml-1" value={manualSignOut} onChange={e => setManualSignOut(e.target.value)} />
              </label>
              <button className="btn-primary text-sm" disabled={manualLoading} onClick={submitManualAttendance}>
                {manualLoading ? 'Saving…' : `Save for ${format(parseISO(selectedDate), 'MMM d')}`}
              </button>
            </div>
            {manualMsg && (
              <p className={`text-xs mt-2 ${manualMsg.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>{manualMsg.text}</p>
            )}
            <p className="text-xs text-gray-400 mt-2">Use this to fix a forgotten sign-in/out for the date selected above.</p>
          </div>
          {dateAttendance.length === 0 ? (
            <p className="text-gray-400 text-sm text-center py-8">No attendance for this date</p>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100">
                  <th className="table-th">Name</th>
                  <th className="table-th">ID</th>
                  <th className="table-th">Group</th>
                  <th className="table-th">Sign In</th>
                  <th className="table-th">Sign Out</th>
                </tr>
              </thead>
              <tbody>
                {dateAttendance.map((a: any) => (
                  <tr key={a.id} className="table-row">
                    <td className="table-td font-medium">{a.profiles?.full_name}</td>
                    <td className="table-td text-gray-400 font-mono">{a.profiles?.member_id}</td>
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
          )}
        </div>
      )}

      {/* SCANNER LINK — admin only */}
      {tab === 'scanner-link' && isAdmin && (
        <div className="card p-6 max-w-lg">
          <h2 className="section-title mb-2">Office Scanner</h2>
          <p className="text-sm text-gray-500 mb-6">
            Open this link on a tablet or phone in the office. Members walk up and enter their Member ID to sign in or out.
            The session resets automatically every day.
          </p>

          <div className="bg-indigo-50 border border-indigo-200 rounded-xl p-5 mb-4">
            <div className="text-xs text-indigo-400 font-semibold mb-2 uppercase tracking-wide">Scanner URL</div>
            <div className="font-mono text-indigo-700 font-bold text-sm break-all mb-3">
              {typeof window !== 'undefined' ? window.location.origin : ''}/scanner
            </div>
            <div className="flex gap-2">
              <button onClick={() => { navigator.clipboard.writeText((typeof window !== 'undefined' ? window.location.origin : '') + '/scanner'); }}
                className="btn-secondary text-sm flex-1">
                📋 Copy Link
              </button>
              <a href="/scanner" target="_blank" rel="noreferrer" className="btn-primary text-sm flex-1 text-center">
                <ExternalLink size={14} className="inline mr-1" />Open Scanner
              </a>
            </div>
          </div>

          <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-sm text-amber-700">
            <strong>How it works:</strong>
            <ul className="mt-2 space-y-1 list-disc list-inside">
              <li>Open /scanner on an office device (tablet recommended)</li>
              <li>Member enters their Member ID (e.g. RED001)</li>
              <li>First scan = Sign In. Second scan = Sign Out</li>
              <li>No login required on the scanner device</li>
              <li>Session auto-resets at midnight daily</li>
            </ul>
          </div>
        </div>
      )}
    </div>
  )
}
