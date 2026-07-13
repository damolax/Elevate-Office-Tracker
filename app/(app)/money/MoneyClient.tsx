'use client'

import { useState, useMemo } from 'react'
import { format, startOfWeek, endOfWeek, parseISO, startOfMonth, endOfMonth } from 'date-fns'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ColorGroup, WeeklyEarning } from '@/lib/types'
import { formatCurrency, getStatusLabel, getStatusColor } from '@/lib/utils'
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Cell } from 'recharts'

type EarningView = 'weekly' | 'monthly'

export default function MoneyClient({
  profile, isAdmin, isEmOrBelow, myWeeklyEarnings, allEarnings, colorGroups, allProfiles,
}: {
  profile: Profile; isAdmin: boolean; isEmOrBelow: boolean
  myWeeklyEarnings: WeeklyEarning[]
  allEarnings: any[]; colorGroups: ColorGroup[]; allProfiles: any[]
}) {
  const [tab, setTab] = useState<'me' | 'leaderboard' | 'groups' | 'record'>('me')
  const [earningView, setEarningView] = useState<EarningView>('monthly')
  const [recordForm, setRecordForm] = useState({
    user_id: '', date: format(new Date(), 'yyyy-MM-dd'), amount: '', notes: '',
  })
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState(false)
  const [editingEntry, setEditingEntry] = useState<any | null>(null)
  const [statusFilter, setStatusFilter] = useState('all')
  const [groupFilter, setGroupFilter] = useState('all')
  const [monthFilter, setMonthFilter] = useState(format(new Date(), 'yyyy-MM'))

  // My monthly earnings aggregation
  const myMonthlyEarnings = useMemo(() => {
    const map = new Map<string, number>()
    for (const e of myWeeklyEarnings) {
      const monthStr = e.week_start.slice(0, 7)
      map.set(monthStr, (map.get(monthStr) ?? 0) + Number(e.amount_usd))
    }
    return Array.from(map.entries())
      .map(([month, total]) => ({ month, total, label: format(parseISO(month + '-01'), 'MMM yyyy') }))
      .sort((a, b) => b.month.localeCompare(a.month))
  }, [myWeeklyEarnings])

  const myTotal = myWeeklyEarnings.reduce((s, e) => s + Number(e.amount_usd), 0)
  const myThisMonth = myMonthlyEarnings.find(m => m.month === format(new Date(), 'yyyy-MM'))?.total ?? 0
  const myBestWeek = myWeeklyEarnings.length > 0 ? Math.max(...myWeeklyEarnings.map(e => Number(e.amount_usd))) : 0

  // Leaderboard — filtered by selected month
  const leaderboard = useMemo(() => {
    const filtered = allEarnings.filter(e => {
      const monthStr = e.week_start.slice(0, 7)
      return monthStr === monthFilter
    })
    const map = new Map<string, { id: string; full_name: string; member_id: string; status: string; group_name: string; group_color: string; total: number }>()
    for (const e of filtered) {
      const p = e.profiles
      if (!p) continue
      if (statusFilter !== 'all' && p.status !== statusFilter) continue
      if (groupFilter !== 'all' && p.color_groups?.code !== groupFilter) continue
      const ex = map.get(p.id) ?? {
        id: p.id, full_name: p.full_name, member_id: p.member_id, status: p.status,
        group_name: p.color_groups?.name ?? '—', group_color: p.color_groups?.hex_color ?? '#ccc', total: 0,
      }
      ex.total += Number(e.amount_usd)
      map.set(p.id, ex)
    }
    return Array.from(map.values()).sort((a, b) => b.total - a.total)
  }, [allEarnings, monthFilter, statusFilter, groupFilter])

  // Group totals for selected month
  const groupTotals = useMemo(() => {
    const filtered = allEarnings.filter(e => e.week_start.slice(0, 7) === monthFilter)
    const map = new Map<string, { name: string; hex_color: string; total: number; count: number }>()
    for (const e of filtered) {
      const g = e.profiles?.color_groups
      if (!g) continue
      const ex = map.get(g.name) ?? { name: g.name, hex_color: g.hex_color, total: 0, count: 0 }
      ex.total += Number(e.amount_usd)
      ex.count++
      map.set(g.name, ex)
    }
    return Array.from(map.values()).sort((a, b) => b.total - a.total)
  }, [allEarnings, monthFilter])

  // Available months for filter
  const availableMonths = useMemo(() => {
    const months = new Set<string>()
    allEarnings.forEach(e => months.add(e.week_start.slice(0, 7)))
    return Array.from(months).sort().reverse()
  }, [allEarnings])

  // Most recent individual earning entries — used for the editable list
  const recentEntries = useMemo(() => {
    return [...allEarnings]
      .sort((a, b) => b.week_start.localeCompare(a.week_start))
      .slice(0, 30)
  }, [allEarnings])

  function startEdit(entry: any) {
    setEditingEntry(entry)
    setRecordForm({
      user_id: entry.user_id,
      date: entry.week_start,
      amount: String(entry.amount_usd),
      notes: entry.notes ?? '',
    })
    setTab('record')
  }

  async function recordEarning() {
    if (!recordForm.user_id || !recordForm.amount || !recordForm.date) return
    setLoading(true); setMsg(null)
    const supabase = createClient()
    // Determine week bounds from the selected date
    const selectedDate = new Date(recordForm.date)
    const weekStart = startOfWeek(selectedDate, { weekStartsOn: 6 })
    const weekEnd = endOfWeek(selectedDate, { weekStartsOn: 6 })

    const { error } = await supabase.from('weekly_earnings').upsert({
      user_id: recordForm.user_id,
      week_start: format(weekStart, 'yyyy-MM-dd'),
      week_end: format(weekEnd, 'yyyy-MM-dd'),
      amount_usd: Number(recordForm.amount),
      recorded_by: profile.id,
      notes: recordForm.notes || null,
    }, { onConflict: 'user_id,week_start' })

    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: `${editingEntry ? 'Earnings updated' : 'Earnings recorded'} for ${format(weekStart, 'MMM d')} – ${format(weekEnd, 'MMM d, yyyy')}` })
      setRecordForm(p => ({ ...p, amount: '', notes: '' }))
      setEditingEntry(null)
      setTimeout(() => window.location.reload(), 1200)
    }
    setLoading(false)
  }

  const monthLabel = (m: string) => format(parseISO(m + '-01'), 'MMMM yyyy')

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {[
          { id: 'me', label: 'My Earnings' },
          ...(isAdmin ? [
            { id: 'leaderboard', label: 'Top Earners' },
            { id: 'groups', label: 'Group Rankings' },
            { id: 'record', label: 'Record Earnings' },
          ] : []),
        ].map(t => (
          <button key={t.id} onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* ── MY EARNINGS ── */}
      {tab === 'me' && (
        <div className="space-y-4">
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            <div className="card p-4 bg-green-50">
              <div className="text-xs text-gray-500 mb-1">This Month</div>
              <div className="text-2xl font-extrabold text-green-700">{formatCurrency(myThisMonth)}</div>
            </div>
            <div className="card p-4 bg-blue-50">
              <div className="text-xs text-gray-500 mb-1">All Time Total</div>
              <div className="text-2xl font-extrabold text-blue-700">{formatCurrency(myTotal)}</div>
            </div>
            <div className="card p-4 bg-purple-50">
              <div className="text-xs text-gray-500 mb-1">Best Single Week</div>
              <div className="text-2xl font-extrabold text-purple-700">{formatCurrency(myBestWeek)}</div>
            </div>
          </div>

          {/* View toggle */}
          <div className="flex gap-2">
            {(['monthly', 'weekly'] as EarningView[]).map(v => (
              <button key={v} onClick={() => setEarningView(v)}
                className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-all border ${earningView === v ? 'bg-brand-600 text-white border-brand-600' : 'bg-white text-gray-500 border-gray-200 hover:border-gray-300'}`}>
                {v === 'monthly' ? 'Monthly View' : 'Weekly View'}
              </button>
            ))}
          </div>

          {earningView === 'monthly' ? (
            <div className="card overflow-x-auto">
              <div className="p-4 border-b border-gray-100"><h2 className="section-title">Monthly Earnings</h2></div>
              {myMonthlyEarnings.length === 0 ? (
                <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
              ) : (
                <>
                  <div className="p-4">
                    <ResponsiveContainer width="100%" height={200}>
                      <BarChart data={[...myMonthlyEarnings].reverse()}>
                        <XAxis dataKey="label" tick={{ fontSize: 11 }} />
                        <YAxis tick={{ fontSize: 11 }} tickFormatter={v => `$${v}`} />
                        <Tooltip formatter={(v: number) => formatCurrency(v)} />
                        <Bar dataKey="total" fill="#4f46e5" radius={[4,4,0,0]} />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                  <table className="w-full text-sm">
                    <thead className="border-t border-gray-100"><tr>
                      <th className="table-th">Month</th>
                      <th className="table-th">Total Earned</th>
                    </tr></thead>
                    <tbody>
                      {myMonthlyEarnings.map(m => (
                        <tr key={m.month} className={`table-row ${m.month === format(new Date(), 'yyyy-MM') ? 'bg-green-50' : ''}`}>
                          <td className="table-td font-medium">{m.label}</td>
                          <td className="table-td font-bold text-green-700">{formatCurrency(m.total)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </>
              )}
            </div>
          ) : (
            <div className="card overflow-x-auto">
              <div className="p-4 border-b border-gray-100"><h2 className="section-title">Weekly Earnings History</h2></div>
              {myWeeklyEarnings.length === 0 ? (
                <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
              ) : (
                <table className="w-full text-sm">
                  <thead className="border-b border-gray-100"><tr>
                    <th className="table-th">Week</th>
                    <th className="table-th">Amount</th>
                    <th className="table-th">Notes</th>
                  </tr></thead>
                  <tbody>
                    {myWeeklyEarnings.map(e => (
                      <tr key={e.id} className="table-row">
                        <td className="table-td">{format(parseISO(e.week_start), 'MMM d')} – {format(parseISO(e.week_end ?? e.week_start), 'MMM d, yyyy')}</td>
                        <td className="table-td font-bold text-green-700">{formatCurrency(Number(e.amount_usd))}</td>
                        <td className="table-td text-gray-400 text-xs">{e.notes ?? '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          )}
        </div>
      )}

      {/* ── TOP EARNERS ── */}
      {tab === 'leaderboard' && isAdmin && (
        <div className="space-y-4">
          <div className="flex gap-3 flex-wrap items-center">
            <select className="input w-auto" value={monthFilter} onChange={e => setMonthFilter(e.target.value)}>
              {availableMonths.length === 0
                ? <option value={format(new Date(), 'yyyy-MM')}>{monthLabel(format(new Date(), 'yyyy-MM'))}</option>
                : availableMonths.map(m => <option key={m} value={m}>{monthLabel(m)}</option>)
              }
            </select>
            <select className="input w-auto" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
              <option value="all">All Statuses</option>
              {['member','distributor','manager','executive_manager'].map(s => (
                <option key={s} value={s}>{getStatusLabel(s as any)}</option>
              ))}
            </select>
            <select className="input w-auto" value={groupFilter} onChange={e => setGroupFilter(e.target.value)}>
              <option value="all">All Groups</option>
              {colorGroups.map(g => <option key={g.code} value={g.code}>{g.name}</option>)}
            </select>
          </div>

          <div className="card p-4 bg-brand-50 border-brand-200">
            <div className="text-xs text-brand-600 font-semibold">Top Earners — {monthLabel(monthFilter)}</div>
            <div className="text-xs text-brand-400 mt-0.5">Executive Manager and below only</div>
          </div>

          <div className="card overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-gray-100"><tr>
                <th className="table-th">Rank</th>
                <th className="table-th">Name</th>
                <th className="table-th">ID</th>
                <th className="table-th">Status</th>
                <th className="table-th">Group</th>
                <th className="table-th">Earned This Month</th>
              </tr></thead>
              <tbody>
                {leaderboard.length === 0 ? (
                  <tr><td colSpan={6} className="table-td text-center text-gray-400 py-8">No earnings recorded for {monthLabel(monthFilter)}</td></tr>
                ) : leaderboard.map((p, i) => (
                  <tr key={p.id} className={`table-row ${p.id === profile.id ? 'bg-brand-50' : ''}`}>
                    <td className="table-td">
                      <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold ${i < 3 ? 'bg-yellow-100 text-yellow-700' : 'bg-gray-100 text-gray-500'}`}>{i + 1}</div>
                    </td>
                    <td className="table-td font-medium">{p.full_name} {p.id === profile.id && <span className="text-brand-600 text-xs">(You)</span>}</td>
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
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ── GROUP RANKINGS ── */}
      {tab === 'groups' && isAdmin && (
        <div className="space-y-4">
          <div className="flex gap-3">
            <select className="input w-auto" value={monthFilter} onChange={e => setMonthFilter(e.target.value)}>
              {availableMonths.length === 0
                ? <option value={format(new Date(), 'yyyy-MM')}>{monthLabel(format(new Date(), 'yyyy-MM'))}</option>
                : availableMonths.map(m => <option key={m} value={m}>{monthLabel(m)}</option>)
              }
            </select>
          </div>

          {groupTotals.length > 0 && (
            <div className="card p-5">
              <h2 className="section-title mb-4">Group Earnings — {monthLabel(monthFilter)}</h2>
              <ResponsiveContainer width="100%" height={240}>
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
          )}

          <div className="card overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-gray-100"><tr>
                <th className="table-th">Rank</th>
                <th className="table-th">Group</th>
                <th className="table-th">Total Earned</th>
                <th className="table-th">Earners</th>
              </tr></thead>
              <tbody>
                {groupTotals.length === 0 ? (
                  <tr><td colSpan={4} className="table-td text-center text-gray-400 py-8">No data for {monthLabel(monthFilter)}</td></tr>
                ) : groupTotals.map((g, i) => (
                  <tr key={g.name} className="table-row">
                    <td className="table-td font-bold text-gray-500">{i + 1}</td>
                    <td className="table-td">
                      <div className="flex items-center gap-2">
                        <div className="w-4 h-4 rounded-full" style={{ backgroundColor: g.hex_color }} />
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

      {/* ── RECORD EARNINGS ── */}
      {tab === 'record' && isAdmin && (
        <div className="space-y-6">
          <div className="card p-6 max-w-lg">
            <div className="flex items-center justify-between mb-1">
              <h2 className="section-title">{editingEntry ? 'Edit Earnings Entry' : 'Record Earnings'}</h2>
              {editingEntry && (
                <button onClick={() => { setEditingEntry(null); setRecordForm({ user_id: '', date: format(new Date(), 'yyyy-MM-dd'), amount: '', notes: '' }) }}
                  className="text-xs text-gray-400 hover:text-gray-600">Cancel Edit</button>
              )}
            </div>
            <p className="text-sm text-gray-500 mb-4">
              {editingEntry
                ? 'Editing an existing entry — saving will overwrite the amount/notes for this person\'s week.'
                : 'Select the member and the date the earnings were made. The app will automatically assign it to the correct week and month.'}
            </p>
            <div className="space-y-4">
              <div>
                <label className="label">Member *</label>
                <select className="input" value={recordForm.user_id} disabled={!!editingEntry} onChange={e => setRecordForm(p => ({ ...p, user_id: e.target.value }))}>
                  <option value="">Select member…</option>
                  {allProfiles.map((p: any) => (
                    <option key={p.id} value={p.id}>{p.full_name} ({p.member_id ?? 'No ID'})</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="label">Date Earned *</label>
                <input className="input" type="date" value={recordForm.date} disabled={!!editingEntry}
                  onChange={e => setRecordForm(p => ({ ...p, date: e.target.value }))} />
                {recordForm.date && (
                  <p className="text-xs text-gray-400 mt-1">
                    This will be recorded under: <strong>{format(startOfWeek(new Date(recordForm.date), { weekStartsOn: 6 }), 'MMM d')} – {format(endOfWeek(new Date(recordForm.date), { weekStartsOn: 6 }), 'MMM d, yyyy')}</strong>
                    {' '} · Month: <strong>{format(new Date(recordForm.date), 'MMMM yyyy')}</strong>
                  </p>
                )}
              </div>

              <div>
                <label className="label">Amount (USD) *</label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 font-medium">$</span>
                  <input className="input pl-7" type="number" step="0.01" min="0"
                    value={recordForm.amount} onChange={e => setRecordForm(p => ({ ...p, amount: e.target.value }))}
                    placeholder="0.00" />
                </div>
              </div>

              <div>
                <label className="label">Notes (optional)</label>
                <input className="input" value={recordForm.notes}
                  onChange={e => setRecordForm(p => ({ ...p, notes: e.target.value }))}
                  placeholder="e.g. Fiverr order, client payment…" />
              </div>

              {msg && (
                <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
                  {msg.text}
                </div>
              )}

              <button onClick={recordEarning} disabled={loading || !recordForm.user_id || !recordForm.amount || !recordForm.date}
                className="btn-primary w-full py-3">
                {loading ? (editingEntry ? 'Updating…' : 'Recording…') : (editingEntry ? 'Update Earnings' : 'Record Earnings')}
              </button>
            </div>
          </div>

          {/* Recent entries — click Edit to adjust amount/notes on any past entry */}
          <div className="card overflow-x-auto max-w-3xl">
            <div className="p-4 border-b border-gray-100"><h2 className="section-title">Recent Entries</h2></div>
            {recentEntries.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No earnings recorded yet</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="border-b border-gray-100"><tr>
                  <th className="table-th">Person</th>
                  <th className="table-th">Week</th>
                  <th className="table-th">Amount</th>
                  <th className="table-th"></th>
                </tr></thead>
                <tbody>
                  {recentEntries.map((e: any) => (
                    <tr key={e.id ?? `${e.user_id}-${e.week_start}`} className="table-row">
                      <td className="table-td font-medium">{e.profiles?.full_name ?? '—'}</td>
                      <td className="table-td text-gray-400">{format(parseISO(e.week_start), 'MMM d')} – {format(parseISO(e.week_end ?? e.week_start), 'MMM d, yyyy')}</td>
                      <td className="table-td font-bold text-green-700">{formatCurrency(Number(e.amount_usd))}</td>
                      <td className="table-td text-right">
                        <button onClick={() => startEdit(e)} className="text-xs font-semibold text-brand-600 hover:text-brand-700">Edit</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
