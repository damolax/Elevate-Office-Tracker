'use client'

import { useState, useMemo } from 'react'
import { format, startOfWeek, endOfWeek } from 'date-fns'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ColorGroup, WeeklyEarning } from '@/lib/types'
import { formatCurrency, getStatusLabel, getStatusColor, getWeekBounds, getWeekLabel } from '@/lib/utils'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts'

export default function MoneyClient({
  profile, isAdmin, myEarnings, allEarnings, colorGroups, allProfiles,
}: {
  profile: Profile
  isAdmin: boolean
  myEarnings: WeeklyEarning[]
  allEarnings: (WeeklyEarning & { profiles: { id: string; full_name: string; member_id: string; status: string; color_groups: { name: string; hex_color: string; code: string } } })[]
  colorGroups: ColorGroup[]
  allProfiles: Profile[]
}) {
  const [tab, setTab] = useState<'me' | 'leaderboard' | 'groups' | 'record'>('me')
  const [recordForm, setRecordForm] = useState({
    user_id: '',
    week_start: format(startOfWeek(new Date(), { weekStartsOn: 6 }), 'yyyy-MM-dd'),
    amount: '',
    notes: '',
  })
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState(false)
  const [statusFilter, setStatusFilter] = useState('all')
  const [groupFilter, setGroupFilter] = useState('all')

  const myTotal = myEarnings.reduce((s, e) => s + Number(e.amount_usd), 0)

  // Aggregate earnings by person for leaderboard
  const leaderboard = useMemo(() => {
    const map = new Map<string, { id: string; full_name: string; member_id: string; status: string; group_name: string; group_color: string; group_code: string; total: number }>()
    for (const e of allEarnings) {
      const p = e.profiles
      if (!p) continue
      const existing = map.get(p.id) ?? {
        id: p.id, full_name: p.full_name, member_id: p.member_id, status: p.status,
        group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#ccc', group_code: p.color_groups?.code ?? '',
        total: 0,
      }
      existing.total += Number(e.amount_usd)
      map.set(p.id, existing)
    }
    return Array.from(map.values())
      .filter(p => {
        if (statusFilter !== 'all' && p.status !== statusFilter) return false
        if (groupFilter !== 'all' && p.group_code !== groupFilter) return false
        return true
      })
      .sort((a, b) => b.total - a.total)
  }, [allEarnings, statusFilter, groupFilter])

  // Group totals
  const groupTotals = useMemo(() => {
    const map = new Map<string, { name: string; hex_color: string; total: number; count: number }>()
    for (const e of allEarnings) {
      const g = e.profiles?.color_groups
      if (!g) continue
      const existing = map.get(g.name) ?? { name: g.name, hex_color: g.hex_color, total: 0, count: 0 }
      existing.total += Number(e.amount_usd)
      existing.count++
      map.set(g.name, existing)
    }
    return Array.from(map.values()).sort((a, b) => b.total - a.total)
  }, [allEarnings])

  async function recordEarning() {
    if (!recordForm.user_id || !recordForm.amount) return
    setLoading(true)
    setMsg(null)
    const supabase = createClient()
    const weekStart = new Date(recordForm.week_start)
    const weekEnd = endOfWeek(weekStart, { weekStartsOn: 6 })

    const { error } = await supabase.from('weekly_earnings').upsert({
      user_id: recordForm.user_id,
      week_start: recordForm.week_start,
      week_end: format(weekEnd, 'yyyy-MM-dd'),
      amount_usd: Number(recordForm.amount),
      recorded_by: profile.id,
      notes: recordForm.notes || null,
    }, { onConflict: 'user_id,week_start' })

    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: 'Earnings recorded!' })
      setRecordForm(p => ({ ...p, amount: '', notes: '' }))
      setTimeout(() => window.location.reload(), 1200)
    }
    setLoading(false)
  }

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {[
          { id: 'me', label: 'My Earnings' },
          ...(isAdmin ? [
            { id: 'leaderboard', label: 'Leaderboard' },
            { id: 'groups', label: 'Group Rankings' },
            { id: 'record', label: 'Record Earnings' },
          ] : []),
        ].map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* My Earnings */}
      {tab === 'me' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            <div className="card p-4 bg-green-50">
              <div className="text-xs text-gray-500 mb-1">Total Earned (All Time)</div>
              <div className="text-2xl font-extrabold text-green-700">{formatCurrency(myTotal)}</div>
            </div>
            <div className="card p-4 bg-blue-50">
              <div className="text-xs text-gray-500 mb-1">Weeks with Earnings</div>
              <div className="text-2xl font-extrabold text-blue-700">{myEarnings.filter(e => e.amount_usd > 0).length}</div>
            </div>
            <div className="card p-4 bg-purple-50">
              <div className="text-xs text-gray-500 mb-1">Best Week</div>
              <div className="text-2xl font-extrabold text-purple-700">
                {myEarnings.length > 0 ? formatCurrency(Math.max(...myEarnings.map(e => Number(e.amount_usd)))) : '$0'}
              </div>
            </div>
          </div>

          <div className="card overflow-x-auto">
            <div className="p-4 border-b border-gray-100">
              <h2 className="section-title">Weekly Earnings History</h2>
            </div>
            {myEarnings.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="border-b border-gray-100">
                  <tr>
                    <th className="table-th">Week</th>
                    <th className="table-th">Amount</th>
                    <th className="table-th">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {myEarnings.map(e => (
                    <tr key={e.id} className="table-row">
                      <td className="table-td">{getWeekLabel(e.week_start)}</td>
                      <td className="table-td font-bold text-green-700">{formatCurrency(Number(e.amount_usd))}</td>
                      <td className="table-td text-gray-400 text-xs">{e.notes ?? '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}

      {/* Leaderboard */}
      {tab === 'leaderboard' && isAdmin && (
        <div className="space-y-4">
          <div className="flex gap-3 flex-wrap">
            <select className="input w-auto" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
              <option value="all">All Statuses</option>
              {['member','distributor','manager'].map(s => <option key={s} value={s}>{getStatusLabel(s as any)}</option>)}
            </select>
            <select className="input w-auto" value={groupFilter} onChange={e => setGroupFilter(e.target.value)}>
              <option value="all">All Groups</option>
              {colorGroups.map(g => <option key={g.code} value={g.code}>{g.name}</option>)}
            </select>
          </div>

          <div className="card overflow-x-auto">
            <div className="p-4 border-b border-gray-100">
              <h2 className="section-title">All-Time Earners Leaderboard</h2>
            </div>
            <table className="w-full text-sm">
              <thead className="border-b border-gray-100">
                <tr>
                  <th className="table-th">Rank</th>
                  <th className="table-th">Name</th>
                  <th className="table-th">ID</th>
                  <th className="table-th">Status</th>
                  <th className="table-th">Group</th>
                  <th className="table-th">Total Earned</th>
                </tr>
              </thead>
              <tbody>
                {leaderboard.map((p, i) => {
                  const isMe = p.id === profile.id
                  return (
                    <tr key={p.id} className={`table-row ${isMe ? 'bg-brand-50' : ''}`}>
                      <td className="table-td">
                        <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold ${i < 3 ? 'bg-yellow-100 text-yellow-700' : 'bg-gray-100 text-gray-500'}`}>
                          {i + 1}
                        </div>
                      </td>
                      <td className="table-td font-medium">{p.full_name} {isMe && <span className="text-brand-600 text-xs">(You)</span>}</td>
                      <td className="table-td text-gray-400">{p.member_id}</td>
                      <td className="table-td"><span className={`badge ${getStatusColor(p.status as any)}`}>{getStatusLabel(p.status as any)}</span></td>
                      <td className="table-td">
                        <div className="flex items-center gap-1.5">
                          <div className="w-3 h-3 rounded-full" style={{ backgroundColor: p.group_color }} />
                          {p.group_name}
                        </div>
                      </td>
                      <td className="table-td font-bold text-green-700">{formatCurrency(p.total)}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Group rankings */}
      {tab === 'groups' && isAdmin && (
        <div className="space-y-4">
          <div className="card p-5">
            <h2 className="section-title mb-4">Earnings by Color Group</h2>
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={groupTotals}>
                <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} tickFormatter={v => `$${v}`} />
                <Tooltip formatter={(v: number) => formatCurrency(v)} />
                <Bar dataKey="total" radius={[4,4,0,0]}>
                  {groupTotals.map((g, i) => <Cell key={i} fill={g.hex_color} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="card overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-gray-100">
                <tr>
                  <th className="table-th">Rank</th>
                  <th className="table-th">Group</th>
                  <th className="table-th">Total Earned</th>
                  <th className="table-th">Earners</th>
                </tr>
              </thead>
              <tbody>
                {groupTotals.map((g, i) => (
                  <tr key={g.name} className="table-row">
                    <td className="table-td font-bold text-gray-500">{i + 1}</td>
                    <td className="table-td">
                      <div className="flex items-center gap-2">
                        <div className="w-5 h-5 rounded-full" style={{ backgroundColor: g.hex_color }} />
                        <span className="font-medium">{g.name}</span>
                      </div>
                    </td>
                    <td className="table-td font-bold text-green-700">{formatCurrency(g.total)}</td>
                    <td className="table-td text-gray-500">{g.count}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Record earnings */}
      {tab === 'record' && isAdmin && (
        <div className="card p-6 max-w-lg">
          <h2 className="section-title mb-4">Record Weekly Earnings</h2>
          <div className="space-y-4">
            <div>
              <label className="label">Member *</label>
              <select className="input" value={recordForm.user_id} onChange={e => setRecordForm(p => ({ ...p, user_id: e.target.value }))}>
                <option value="">Select member…</option>
                {allProfiles.map(p => (
                  <option key={p.id} value={p.id}>{p.full_name} ({p.member_id})</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Week Starting (Saturday) *</label>
              <input
                className="input"
                type="date"
                value={recordForm.week_start}
                onChange={e => setRecordForm(p => ({ ...p, week_start: e.target.value }))}
              />
            </div>
            <div>
              <label className="label">Amount (USD) *</label>
              <input
                className="input"
                type="number"
                step="0.01"
                value={recordForm.amount}
                onChange={e => setRecordForm(p => ({ ...p, amount: e.target.value }))}
                placeholder="0.00"
              />
            </div>
            <div>
              <label className="label">Notes</label>
              <input
                className="input"
                value={recordForm.notes}
                onChange={e => setRecordForm(p => ({ ...p, notes: e.target.value }))}
                placeholder="Optional notes"
              />
            </div>

            {msg && (
              <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
                {msg.text}
              </div>
            )}

            <button onClick={recordEarning} disabled={loading} className="btn-primary w-full py-3">
              {loading ? 'Recording…' : 'Record Earnings'}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
