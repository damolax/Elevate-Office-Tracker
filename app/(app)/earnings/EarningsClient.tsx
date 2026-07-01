'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { format, startOfWeek, endOfWeek } from 'date-fns'
import type { Profile, Earnings } from '@/lib/types'
import { EARNINGS_TARGETS, STATUS_LABELS, getStatusLabel, isSmOrAbove, computeTeam, statusRank } from '@/lib/types'
import { DollarSign, TrendingUp, Target } from 'lucide-react'

export default function EarningsClient({
  profile, allProfiles, myEarnings, teamEarnings, isAdmin,
}: {
  profile: Profile
  allProfiles: Profile[]
  myEarnings: Earnings[]
  teamEarnings: (Earnings & { profiles: { full_name: string; member_id: string; status: string } })[]
  isAdmin: boolean
}) {
  const [tab, setTab] = useState<'mine' | 'team' | 'log'>('mine')
  const [logForm, setLogForm] = useState({
    user_id: profile.id,
    amount: '',
    week_start: format(startOfWeek(new Date(), { weekStartsOn: 1 }), 'yyyy-MM-dd'),
    week_end: format(endOfWeek(new Date(), { weekStartsOn: 1 }), 'yyyy-MM-dd'),
    note: '',
  })
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [customTarget, setCustomTarget] = useState(profile.earnings_target ?? EARNINGS_TARGETS[profile.status] ?? 0)

  const canLog = isAdmin || profile.is_director || profile.is_co_admin
  const canSeeTeam = isSmOrAbove(profile.status) || isAdmin

  // Current month earnings
  const currentMonth = format(new Date(), 'yyyy-MM')
  const myMonthTotal = myEarnings
    .filter(e => e.week_start.startsWith(currentMonth.slice(0, 7)))
    .reduce((sum, e) => sum + e.amount, 0)

  const target = profile.earnings_target ?? EARNINGS_TARGETS[profile.status] ?? 0

  async function logEarnings() {
    if (!logForm.amount || isNaN(parseFloat(logForm.amount))) {
      setMsg({ type: 'error', text: 'Enter a valid amount' })
      return
    }
    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.from('earnings').insert({
      user_id: logForm.user_id,
      amount: parseFloat(logForm.amount),
      week_start: logForm.week_start,
      week_end: logForm.week_end,
      note: logForm.note || null,
      logged_by: profile.id,
    })
    if (error) {
      setMsg({ type: 'error', text: error.message })
    } else {
      // Notify the person whose earnings were logged
      const targetProfile = allProfiles.find(p => p.id === logForm.user_id)
      if (targetProfile && targetProfile.id !== profile.id) {
        await supabase.from('notifications').insert({
          user_id: targetProfile.id,
          title: '💰 Earnings Logged',
          body: `$${parseFloat(logForm.amount).toFixed(2)} earnings logged for week of ${logForm.week_start} by ${profile.full_name}.`,
          type: 'success',
          link: '/earnings',
        })
      }
      // Check if target hit
      if (target > 0) {
        const newTotal = myMonthTotal + parseFloat(logForm.amount)
        if (newTotal >= target && myMonthTotal < target) {
          await supabase.from('notifications').insert({
            user_id: logForm.user_id,
            title: '🎯 Earnings Target Hit!',
            body: `You've reached your monthly target of $${target}!`,
            type: 'success',
            link: '/earnings',
          })
        }
      }
      setMsg({ type: 'success', text: 'Earnings logged!' })
      setLogForm(f => ({ ...f, amount: '', note: '' }))
      setTimeout(() => window.location.reload(), 1200)
    }
    setLoading(false)
  }

  async function saveCustomTarget() {
    const supabase = createClient()
    const min = EARNINGS_TARGETS[profile.status] ?? 0
    if (customTarget < min) {
      setMsg({ type: 'error', text: `Minimum target is $${min}` })
      return
    }
    await supabase.from('profiles').update({ earnings_target: customTarget }).eq('id', profile.id)
    setMsg({ type: 'success', text: 'Target updated!' })
  }

  const progressPct = target > 0 ? Math.min(100, (myMonthTotal / target) * 100) : 0

  return (
    <div className="max-w-4xl mx-auto space-y-5">
      {msg && (
        <div className={`px-4 py-3 rounded-xl text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
        <button onClick={() => setTab('mine')} className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === 'mine' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500'}`}>My Earnings</button>
        {canSeeTeam && <button onClick={() => setTab('team')} className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === 'team' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500'}`}>Team Earnings</button>}
        {canLog && <button onClick={() => setTab('log')} className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === 'log' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500'}`}>Log Earnings</button>}
      </div>

      {tab === 'mine' && (
        <div className="space-y-4">
          {/* Progress card */}
          {target > 0 && (
            <div className="card p-5">
              <div className="flex items-center justify-between mb-3">
                <div>
                  <div className="text-sm text-gray-500">This Month</div>
                  <div className="text-3xl font-extrabold text-gray-900">${myMonthTotal.toFixed(2)}</div>
                </div>
                <div className="text-right">
                  <div className="text-sm text-gray-500">Target</div>
                  <div className="text-2xl font-bold text-indigo-600">${target.toFixed(2)}</div>
                </div>
              </div>
              <div className="w-full bg-gray-100 rounded-full h-3 mb-2">
                <div className="h-3 rounded-full transition-all" style={{ width: `${progressPct}%`, backgroundColor: progressPct >= 100 ? '#10c980' : '#6366f1' }} />
              </div>
              <div className="text-xs text-gray-400">{progressPct.toFixed(0)}% of monthly target</div>

              {/* Custom target for distributors */}
              {profile.status === 'distributor' && (
                <div className="mt-4 pt-4 border-t border-gray-100">
                  <label className="text-sm font-medium text-gray-700 block mb-2">Set your own target (min $300)</label>
                  <div className="flex gap-2">
                    <input type="number" min={300} value={customTarget}
                      onChange={e => setCustomTarget(parseFloat(e.target.value))}
                      className="input flex-1" placeholder="300" />
                    <button onClick={saveCustomTarget} className="btn-primary">Save</button>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* History */}
          <div className="card p-5">
            <h2 className="section-title mb-4">Earnings History</h2>
            {myEarnings.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
            ) : (
              <table className="w-full text-sm">
                <thead><tr className="border-b border-gray-100">
                  <th className="table-th">Week</th>
                  <th className="table-th">Amount</th>
                  <th className="table-th">Note</th>
                </tr></thead>
                <tbody>
                  {myEarnings.map(e => (
                    <tr key={e.id} className="table-row">
                      <td className="table-td text-xs text-gray-500">{e.week_start} – {e.week_end}</td>
                      <td className="table-td font-bold text-green-600">${e.amount.toFixed(2)}</td>
                      <td className="table-td text-gray-400">{e.note ?? '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}

      {tab === 'team' && canSeeTeam && (
        <div className="card p-5">
          <h2 className="section-title mb-4">Team Earnings</h2>
          {teamEarnings.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No team earnings recorded</p>
          ) : (
            <table className="w-full text-sm">
              <thead><tr className="border-b border-gray-100">
                <th className="table-th">Member</th>
                <th className="table-th">Status</th>
                <th className="table-th">Week</th>
                <th className="table-th">Amount</th>
              </tr></thead>
              <tbody>
                {teamEarnings.map(e => (
                  <tr key={e.id} className="table-row">
                    <td className="table-td font-medium">{(e as any).profiles?.full_name}</td>
                    <td className="table-td text-xs text-gray-400">{getStatusLabel((e as any).profiles?.status)}</td>
                    <td className="table-td text-xs text-gray-400">{e.week_start}</td>
                    <td className="table-td font-bold text-green-600">${e.amount.toFixed(2)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {tab === 'log' && canLog && (
        <div className="card p-6 max-w-lg">
          <h2 className="section-title mb-4">Log Weekly Earnings</h2>
          <div className="space-y-4">
            <div>
              <label className="label">Member</label>
              <select className="input" value={logForm.user_id} onChange={e => setLogForm(f => ({ ...f, user_id: e.target.value }))}>
                {allProfiles.filter(p => p.approved).map(p => (
                  <option key={p.id} value={p.id}>{p.full_name} ({p.member_id ?? 'no ID'}) — {getStatusLabel(p.status)}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Amount ($)</label>
              <input type="number" min="0" step="0.01" className="input" placeholder="0.00"
                value={logForm.amount} onChange={e => setLogForm(f => ({ ...f, amount: e.target.value }))} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Week Start</label>
                <input type="date" className="input" value={logForm.week_start} onChange={e => setLogForm(f => ({ ...f, week_start: e.target.value }))} />
              </div>
              <div>
                <label className="label">Week End</label>
                <input type="date" className="input" value={logForm.week_end} onChange={e => setLogForm(f => ({ ...f, week_end: e.target.value }))} />
              </div>
            </div>
            <div>
              <label className="label">Note (optional)</label>
              <input type="text" className="input" placeholder="e.g. Sales commission week 3"
                value={logForm.note} onChange={e => setLogForm(f => ({ ...f, note: e.target.value }))} />
            </div>
            <button onClick={logEarnings} disabled={loading} className="btn-primary w-full">
              {loading ? 'Saving…' : 'Log Earnings'}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
