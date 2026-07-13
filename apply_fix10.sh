#!/usr/bin/env bash
set -e
echo "Writing updated files..."

mkdir -p "app/(app)/community"
cat > "app/(app)/community/CommunityClient.tsx" << 'CLAUDE_EOF_MARKER'
import { isOnline, lastSeenLabel } from '@/lib/useLastSeen'
'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, CommunityPost } from '@/lib/types'
import { getStatusLabel } from '@/lib/utils'
import { Send, Trash2 } from 'lucide-react'
import { format, parseISO } from 'date-fns'

export default function CommunityClient({
  profile, initialPosts, isAdmin,
}: {
  profile: Profile
  initialPosts: CommunityPost[]
  isAdmin: boolean
}) {
  const [posts, setPosts] = useState<CommunityPost[]>(initialPosts)
  const [content, setContent] = useState('')
  const [posting, setPosting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [connected, setConnected] = useState(false)
  const bottomRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  const scrollToBottom = useCallback((smooth = true) => {
    bottomRef.current?.scrollIntoView({ behavior: smooth ? 'smooth' : 'auto' })
  }, [])

  useEffect(() => {
    // Scroll to bottom on initial load
    scrollToBottom(false)
  }, [])

  useEffect(() => {
    const supabase = createClient()

    const channel = supabase
      .channel('community-realtime')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'community_posts',
      }, async (payload) => {
        // Skip if this is our own post — we already added it optimistically
        if (payload.new.user_id === profile.id) return

        // Fetch the full post with profile data
        const { data } = await supabase
          .from('community_posts')
          .select('*, profiles(id, full_name, member_id, profile_picture, status, last_seen, color_groups!profiles_color_group_id_fkey(name, hex_color))')
          .eq('id', payload.new.id)
          .single()

        if (data) {
          setPosts(prev => {
            // Avoid duplicates
            if (prev.find(p => p.id === data.id)) return prev
            return [data as CommunityPost, ...prev]
          })
          setTimeout(() => scrollToBottom(), 100)
        }
      })
      .on('postgres_changes', {
        event: 'DELETE',
        schema: 'public',
        table: 'community_posts',
      }, (payload) => {
        setPosts(prev => prev.filter(p => p.id !== payload.old.id))
      })
      .subscribe((status) => {
        setConnected(status === 'SUBSCRIBED')
      })

    return () => { supabase.removeChannel(channel) }
  }, [profile.id, scrollToBottom])

  async function post() {
    if (!content.trim() || posting) return
    const text = content.trim()
    setContent('')
    setPosting(true)
    setError(null)

    // Optimistic update — add post immediately to UI
    const tempId = `temp-${Date.now()}`
    const optimisticPost: CommunityPost = {
      id: tempId,
      user_id: profile.id,
      content: text,
      attachment_url: null,
      attachment_type: null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      profiles: {
        id: profile.id,
        full_name: profile.full_name,
        member_id: profile.member_id,
        profile_picture: profile.profile_picture,
        status: profile.status,
      } as any,
    }
    setPosts(prev => [optimisticPost, ...prev])
    setTimeout(() => scrollToBottom(), 100)

    const supabase = createClient()
    const { data, error: insertError } = await supabase
      .from('community_posts')
      .insert({ user_id: profile.id, content: text })
      .select('*, profiles(id, full_name, member_id, profile_picture, status, color_groups!profiles_color_group_id_fkey(name, hex_color))')
      .single()

    if (insertError) {
      // Remove optimistic post on error
      setPosts(prev => prev.filter(p => p.id !== tempId))
      setContent(text)
      setError(insertError.message)
    } else if (data) {
      // Replace optimistic post with real data
      setPosts(prev => prev.map(p => p.id === tempId ? data as CommunityPost : p))
      supabase.from('activity_events').insert({
        type: 'community_post', actor_id: profile.id,
        message: `${profile.full_name} posted in Community`,
      })
    }

    setPosting(false)
    textareaRef.current?.focus()
  }

  async function deletePost(id: string) {
    // Optimistic remove
    setPosts(prev => prev.filter(p => p.id !== id))
    const supabase = createClient()
    const { error: delError } = await supabase.from('community_posts').delete().eq('id', id)
    if (delError) {
      // Restore post list on error
      setError(delError.message)
      window.location.reload()
    }
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      post()
    }
  }

  return (
    <div className="flex flex-col h-[calc(100vh-120px)] max-w-3xl mx-auto">
      {/* Header */}
      <div className="card p-4 mb-4 flex-shrink-0 flex items-center justify-between">
        <div>
          <h2 className="font-bold text-gray-900">Team Community</h2>
          <p className="text-xs text-gray-400">Share updates, ask questions, celebrate wins</p>
        </div>
        <div className={`flex items-center gap-1.5 text-xs font-medium ${connected ? 'text-green-600' : 'text-gray-400'}`}>
          <div className={`w-2 h-2 rounded-full ${connected ? 'bg-green-500' : 'bg-gray-300'}`} />
          {connected ? 'Live' : 'Connecting…'}
        </div>
      </div>

      {/* Posts feed */}
      <div className="flex-1 overflow-y-auto space-y-3 pr-1 flex flex-col-reverse">
        <div ref={bottomRef} />
        {posts.length === 0 && (
          <p className="text-sm text-gray-400 text-center py-12">No posts yet — be the first to share!</p>
        )}
        {posts.map(postItem => {
          const p = (postItem as any).profiles
          const isMyPost = postItem.user_id === profile.id
          const canDelete = isMyPost || isAdmin
          const isTemp = postItem.id.startsWith('temp-')

          return (
            <div key={postItem.id} className={`card p-4 transition-opacity ${isTemp ? 'opacity-70' : 'opacity-100'}`}>
              <div className="flex items-start gap-3">
                <div className="w-9 h-9 rounded-full flex-shrink-0 overflow-hidden">
                  {p?.profile_picture ? (
                    <img src={p.profile_picture} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-white text-sm font-bold"
                      style={{ backgroundColor: p?.color_groups?.hex_color ?? '#4f46e5' }}>
                      {p?.full_name?.slice(0, 1) ?? '?'}
                    </div>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1 flex-wrap">
                    <span className="font-semibold text-sm text-gray-900">{p?.full_name ?? 'Unknown'}</span>
                    {p?.member_id && <span className="text-xs text-gray-400">{p.member_id}</span>}
                    {p?.status && (
                      <span className="text-xs bg-gray-100 text-gray-500 px-1.5 py-0.5 rounded">
                        {getStatusLabel(p.status)}
                      </span>
                    )}
                    {p?.color_groups && (
                      <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: p.color_groups.hex_color }} />
                    )}
                    {isMyPost && <span className="text-xs text-brand-500 font-medium">You</span>}
                  </div>
                  <p className="text-sm text-gray-700 whitespace-pre-wrap break-words leading-relaxed">{postItem.content}</p>
                  <div className="text-xs text-gray-400 mt-1.5">
                    {isTemp ? 'Sending…' : format(parseISO(postItem.created_at), 'MMM d, h:mm a')}
                  </div>
                </div>
                {canDelete && !isTemp && (
                  <button onClick={() => deletePost(postItem.id)}
                    className="p-1.5 rounded-lg text-gray-300 hover:text-red-500 hover:bg-red-50 transition-colors flex-shrink-0">
                    <Trash2 size={14} />
                  </button>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {/* Compose */}
      <div className="card p-4 mt-4 flex-shrink-0">
        {error && <p className="text-sm text-red-600 mb-2">{error}</p>}
        <div className="flex gap-3 items-end">
          <div className="w-8 h-8 rounded-full flex-shrink-0 overflow-hidden">
            {profile.profile_picture ? (
              <img src={profile.profile_picture} alt="" className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-white text-sm font-bold"
                style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}>
                {profile.full_name.slice(0, 1)}
              </div>
            )}
          </div>
          <div className="flex-1">
            <textarea
              ref={textareaRef}
              className="input resize-none"
              rows={3}
              placeholder="Share an update, ask a question, or celebrate a win…"
              value={content}
              onChange={e => setContent(e.target.value)}
              onKeyDown={handleKeyDown}
            />
          </div>
          <button onClick={post} disabled={posting || !content.trim()} className="btn-primary p-3 flex-shrink-0">
            <Send size={16} />
          </button>
        </div>
        <p className="text-xs text-gray-400 mt-1.5">Press Enter to post · Shift+Enter for new line</p>
      </div>
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/money"
cat > "app/(app)/money/MoneyClient.tsx" << 'CLAUDE_EOF_MARKER'
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
      if (!editingEntry) {
        const person = allProfiles.find((p: any) => p.id === recordForm.user_id)
        supabase.from('activity_events').insert({
          type: 'earning', actor_id: recordForm.user_id,
          message: `${person?.full_name ?? 'Someone'} recorded ${formatCurrency(Number(recordForm.amount))} in earnings`,
        })
      }
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
CLAUDE_EOF_MARKER

mkdir -p "app/(app)/people"
cat > "app/(app)/people/PeopleClient.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ColorGroup, ActivityStatus } from '@/lib/types'
import { getStatusLabel, getStatusColor, formatDate } from '@/lib/utils'
import { ACTIVITY_STATUS_LABELS, ACTIVITY_STATUS_COLORS, statusRank, isSmOrAbove } from '@/lib/types'
import { Check, X, Search, ChevronDown, ChevronRight, Shield, UserX, UserCheck, Eye } from 'lucide-react'

const ACTIVITY_OPTIONS: ActivityStatus[] = [
  'active', 'suspended', 'inactive', 'left_office', 'another_location', 'moved_to_another_office'
]

export default function PeopleClient({
  currentProfile, allProfiles, pendingProfiles, colorGroups, isMainAdmin, mainAdminId,
}: {
  currentProfile: Profile
  allProfiles: Profile[]
  pendingProfiles: Profile[]
  colorGroups: ColorGroup[]
  isMainAdmin: boolean
  mainAdminId: string | null
}) {
  const [tab, setTab] = useState<'active' | 'pending' | 'inactive' | 'tree' | 'add'>('active')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [loading, setLoading] = useState<string | null>(null)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [selectedProfile, setSelectedProfile] = useState<Profile | null>(null)
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  const [confirmAction, setConfirmAction] = useState<{ type: 'approve' | 'reject' | 'delete'; profile: Profile } | null>(null)
  const [rejectReason, setRejectReason] = useState('')
  const [deleteConfirmName, setDeleteConfirmName] = useState('')
  const [addForm, setAddForm] = useState({
    full_name: '', email: '', phone: '', status: 'member',
    color_group_id: '', sponsor_id: '', week_number: 1,
  })
  const [addLoading, setAddLoading] = useState(false)
  const isDirector = currentProfile.is_director && !isMainAdmin
  const isCoAdmin = currentProfile.is_co_admin && !isMainAdmin && !currentProfile.is_director

  // A co-admin's own downline (used for the "can view upline only if it's my downline" rule)
  function getDownlineIds(rootId: string): string[] {
    const direct = allProfiles.filter(p => p.sponsor_id === rootId).map(p => p.id)
    return [...direct, ...direct.flatMap(id => getDownlineIds(id))]
  }
  const myDownlineIds = isCoAdmin ? getDownlineIds(currentProfile.id) : []

  // The one co-admin this person (if Director/Co-Admin, not main admin) has personally assigned
  const myAssignedCoAdmin = allProfiles.find(p => p.co_admin_assigned_by === currentProfile.id && p.is_co_admin)

  // Hide main admin from everyone but main admin; hide Directors from Co-Admins.
  // Co-Admins additionally cannot view anyone ABOVE them in status rank unless
  // that person is in their own downline — but can always view anyone at or
  // below their rank, downline or not.
  const visibleProfiles = allProfiles.filter(p => {
    if (!isMainAdmin && p.id === mainAdminId) return false
    if (isCoAdmin && p.is_director) return false
    if (isCoAdmin && statusRank(p.status) > statusRank(currentProfile.status) && !myDownlineIds.includes(p.id)) return false
    return true
  })

  // Active vs inactive split
  const activeProfiles = visibleProfiles.filter(p => p.approved && !p.rejected && p.activity_status === 'active')
  const inactiveProfiles = visibleProfiles.filter(p => p.approved && !p.rejected && p.activity_status !== 'active')
  const rejectedProfiles = visibleProfiles.filter(p => p.rejected)

  // "Senior-manager tier" for the one-person-per-color rule: Senior Manager and
  // above on the status ladder, OR anyone with Admin/Director/Co-Admin
  // permission flags — including the main Admin, who can now be assigned a
  // color group too, subject to the exact same one-per-color rule as anyone else.
  function isColorLeaderTier(p: Profile): boolean {
    return isSmOrAbove(p.status) || p.is_admin || p.is_director || p.is_co_admin
  }

  // Color group → senior manager (or admin-tier) check
  function getSeniorManagerInColor(colorGroupId: string, excludeId?: string): Profile | null {
    return visibleProfiles.find(p =>
      p.color_group_id === colorGroupId &&
      isColorLeaderTier(p) &&
      p.approved &&
      p.id !== excludeId
    ) || null
  }

  // Downline builder
  function getDownline(rootId: string, profiles: Profile[]): string[] {
    const direct = profiles.filter(p => p.sponsor_id === rootId).map(p => p.id)
    return [...direct, ...direct.flatMap(id => getDownline(id, profiles))]
  }

  // Can this admin delete this person?
  function canDelete(target: Profile): boolean {
    if (isMainAdmin) return true
    if (target.rejected) return true // anyone can delete rejected
    if (isCoAdmin && target.added_by === currentProfile.id) return true
    if (isDirector && !target.approved) return true
    return false
  }

  // Can override sponsor/color?
  const canOverride = isMainAdmin || isDirector

  // ── ACTIONS ────────────────────────────────────────────────────────────────

  async function confirmApprove(p: Profile) {
    setLoading(p.id)
    setMsg(null)
    const supabase = createClient()
    const colorGroup = colorGroups.find(g => g.id === p.color_group_id)
    let memberId = null
    if (colorGroup) {
      const { data: seqData } = await supabase.rpc('generate_member_id', { p_color_code: colorGroup.code })
      memberId = seqData
      await supabase.from('color_groups').update({ member_count: colorGroup.member_count + 1 }).eq('id', colorGroup.id)
    }
    const { error } = await supabase.from('profiles')
      .update({ approved: true, rejected: false, member_id: memberId, added_by: currentProfile.id })
      .eq('id', p.id)
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: `✓ Approved! Member ID: ${memberId ?? 'N/A'}` })
      // Notify the new member
      await supabase.from('notifications').insert({
        user_id: p.id,
        title: 'Application Approved!',
        body: `Welcome to Elevate! Your member ID is ${memberId ?? 'assigned'}. You can now access all features.`,
        type: 'success',
        link: '/dashboard',
      })
      // Let everyone know a new person just joined
      await supabase.from('activity_events').insert({
        type: 'new_member', actor_id: p.id,
        message: `${p.full_name} just joined the team!`,
      })
      setTimeout(() => window.location.reload(), 1500)
    }
    setConfirmAction(null)
    setLoading(null)
  }

  async function confirmReject(p: Profile) {
    setLoading(p.id)
    const supabase = createClient()
    await supabase.from('profiles').update({ rejected: true, rejection_reason: rejectReason || null }).eq('id', p.id)
    // Notify the rejected person
    await supabase.from('notifications').insert({
      user_id: p.id,
      title: 'Application Status Update',
      body: rejectReason ? `Your application was not approved: ${rejectReason}` : 'Your application was not approved at this time.',
      type: 'error',
    })
    setMsg({ type: 'success', text: `${p.full_name} rejected.` })
    setConfirmAction(null)
    setRejectReason('')
    setTimeout(() => window.location.reload(), 1200)
    setLoading(null)
  }

  async function confirmDelete(p: Profile) {
    // Main admin requires name confirmation
    if (isMainAdmin && deleteConfirmName.trim().toLowerCase() !== p.full_name.toLowerCase()) {
      setMsg({ type: 'error', text: 'Name does not match. Type the exact name to confirm.' })
      return
    }
    setLoading(p.id)
    const supabase = createClient()
    const { error } = await supabase.from('profiles').delete().eq('id', p.id)
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: `${p.full_name} deleted.` })
      setConfirmAction(null)
      setDeleteConfirmName('')
      setTimeout(() => window.location.reload(), 1000)
    }
    setLoading(null)
  }

  async function updateProfile(profileId: string, updates: Record<string, unknown>) {
    const supabase = createClient()
    const { error } = await supabase.from('profiles').update(updates).eq('id', profileId)
    if (error) { setMsg({ type: 'error', text: error.message }); return }
    setMsg({ type: 'success', text: 'Updated!' })
    if (selectedProfile?.id === profileId) {
      setSelectedProfile(prev => prev ? { ...prev, ...updates } as Profile : null)
    }
    setTimeout(() => window.location.reload(), 800)
  }

  async function assignColor(profileId: string, colorGroupId: string, targetProfile: Profile) {
    // Enforce: no two senior-manager-tier people (Senior Manager+, or Admin/
    // Director/Co-Admin) can share the same color group — including the
    // main Admin assigning a color to themselves.
    if (isColorLeaderTier(targetProfile)) {
      const existing = getSeniorManagerInColor(colorGroupId, profileId)
      if (existing) {
        setMsg({ type: 'error', text: `${existing.full_name} already leads this color group. Two Senior-Manager-tier people (including Admins/Directors/Co-Admins) cannot share a color.` })
        return
      }
    }

    const colorGroup = colorGroups.find(g => g.id === colorGroupId)

    // If this person has no member ID yet, auto-generate the next one for this
    // color (e.g. selecting Red for someone with no ID yet -> RED050 if RED049 was last)
    if (!targetProfile.member_id && colorGroup) {
      const supabase = createClient()
      const { data: newId, error: idError } = await supabase.rpc('generate_member_id', {
        p_color_code: colorGroup.code,
      })
      if (idError) {
        setMsg({ type: 'error', text: `Could not generate member ID: ${idError.message}` })
        return
      }
      await updateProfile(profileId, { color_group_id: colorGroupId, member_id: newId })
      return
    }

    await updateProfile(profileId, { color_group_id: colorGroupId })
  }

  async function toggleCoAdmin(profileId: string, current: boolean) {
    if (!isMainAdmin && !isDirector && !isCoAdmin) return

    if (!isMainAdmin) {
      // Directors and Co-Admins may each assign exactly ONE co-admin of their own
      if (!current) {
        if (myAssignedCoAdmin) {
          setMsg({ type: 'error', text: `You can only assign one Co-Admin. You already made ${myAssignedCoAdmin.full_name} a Co-Admin — remove them first if you want to choose someone else.` })
          return
        }
      } else {
        const target = allProfiles.find(p => p.id === profileId)
        if (target?.co_admin_assigned_by !== currentProfile.id) {
          setMsg({ type: 'error', text: 'You can only remove a Co-Admin that you personally assigned.' })
          return
        }
      }
    }

    await updateProfile(profileId, {
      is_co_admin: !current,
      co_admin_assigned_by: !current ? currentProfile.id : null,
    })
    // Notify the person
    const supabase = createClient()
    await supabase.from('notifications').insert({
      user_id: profileId,
      title: !current ? 'Co-Admin Access Granted' : 'Co-Admin Access Removed',
      body: !current
        ? 'You have been granted co-admin access. You can now approve new members.'
        : 'Your co-admin access has been removed.',
      type: !current ? 'success' : 'info',
    })
  }

  async function setActivityStatus(profileId: string, status: ActivityStatus) {
    await updateProfile(profileId, { activity_status: status })
  }

  async function addMemberManually() {
    setAddLoading(true)
    setMsg(null)
    const tempPassword = `Elevate${Math.random().toString(36).slice(2, 8).toUpperCase()}!`
    const res = await fetch('/api/admin/create-user', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...addForm, temp_password: tempPassword, added_by: currentProfile.id }),
    })
    const result = await res.json()
    if (!res.ok) setMsg({ type: 'error', text: result.error ?? 'Failed' })
    else { setMsg({ type: 'success', text: `Created! Temp password: ${tempPassword}` }); setTab('active'); setTimeout(() => window.location.reload(), 2000) }
    setAddLoading(false)
  }

  // ── PROFILE CARD ──────────────────────────────────────────────────────────

  function ProfileCard({ p }: { p: Profile }) {
    const colorGroup = colorGroups.find(g => g.id === p.color_group_id)
    const sponsor = allProfiles.find(s => s.id === p.sponsor_id)
    const actStatus = (p.activity_status || 'active') as ActivityStatus

    return (
      <div className="card p-5 space-y-4">
        <div className="flex items-start justify-between gap-3">
          <div className="flex items-center gap-3">
            {p.profile_picture
              ? <img src={p.profile_picture} className="w-12 h-12 rounded-full object-cover" />
              : <div className="w-12 h-12 rounded-full flex items-center justify-center font-bold text-lg text-white" style={{ backgroundColor: colorGroup?.hex_color ?? '#6366f1' }}>{p.full_name.charAt(0)}</div>
            }
            <div>
              <button className="font-bold text-gray-900 hover:text-brand-600 hover:underline text-left" onClick={() => window.open(`/member/${p.id}`, '_blank')}>
                {p.full_name}
              </button>
              <div className="text-sm text-gray-400">{p.member_id ?? 'No ID'} · {p.email}</div>
              <div className="flex gap-1.5 mt-1 flex-wrap">
                <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                <span className={`badge ${ACTIVITY_STATUS_COLORS[actStatus]}`}>{ACTIVITY_STATUS_LABELS[actStatus]}</span>
                {p.is_co_admin && <span className="badge bg-purple-100 text-purple-700">Co-Admin</span>}
              </div>
            </div>
          </div>
          <div className="flex gap-2">
            {isMainAdmin && p.id !== currentProfile.id && (
              <button onClick={async () => {
                await fetch('/api/admin/view-as', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ target_id: p.id }),
                })
                window.location.href = '/dashboard'
              }} className="btn-icon text-purple-400 hover:text-purple-600" title={`View app as ${p.full_name}`}>
                <Eye size={16} />
              </button>
            )}
            <button onClick={e => { e.stopPropagation(); setSelectedProfile(null) }}
              className="btn-icon text-gray-400 hover:text-gray-600" title="Close">
              <X size={16} />
            </button>
            {canDelete(p) && (
              <button onClick={() => { setConfirmAction({ type: 'delete', profile: p }); setDeleteConfirmName('') }}
                className="btn-icon text-red-400 hover:text-red-600" title="Delete">
                <UserX size={16} />
              </button>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {/* Color Group — admin/director can override */}
          <div>
            <label className="label">Color Group</label>
            {canOverride ? (
              <select className="input" value={p.color_group_id ?? ''} onChange={e => assignColor(p.id, e.target.value, p)}>
                <option value="">No group</option>
                {colorGroups.map(g => {
                  const smInGroup = getSeniorManagerInColor(g.id, p.id)
                  const blocked = isColorLeaderTier(p) && !!smInGroup
                  return (
                    <option key={g.id} value={g.id} disabled={blocked}>
                      {g.name}{blocked ? ` (Leader: ${smInGroup!.full_name})` : ''}
                    </option>
                  )
                })}
              </select>
            ) : (
              <div className="flex items-center gap-2 text-sm">
                {colorGroup && <div className="w-3 h-3 rounded-full" style={{ backgroundColor: colorGroup.hex_color }} />}
                {colorGroup?.name ?? '—'}
              </div>
            )}
          </div>

          {/* Sponsor — admin/director can override */}
          <div>
            <label className="label">Sponsor</label>
            {canOverride ? (
              <select className="input" value={p.sponsor_id ?? ''} onChange={e => updateProfile(p.id, { sponsor_id: e.target.value || null })}>
                <option value="">No sponsor</option>
                {visibleProfiles.filter(s => s.id !== p.id && s.approved).map(s => (
                  <option key={s.id} value={s.id}>{s.full_name} ({s.member_id ?? 'no ID'})</option>
                ))}
              </select>
            ) : (
              <div className="text-sm">{sponsor?.full_name ?? '—'}</div>
            )}
          </div>

          {/* Activity Status */}
          <div>
            <label className="label">Activity Status</label>
            <select className="input" value={actStatus} onChange={e => setActivityStatus(p.id, e.target.value as ActivityStatus)}>
              {ACTIVITY_OPTIONS.map(o => <option key={o} value={o}>{ACTIVITY_STATUS_LABELS[o]}</option>)}
            </select>
          </div>

          {/* Week number */}
          <div>
            <label className="label">Week Number</label>
            <input type="number" className="input" defaultValue={p.week_number ?? 1} min={1}
              onBlur={e => updateProfile(p.id, { week_number: parseInt(e.target.value) })} />
          </div>
        </div>

        {/* Co-admin toggle — main admin unrestricted; Directors/Co-Admins may
            each assign exactly one of their own and can only remove that one */}
        {(isMainAdmin || isDirector || isCoAdmin) && p.id !== currentProfile.id && (() => {
          const canRemoveThis = isMainAdmin || p.co_admin_assigned_by === currentProfile.id
          const canGrantMore = isMainAdmin || !myAssignedCoAdmin
          const disabled = p.is_co_admin ? !canRemoveThis : !canGrantMore
          return (
            <div className="flex items-center gap-3 pt-2 border-t border-gray-100">
              <Shield size={15} className="text-purple-500" />
              <span className="text-sm text-gray-700 flex-1">Co-Admin Access</span>
              <button onClick={() => toggleCoAdmin(p.id, p.is_co_admin)} disabled={disabled}
                title={disabled ? (p.is_co_admin ? "Only who assigned this Co-Admin can remove them" : "You've already assigned your one Co-Admin") : undefined}
                className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all ${disabled ? 'bg-gray-50 text-gray-300 cursor-not-allowed' : p.is_co_admin ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-purple-50'}`}>
                {p.is_co_admin ? 'Remove Co-Admin' : 'Make Co-Admin'}
              </button>
            </div>
          )
        })()}
      </div>
    )
  }

  // ── TREE VIEW ─────────────────────────────────────────────────────────────

  function TreeNode({ profileId, depth = 0 }: { profileId: string; depth?: number }) {
    const p = allProfiles.find(x => x.id === profileId)
    if (!p) return null
    const children = allProfiles.filter(x => x.sponsor_id === profileId && x.approved)
    const expanded = expandedNodes.has(profileId)
    const colorGroup = colorGroups.find(g => g.id === p.color_group_id)

    return (
      <div style={{ marginLeft: depth * 20 }}>
        <div className="flex items-center gap-2 py-1.5 px-2 rounded-lg hover:bg-gray-50 cursor-pointer"
          onClick={() => {
            setExpandedNodes(prev => { const n = new Set(prev); n.has(profileId) ? n.delete(profileId) : n.add(profileId); return n })
            setSelectedProfile(p)
          }}>
          {children.length > 0
            ? (expanded ? <ChevronDown size={14} className="text-gray-400" /> : <ChevronRight size={14} className="text-gray-400" />)
            : <div className="w-3.5" />
          }
          <div className="w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold text-white flex-shrink-0"
            style={{ backgroundColor: colorGroup?.hex_color ?? '#6366f1' }}>
            {p.full_name.charAt(0)}
          </div>
          <div className="flex-1 min-w-0">
            <span className="text-sm font-medium text-gray-900">{p.full_name}</span>
            <span className="text-xs text-gray-400 ml-2">{p.member_id ?? ''} · {getStatusLabel(p.status)}</span>
          </div>
          {children.length > 0 && <span className="text-xs text-gray-400">{children.length} direct</span>}
        </div>
        {expanded && children.map(c => <TreeNode key={c.id} profileId={c.id} depth={depth + 1} />)}
      </div>
    )
  }

  // ── SEARCH FILTER ─────────────────────────────────────────────────────────

  function filterProfiles(list: Profile[]) {
    return list.filter(p => {
      const q = search.toLowerCase()
      const matchSearch = !q || p.full_name.toLowerCase().includes(q) || (p.member_id ?? '').toLowerCase().includes(q) || p.email.toLowerCase().includes(q)
      const matchStatus = statusFilter === 'all' || p.status === statusFilter
      return matchSearch && matchStatus
    })
  }

  const filtered = filterProfiles(tab === 'active' ? activeProfiles : tab === 'inactive' ? inactiveProfiles : [])

  // ── TABS ─────────────────────────────────────────────────────────────────

  const tabs = [
    { id: 'active', label: `Active (${activeProfiles.length})` },
    { id: 'pending', label: `Pending (${pendingProfiles.length})` },
    { id: 'inactive', label: `Inactive (${inactiveProfiles.length})` },
    { id: 'tree', label: 'Tree View' },
    { id: 'add', label: '+ Add Member' },
  ]

  return (
    <div className="max-w-6xl mx-auto space-y-5">
      {msg && (
        <div className={`px-4 py-3 rounded-xl text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {tabs.map(t => (
          <button key={t.id} onClick={() => { setTab(t.id as any); setSelectedProfile(null) }}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* Search + status filter */}
      {(tab === 'active' || tab === 'inactive') && (
        <div className="flex gap-3 flex-wrap">
          <div className="relative flex-1 max-w-sm">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input className="input pl-8" placeholder="Search name, ID, email…" value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <select className="input w-auto" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
            <option value="all">All Statuses</option>
            {['member','distributor','manager','senior_manager','executive_manager','director'].map(s => (
              <option key={s} value={s}>{getStatusLabel(s as any)}</option>
            ))}
          </select>
        </div>
      )}

      {/* ACTIVE TAB */}
      {tab === 'active' && (
        <div className="grid grid-cols-1 gap-4">
          {filtered.length === 0
            ? <p className="text-sm text-gray-400 text-center py-12">No active members found</p>
            : filtered.map(p => (
              <div key={p.id}>
                {selectedProfile?.id === p.id
                  ? <div onClick={e => e.stopPropagation()}><ProfileCard p={p} /></div>
                  : (
                    <button
                      type="button"
                      className="w-full card p-4 flex items-center gap-3 hover:shadow-md transition-shadow text-left"
                      onClick={e => { e.stopPropagation(); setSelectedProfile(p); setMsg(null) }}
                    >
                      <div className="w-9 h-9 rounded-full flex items-center justify-center font-bold text-white text-sm flex-shrink-0"
                        style={{ backgroundColor: colorGroups.find(g => g.id === p.color_group_id)?.hex_color ?? '#6366f1' }}>
                        {p.full_name.charAt(0)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="font-semibold text-gray-900 truncate">{p.full_name}</div>
                        <div className="text-xs text-gray-400">{p.member_id ?? 'No ID'} · {getStatusLabel(p.status)}</div>
                      </div>
                      {p.is_co_admin && <span className="badge bg-purple-100 text-purple-700 text-xs">Co-Admin</span>}
                      <ChevronRight size={16} className="text-gray-300" />
                    </button>
                  )
                }
              </div>
            ))
          }
        </div>
      )}

      {/* INACTIVE TAB */}
      {tab === 'inactive' && (
        <div className="grid grid-cols-1 gap-4">
          {filtered.length === 0
            ? <p className="text-sm text-gray-400 text-center py-12">No inactive members</p>
            : filtered.map(p => (
              <div key={p.id}>
                {selectedProfile?.id === p.id
                  ? <div onClick={e => e.stopPropagation()}><ProfileCard p={p} /></div>
                  : (
                    <button
                      type="button"
                      className="w-full card p-4 flex items-center gap-3 opacity-70 hover:opacity-100 transition-opacity text-left"
                      onClick={e => { e.stopPropagation(); setSelectedProfile(p); setMsg(null) }}
                    >
                      <div className="w-9 h-9 rounded-full bg-gray-300 flex items-center justify-center font-bold text-white text-sm flex-shrink-0">
                        {p.full_name.charAt(0)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="font-semibold text-gray-700 truncate">{p.full_name}</div>
                        <div className="text-xs text-gray-400">{getStatusLabel(p.status)} · <span className={`${ACTIVITY_STATUS_COLORS[(p.activity_status || 'inactive') as ActivityStatus]}`}>{ACTIVITY_STATUS_LABELS[(p.activity_status || 'inactive') as ActivityStatus]}</span></div>
                      </div>
                      <ChevronRight size={16} className="text-gray-300" />
                    </button>
                  )
                }
              </div>
            ))
          }
        </div>
      )}

      {/* PENDING TAB */}
      {tab === 'pending' && (
        <div className="space-y-4">
          {pendingProfiles.length === 0
            ? <p className="text-sm text-gray-400 text-center py-12">No pending applications</p>
            : pendingProfiles.map(p => (
              <div key={p.id} className="card p-5">
                <div className="flex items-start justify-between gap-3 mb-3">
                  <div>
                    <div className="font-bold text-gray-900">{p.full_name}</div>
                    <div className="text-sm text-gray-400">{p.email} · Applied {formatDate(p.created_at)}</div>
                    <div className="flex gap-1.5 mt-1 flex-wrap">
                      <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                      {(p as any).color_groups && <span className="badge bg-gray-100 text-gray-600">{(p as any).color_groups.name}</span>}
                      {(p as any).sponsor && <span className="badge bg-blue-100 text-blue-700">Sponsor: {(p as any).sponsor.full_name}</span>}
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <button onClick={() => setConfirmAction({ type: 'approve', profile: p })}
                      className="btn-primary text-xs px-3 py-1.5 flex items-center gap-1">
                      <Check size={13} /> Approve
                    </button>
                    <button onClick={() => setConfirmAction({ type: 'reject', profile: p })}
                      className="btn-secondary text-xs px-3 py-1.5 flex items-center gap-1 text-red-600 border-red-200">
                      <X size={13} /> Reject
                    </button>
                    {isMainAdmin && (
                      <button onClick={() => { setConfirmAction({ type: 'delete', profile: p }); setDeleteConfirmName('') }}
                        className="btn-icon text-red-400" title="Delete application">
                        <UserX size={15} />
                      </button>
                    )}
                  </div>
                </div>
                {p.about && <p className="text-sm text-gray-500 bg-gray-50 rounded-lg p-3">{p.about}</p>}
              </div>
            ))
          }

          {/* Rejected section */}
          {rejectedProfiles.length > 0 && (
            <div className="mt-6">
              <h3 className="section-title mb-3 text-red-500">Rejected Applications ({rejectedProfiles.length})</h3>
              {rejectedProfiles.map(p => (
                <div key={p.id} className="card p-4 flex items-center gap-3 opacity-60 mb-2">
                  <div className="flex-1">
                    <div className="font-semibold text-gray-700">{p.full_name}</div>
                    <div className="text-xs text-gray-400">{p.email}</div>
                    {p.rejection_reason && <div className="text-xs text-red-400 mt-0.5">Reason: {p.rejection_reason}</div>}
                  </div>
                  <button onClick={() => { setConfirmAction({ type: 'delete', profile: p }); setDeleteConfirmName('') }}
                    className="btn-icon text-red-400 hover:text-red-600" title="Delete">
                    <UserX size={15} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* TREE VIEW */}
      {tab === 'tree' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div className="card p-5">
            <h2 className="section-title mb-4">Organisation Tree</h2>
            {isMainAdmin ? (
              // Main admin sees full tree from root
              allProfiles.filter(p => !p.sponsor_id && p.approved).map(p => (
                <TreeNode key={p.id} profileId={p.id} />
              ))
            ) : (
              // Directors/others: see tree from any approved member but NOT the main admin as root
              <div>
                <p className="text-xs text-gray-400 mb-3">Click any member to see their downline</p>
                {visibleProfiles.filter(p => p.approved && p.activity_status === 'active').slice(0, 30).map(p => (
                  <TreeNode key={p.id} profileId={p.id} />
                ))}
              </div>
            )}
          </div>
          {selectedProfile && (
            <div>
              <ProfileCard p={selectedProfile} />
            </div>
          )}
        </div>
      )}

      {/* ADD MEMBER */}
      {tab === 'add' && (
        <div className="card p-6 max-w-lg">
          <h2 className="section-title mb-4">Add Member Manually</h2>
          <div className="space-y-3">
            {[
              { label: 'Full Name', key: 'full_name', type: 'text', placeholder: 'John Smith' },
              { label: 'Email', key: 'email', type: 'email', placeholder: 'john@example.com' },
              { label: 'Phone', key: 'phone', type: 'tel', placeholder: '+44 7700 000000' },
            ].map(f => (
              <div key={f.key}>
                <label className="label">{f.label}</label>
                <input type={f.type} className="input" placeholder={f.placeholder}
                  value={(addForm as any)[f.key]} onChange={e => setAddForm(prev => ({ ...prev, [f.key]: e.target.value }))} />
              </div>
            ))}
            <div>
              <label className="label">Status</label>
              <select className="input" value={addForm.status} onChange={e => setAddForm(p => ({ ...p, status: e.target.value }))}>
                {['member','distributor','manager','senior_manager','executive_manager','director'].map(s => (
                  <option key={s} value={s}>{getStatusLabel(s as any)}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Color Group</label>
              <select className="input" value={addForm.color_group_id} onChange={e => setAddForm(p => ({ ...p, color_group_id: e.target.value }))}>
                <option value="">Select group</option>
                {colorGroups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Sponsor</label>
              <select className="input" value={addForm.sponsor_id} onChange={e => setAddForm(p => ({ ...p, sponsor_id: e.target.value }))}>
                <option value="">No sponsor</option>
                {visibleProfiles.filter(p => p.approved).map(p => (
                  <option key={p.id} value={p.id}>{p.full_name} ({p.member_id ?? 'no ID'})</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Starting Week</label>
              <input type="number" className="input" min={1} value={addForm.week_number}
                onChange={e => setAddForm(p => ({ ...p, week_number: parseInt(e.target.value) }))} />
            </div>
            <button onClick={addMemberManually} disabled={addLoading || !addForm.full_name || !addForm.email} className="btn-primary w-full">
              {addLoading ? 'Creating…' : 'Create Member'}
            </button>
            {msg && <div className={`text-sm ${msg.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>{msg.text}</div>}
          </div>
        </div>
      )}

      {/* ── CONFIRM MODALS ─────────────────────────────────────────────────── */}
      {confirmAction && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4" onClick={e => { if (e.target === e.currentTarget) setConfirmAction(null) }}>
          <div className="bg-white rounded-2xl p-6 max-w-md w-full shadow-2xl">
            {confirmAction.type === 'approve' && (
              <>
                <h3 className="text-lg font-bold mb-2">Approve {confirmAction.profile.full_name}?</h3>
                <p className="text-sm text-gray-500 mb-4">This will generate their member ID and grant full access.</p>
                <div className="flex gap-3">
                  <button onClick={() => confirmApprove(confirmAction.profile)} className="btn-primary flex-1" disabled={!!loading}>
                    {loading ? 'Processing…' : 'Confirm Approve'}
                  </button>
                  <button onClick={() => setConfirmAction(null)} className="btn-secondary">Cancel</button>
                </div>
              </>
            )}
            {confirmAction.type === 'reject' && (
              <>
                <h3 className="text-lg font-bold mb-2">Reject {confirmAction.profile.full_name}?</h3>
                <label className="label mb-1">Reason (optional)</label>
                <textarea className="input resize-none mb-4" rows={3} placeholder="Why are you rejecting this application?"
                  value={rejectReason} onChange={e => setRejectReason(e.target.value)} />
                <div className="flex gap-3">
                  <button onClick={() => confirmReject(confirmAction.profile)} className="btn-primary bg-red-500 hover:bg-red-600 flex-1">
                    Confirm Reject
                  </button>
                  <button onClick={() => setConfirmAction(null)} className="btn-secondary">Cancel</button>
                </div>
              </>
            )}
            {confirmAction.type === 'delete' && (
              <>
                <h3 className="text-lg font-bold mb-2 text-red-600">Delete {confirmAction.profile.full_name}?</h3>
                <p className="text-sm text-gray-500 mb-4">This action is permanent and cannot be undone. All their data will be removed.</p>
                {isMainAdmin && (
                  <>
                    <label className="label mb-1">Type their full name to confirm:</label>
                    <input className="input mb-4" placeholder={confirmAction.profile.full_name}
                      value={deleteConfirmName} onChange={e => setDeleteConfirmName(e.target.value)} />
                  </>
                )}
                <div className="flex gap-3">
                  <button onClick={() => confirmDelete(confirmAction.profile)}
                    disabled={isMainAdmin && deleteConfirmName.trim().toLowerCase() !== confirmAction.profile.full_name.toLowerCase()}
                    className="btn-primary bg-red-500 hover:bg-red-600 flex-1 disabled:opacity-40">
                    Delete Permanently
                  </button>
                  <button onClick={() => setConfirmAction(null)} className="btn-secondary">Cancel</button>
                </div>
                {msg?.type === 'error' && <p className="text-red-500 text-sm mt-2">{msg.text}</p>}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "components/attendance"
cat > "components/attendance/QRScanner.tsx" << 'CLAUDE_EOF_MARKER'
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
        supabase.from('activity_events').insert({
          type: 'sign_in', actor_id: user.id, message: `${user.full_name} signed in at ${format(now, 'h:mm a')}`,
        })
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
        supabase.from('activity_events').insert({
          type: 'sign_out', actor_id: user.id, message: `${user.full_name} signed out at ${format(now, 'h:mm a')}`,
        })
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
CLAUDE_EOF_MARKER

mkdir -p "components/layout"
cat > "components/layout/Header.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Menu, X, Bell, LayoutDashboard, Users, UserCheck, DollarSign, Search, Calendar, MessageSquare, Settings, QrCode, Group, LogOut } from 'lucide-react'
import type { Profile } from '@/lib/types'
import { getStatusLabel, isSmOrAbove } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import ActivityFeed from '@/components/layout/ActivityFeed'

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/attendance': 'Attendance',
  '/team': 'My Team',
  '/group': 'My Group',
  '/people': 'People',
  '/money': 'Money Making',
  '/scouting': 'Scouting',
  '/community': 'Community',
  '/events': 'Events',
  '/settings': 'Settings',
}

export default function Header({ profile }: { profile: Profile }) {
  const pathname = usePathname()
  const router = useRouter()
  const [mobileOpen, setMobileOpen] = useState(false)
  const isAdmin = profile.is_admin || profile.is_director || profile.is_co_admin
  const isSm = isSmOrAbove(profile.status)

  const title = Object.entries(PAGE_TITLES).find(([k]) =>
    pathname === k || pathname.startsWith(k + '/')
  )?.[1] ?? 'Elevate'

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
  }

  const navItems = [
    { href: '/dashboard', label: 'Dashboard', icon: <LayoutDashboard size={18} /> },
    { href: '/attendance', label: 'Attendance', icon: <QrCode size={18} /> },
    { href: '/team', label: 'My Team', icon: <Users size={18} /> },
    ...(isSm || isAdmin ? [{ href: '/group', label: 'My Group', icon: <Group size={18} /> }] : []),
    ...(isAdmin ? [{ href: '/people', label: 'People', icon: <UserCheck size={18} /> }] : []),
    { href: '/money', label: 'Money Making', icon: <DollarSign size={18} /> },
    { href: '/scouting', label: 'Scouting', icon: <Search size={18} /> },
    { href: '/community', label: 'Community', icon: <MessageSquare size={18} /> },
    { href: '/events', label: 'Events', icon: <Calendar size={18} /> },
    { href: '/settings', label: 'Settings', icon: <Settings size={18} /> },
  ]

  return (
    <>
      <header className="bg-white border-b border-gray-200 px-4 sm:px-6 py-3 flex items-center justify-between flex-shrink-0">
        {/* Mobile menu button */}
        <button
          className="md:hidden p-2 rounded-lg text-gray-500 hover:bg-gray-100"
          onClick={() => setMobileOpen(true)}
        >
          <Menu size={20} />
        </button>

        <h1 className="text-lg font-bold text-gray-900">{title}</h1>

        <div className="flex items-center gap-2">
          <ActivityFeed />
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold cursor-pointer"
            style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}
            title={profile.full_name ?? ''}
          >
            {(profile.full_name ?? '?').split(' ').filter(Boolean).map(n => n[0]).join('').slice(0, 2).toUpperCase()}
          </div>
        </div>
      </header>

      {/* Mobile sidebar */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div className="absolute inset-0 bg-black/40" onClick={() => setMobileOpen(false)} />
          <aside className="absolute left-0 top-0 bottom-0 w-72 bg-white flex flex-col overflow-y-auto shadow-2xl">
            <div className="flex items-center justify-between p-4 border-b border-gray-100">
              <div className="font-bold text-gray-900">Elevate</div>
              <button onClick={() => setMobileOpen(false)} className="p-2 rounded-lg hover:bg-gray-100">
                <X size={18} />
              </button>
            </div>

            <div className="px-4 py-3 border-b border-gray-100">
              <div className="text-sm font-semibold text-gray-900">{profile.full_name}</div>
              <div className="text-xs text-gray-400">{profile.member_id} · {getStatusLabel(profile.status)}</div>
            </div>

            <nav className="flex-1 p-3 space-y-0.5">
              {navItems.map(item => {
                const active = pathname === item.href
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    onClick={() => setMobileOpen(false)}
                    className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                      active ? 'bg-brand-600 text-white' : 'text-gray-600 hover:bg-gray-100'
                    }`}
                  >
                    {item.icon}
                    {item.label}
                  </Link>
                )
              })}
            </nav>

            <div className="p-3 border-t border-gray-100">
              <button onClick={handleSignOut} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-gray-500 hover:bg-red-50 hover:text-red-600">
                <LogOut size={18} />
                Sign Out
              </button>
            </div>
          </aside>
        </div>
      )}
    </>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "components/layout"
cat > "components/layout/ActivityFeed.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState, useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Bell, LogIn, LogOut, DollarSign, MessageSquare, UserPlus } from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

interface ActivityEvent {
  id: string
  type: string
  message: string
  created_at: string
}

const ICONS: Record<string, React.ReactNode> = {
  sign_in: <LogIn size={14} className="text-green-500" />,
  sign_out: <LogOut size={14} className="text-gray-400" />,
  earning: <DollarSign size={14} className="text-green-600" />,
  community_post: <MessageSquare size={14} className="text-blue-500" />,
  new_member: <UserPlus size={14} className="text-brand-500" />,
}

const LAST_SEEN_KEY = 'activity_feed_last_seen'

export default function ActivityFeed() {
  const [events, setEvents] = useState<ActivityEvent[]>([])
  const [open, setOpen] = useState(false)
  const [unread, setUnread] = useState(0)
  const ref = useRef<HTMLDivElement>(null)

  async function load() {
    const supabase = createClient()
    const { data } = await supabase
      .from('activity_events')
      .select('id, type, message, created_at')
      .order('created_at', { ascending: false })
      .limit(30)
    if (data) {
      setEvents(data)
      const lastSeen = localStorage.getItem(LAST_SEEN_KEY)
      const lastSeenTime = lastSeen ? new Date(lastSeen).getTime() : 0
      setUnread(data.filter(e => new Date(e.created_at).getTime() > lastSeenTime).length)
    }
  }

  useEffect(() => {
    load()
    const supabase = createClient()
    const channel = supabase
      .channel('activity_events')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'activity_events' }, () => {
        load()
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [])

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  function toggle() {
    const next = !open
    setOpen(next)
    if (next) {
      localStorage.setItem(LAST_SEEN_KEY, new Date().toISOString())
      setUnread(0)
    }
  }

  return (
    <div className="relative" ref={ref}>
      <button onClick={toggle} className="relative w-8 h-8 rounded-full flex items-center justify-center text-gray-500 hover:bg-gray-100 transition-colors" title="Activity">
        <Bell size={18} />
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>
      {open && (
        <div className="absolute right-0 mt-2 w-80 max-h-96 overflow-y-auto bg-white rounded-xl shadow-lg border border-gray-100 z-50">
          <div className="px-4 py-3 border-b border-gray-100 font-semibold text-sm text-gray-900">Activity</div>
          {events.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">Nothing yet</p>
          ) : (
            events.map(e => (
              <div key={e.id} className="px-4 py-2.5 border-b border-gray-50 flex items-start gap-2.5 hover:bg-gray-50">
                <div className="mt-0.5">{ICONS[e.type] ?? <Bell size={14} className="text-gray-400" />}</div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-gray-700">{e.message}</p>
                  <p className="text-xs text-gray-400">{formatDistanceToNow(new Date(e.created_at), { addSuffix: true })}</p>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "supabase"
cat > "supabase/schema.sql" << 'CLAUDE_EOF_MARKER'
-- =============================================
-- ELEVATE OFFICE TRACKER — COMPLETE SCHEMA
-- Run this in Supabase SQL Editor
-- =============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- =============================================
-- COLOR GROUPS
-- =============================================
create table if not exists color_groups (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  code text not null unique,        -- RED, GRN, BLU, etc.
  hex_color text not null default '#6366f1',
  member_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- Insert default color groups
insert into color_groups (name, code, hex_color) values
  ('Red',    'RED', '#ef4444'),
  ('Blue',   'BLU', '#3b82f6'),
  ('Green',  'GRN', '#22c55e'),
  ('Orange', 'ORG', '#f97316'),
  ('Yellow', 'YEL', '#eab308'),
  ('Purple', 'PRP', '#a855f7'),
  ('White',  'WHT', '#e5e7eb'),
  ('Gold',   'GLD', '#f59e0b'),
  ('Silver', 'SLV', '#94a3b8'),
  ('Black',  'BLK', '#1e293b')
on conflict do nothing;

-- =============================================
-- PROFILES (extends Supabase auth.users)
-- =============================================
do $$ begin
  create type user_status as enum (
    'member', 'distributor', 'manager',
    'senior_manager', 'executive_manager', 'director'
  );
exception when duplicate_object then null;
end $$;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  member_id text unique,             -- e.g. RED001
  status user_status not null default 'member',
  color_group_id uuid references color_groups(id),
  sponsor_id uuid references profiles(id),
  upline_sm_id uuid references profiles(id),
  is_admin boolean not null default false,
  is_director boolean not null default false,
  approved boolean not null default false,
  rejected boolean not null default false,
  rejection_reason text,
  profile_picture text,              -- storage URL
  about text,
  phone text,
  week_number integer not null default 1 check (week_number between 1 and 12),
  week_confirmed boolean not null default false,
  is_new_member boolean not null default false,
  new_member_month text,             -- YYYY-MM
  is_office_already boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trigger: auto-update updated_at
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists profiles_updated_at on profiles;
create trigger profiles_updated_at before update on profiles
  for each row execute function update_updated_at();

-- =============================================
-- ATTENDANCE
-- =============================================
create table if not exists attendance (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  date date not null,
  sign_in_time timestamptz,
  sign_out_time timestamptz,
  is_night_session boolean not null default false,
  sign_in_note text,                 -- what did you do with your business yesterday/weekend
  sign_out_note text,                -- what did you do in the office today
  late_in boolean not null default false,
  late_out boolean not null default false,
  created_at timestamptz not null default now(),
  unique(user_id, date, is_night_session)
);

-- =============================================
-- WEEKLY EARNINGS
-- =============================================
create table if not exists weekly_earnings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  week_start date not null,          -- Saturday
  week_end date not null,            -- Friday
  amount_usd numeric(12,2) not null default 0,
  recorded_by uuid references profiles(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, week_start)
);

drop trigger if exists weekly_earnings_updated_at on weekly_earnings;
create trigger weekly_earnings_updated_at before update on weekly_earnings
  for each row execute function update_updated_at();

-- =============================================
-- SCOUTING RECORDS
-- =============================================
create table if not exists scouting_records (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  business_name text not null,
  rating text,
  reviews text,
  band text,
  profile_link text,
  industry text,
  email text,
  match_score text,
  issues_found text,
  status text default 'Pending',
  message_sent text,
  their_reply text,
  source text default 'Scout App',
  scouted_at timestamptz not null default now(),
  upload_batch_id uuid,
  unique(user_id, profile_link)
);

-- =============================================
-- EVENTS
-- =============================================
create table if not exists events (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  event_date date not null,
  event_time time,
  location text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

-- =============================================
-- COMMUNITY POSTS
-- =============================================
create table if not exists community_posts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  attachment_url text,
  attachment_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists community_posts_updated_at on community_posts;
create trigger community_posts_updated_at before update on community_posts
  for each row execute function update_updated_at();

-- =============================================
-- TASKS (assigned by SM to team)
-- =============================================
create table if not exists tasks (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  assigned_to uuid not null references profiles(id) on delete cascade,
  assigned_by uuid references profiles(id),
  due_date date,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

-- =============================================
-- APP SETTINGS
-- =============================================
create table if not exists app_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);

insert into app_settings (key, value) values
  ('app_name', 'Elevate Office Tracker'),
  ('app_logo', ''),
  ('about_us', 'Welcome to Elevate — where excellence meets accountability.'),
  ('primary_color', '#4f46e5'),
  ('font_family', 'Inter')
on conflict do nothing;

-- =============================================
-- MEMBER ID SEQUENCE per color group
-- =============================================
create table if not exists member_id_sequences (
  color_code text primary key,
  next_number integer not null default 1
);

insert into member_id_sequences (color_code, next_number)
select code, 1 from color_groups
on conflict do nothing;

-- Function to generate next member ID
create or replace function generate_member_id(p_color_code text)
returns text language plpgsql as $$
declare
  v_num integer;
  v_id text;
begin
  update member_id_sequences
  set next_number = next_number + 1
  where color_code = p_color_code
  returning next_number - 1 into v_num;

  if not found then
    insert into member_id_sequences (color_code, next_number) values (p_color_code, 2);
    v_num := 1;
  end if;

  v_id := p_color_code || lpad(v_num::text, 3, '0');
  return v_id;
end; $$;

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================

alter table profiles enable row level security;
alter table attendance enable row level security;
alter table weekly_earnings enable row level security;
alter table scouting_records enable row level security;
alter table events enable row level security;
alter table community_posts enable row level security;
alter table tasks enable row level security;
alter table color_groups enable row level security;
alter table app_settings enable row level security;

-- Helper: get current user's profile
create or replace function get_my_profile()
returns profiles language sql security definer stable as $$
  select * from profiles where id = auth.uid();
$$;

-- Helper: is admin or director
create or replace function is_admin_or_director()
returns boolean language sql security definer stable as $$
  select coalesce(
    (select is_admin or is_director or is_co_admin from profiles where id = auth.uid()),
    false
  );
$$;

-- Helper: is senior manager or above
create or replace function is_sm_or_above()
returns boolean language sql security definer stable as $$
  select coalesce(
    (select status in ('senior_manager','executive_manager','director')
     from profiles where id = auth.uid()),
    false
  );
$$;

-- PROFILES policies
drop policy if exists "Anyone can view approved profiles" on profiles;
create policy "Anyone can view approved profiles" on profiles
  for select using (approved = true);

drop policy if exists "Users can view own profile" on profiles;
create policy "Users can view own profile" on profiles
  for select using (id = auth.uid());

drop policy if exists "Admins view all profiles" on profiles;
create policy "Admins view all profiles" on profiles
  for select using (is_admin_or_director());

drop policy if exists "Users update own profile" on profiles;
create policy "Users update own profile" on profiles
  for update using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "Admins manage all profiles" on profiles;
create policy "Admins manage all profiles" on profiles
  for all using (is_admin_or_director());

drop policy if exists "Allow insert on signup" on profiles;
create policy "Allow insert on signup" on profiles
  for insert with check (id = auth.uid());

-- COLOR GROUPS policies
drop policy if exists "Anyone can view color groups" on color_groups;
create policy "Anyone can view color groups" on color_groups
  for select using (true);

drop policy if exists "Admins manage color groups" on color_groups;
create policy "Admins manage color groups" on color_groups
  for all using (is_admin_or_director());

-- ATTENDANCE policies
drop policy if exists "Users view own attendance" on attendance;
create policy "Users view own attendance" on attendance
  for select using (user_id = auth.uid());

drop policy if exists "SM+ view team attendance" on attendance;
create policy "SM+ view team attendance" on attendance
  for select using (is_sm_or_above());

drop policy if exists "Admins view all attendance" on attendance;
create policy "Admins view all attendance" on attendance
  for select using (is_admin_or_director());

drop policy if exists "Users manage own attendance" on attendance;
create policy "Users manage own attendance" on attendance
  for all using (user_id = auth.uid());

drop policy if exists "Admins manage all attendance" on attendance;
create policy "Admins manage all attendance" on attendance
  for all using (is_admin_or_director());

-- WEEKLY EARNINGS policies
drop policy if exists "Members view own earnings" on weekly_earnings;
create policy "Members view own earnings" on weekly_earnings
  for select using (user_id = auth.uid());

drop policy if exists "SM+ view team earnings" on weekly_earnings;
create policy "SM+ view team earnings" on weekly_earnings
  for select using (is_sm_or_above());

drop policy if exists "Admins manage earnings" on weekly_earnings;
create policy "Admins manage earnings" on weekly_earnings
  for all using (is_admin_or_director());

-- SCOUTING policies
drop policy if exists "Users view own scouting" on scouting_records;
create policy "Users view own scouting" on scouting_records
  for select using (user_id = auth.uid());

drop policy if exists "SM+ view team scouting" on scouting_records;
create policy "SM+ view team scouting" on scouting_records
  for select using (is_sm_or_above());

drop policy if exists "Users manage own scouting" on scouting_records;
create policy "Users manage own scouting" on scouting_records
  for all using (user_id = auth.uid());

drop policy if exists "Admins manage all scouting" on scouting_records;
create policy "Admins manage all scouting" on scouting_records
  for all using (is_admin_or_director());

-- EVENTS policies
drop policy if exists "Anyone authenticated can view events" on events;
create policy "Anyone authenticated can view events" on events
  for select using (auth.uid() is not null);

drop policy if exists "Admins manage events" on events;
create policy "Admins manage events" on events
  for all using (is_admin_or_director());

-- COMMUNITY policies
drop policy if exists "Anyone authenticated can view posts" on community_posts;
create policy "Anyone authenticated can view posts" on community_posts
  for select using (auth.uid() is not null);

drop policy if exists "Users manage own posts" on community_posts;
create policy "Users manage own posts" on community_posts
  for all using (user_id = auth.uid());

drop policy if exists "Admins manage all posts" on community_posts;
create policy "Admins manage all posts" on community_posts
  for all using (is_admin_or_director());

-- TASKS policies
drop policy if exists "Users view own tasks" on tasks;
create policy "Users view own tasks" on tasks
  for select using (assigned_to = auth.uid() or assigned_by = auth.uid());

drop policy if exists "SM+ view and create tasks" on tasks;
create policy "SM+ view and create tasks" on tasks
  for all using (is_sm_or_above());

-- APP SETTINGS policies
drop policy if exists "Anyone can read settings" on app_settings;
create policy "Anyone can read settings" on app_settings
  for select using (true);

drop policy if exists "Admins update settings" on app_settings;
create policy "Admins update settings" on app_settings
  for all using (is_admin_or_director());

-- =============================================
-- FEEDBACK
-- =============================================
create table if not exists feedback (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  message text not null,
  category text not null default 'general',  -- general, bug, feature, complaint
  status text not null default 'open',        -- open, in_review, resolved
  admin_response text,
  responded_by uuid references profiles(id),
  responded_at timestamptz,
  created_at timestamptz not null default now()
);

alter table feedback enable row level security;

drop policy if exists "Users view own feedback" on feedback;
create policy "Users view own feedback" on feedback
  for select using (user_id = auth.uid());

drop policy if exists "Users create feedback" on feedback;
create policy "Users create feedback" on feedback
  for insert with check (user_id = auth.uid());

drop policy if exists "Admins manage all feedback" on feedback;
create policy "Admins manage all feedback" on feedback
  for all using (is_admin_or_director());

-- =============================================
-- STORAGE BUCKETS (run separately in dashboard)
-- =============================================
-- Create buckets: 'avatars' (public), 'attachments' (public)
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('attachments', 'attachments', true) on conflict (id) do nothing;

-- =============================================
-- SEED: Admin user setup
-- After running this schema, sign up normally, then run this in SQL Editor:
-- UPDATE profiles SET is_admin = true, is_director = true, approved = true,
--   status = 'director', week_number = 12
--   WHERE email = 'YOUR_ADMIN_EMAIL_HERE';
-- =============================================

-- =============================================
-- WEEK TRACKING SYSTEM
-- =============================================

-- Weekly assessment submissions
create table if not exists week_assessments (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  week_number integer not null check (week_number between 1 and 12),
  submitted boolean not null default false,
  submitted_at timestamptz,
  graded boolean not null default false,
  graded_at timestamptz,
  graded_by uuid references profiles(id),
  grade text,                          -- pass / fail / excellent
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, week_number)
);

alter table week_assessments enable row level security;

drop policy if exists "Users view own assessments" on week_assessments;
create policy "Users view own assessments" on week_assessments
  for select using (user_id = auth.uid());

drop policy if exists "Admins manage all assessments" on week_assessments;
create policy "Admins manage all assessments" on week_assessments
  for all using (is_admin_or_director());

drop policy if exists "SM view team assessments" on week_assessments;
create policy "SM view team assessments" on week_assessments
  for select using (is_sm_or_above());

-- Week advancement log (tracks who advanced, who repeated, pardons)
create table if not exists week_advancement_log (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  from_week integer not null,
  to_week integer not null,
  action text not null,               -- 'advanced' | 'repeated' | 'pardoned'
  attendance_days integer not null default 0,
  assessment_submitted boolean not null default false,
  assessment_graded boolean not null default false,
  admin_notes text,
  actioned_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

alter table week_advancement_log enable row level security;

drop policy if exists "Users view own advancement log" on week_advancement_log;
create policy "Users view own advancement log" on week_advancement_log
  for select using (user_id = auth.uid());

drop policy if exists "Admins manage advancement log" on week_advancement_log;
create policy "Admins manage advancement log" on week_advancement_log
  for all using (is_admin_or_director());

-- Absence email log (tracks which emails were sent to avoid duplicates)
create table if not exists absence_emails (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  email_type text not null,           -- 'daily_miss' | 'weekly_summary'
  sent_at timestamptz not null default now(),
  date_missed date,                   -- for daily miss
  week_number integer,                -- for weekly summary
  miss_count integer,                 -- how many days missed that week
  delivered boolean not null default true,
  unique(user_id, email_type, date_missed)
);

alter table absence_emails enable row level security;

drop policy if exists "Admins manage absence emails" on absence_emails;
create policy "Admins manage absence emails" on absence_emails
  for all using (is_admin_or_director());

-- =============================================
-- ACTIVITY STATUS & MONTHLY EARNINGS
-- =============================================

-- Add activity_status to profiles
alter table profiles add column if not exists activity_status text not null default 'active'
  check (activity_status in ('active','suspended','inactive','left_office','another_location','moved_to_another_office'));

-- Monthly earnings view
create or replace view monthly_earnings as
select
  user_id,
  date_trunc('month', week_start::date)::date as month,
  to_char(week_start::date, 'YYYY-MM') as month_str,
  sum(amount_usd) as total_usd,
  count(*) as weeks_with_earnings
from weekly_earnings
group by user_id, date_trunc('month', week_start::date)::date, to_char(week_start::date, 'YYYY-MM');

-- =============================================
-- GROUP LEADER & CONSISTENT EARNER POINTS
-- =============================================

-- Add is_group_leader to profiles (set when member_id ends in 001)
alter table profiles add column if not exists is_group_leader boolean not null default false;

-- Consistent earner points table
create table if not exists earner_points (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  month_str text not null,           -- 'YYYY-MM'
  rank integer not null,             -- 1st, 2nd, 3rd etc
  points integer not null,           -- 10,9,8...1,0
  amount_usd numeric not null,
  created_at timestamptz not null default now(),
  unique(user_id, month_str)
);

alter table earner_points enable row level security;

drop policy if exists "Anyone can view earner points" on earner_points;
create policy "Anyone can view earner points" on earner_points
  for select using (true);

drop policy if exists "Admins manage earner points" on earner_points;
create policy "Admins manage earner points" on earner_points
  for all using (is_admin_or_director());

-- Function: auto-calculate and upsert earner points for a month
create or replace function calculate_earner_points(p_month_str text)
returns void as $$
declare
  r record;
  v_rank integer := 1;
  v_points integer;
begin
  -- Delete existing points for this month
  delete from earner_points where month_str = p_month_str;

  -- Recalculate from weekly_earnings
  for r in (
    select
      p.id as user_id,
      sum(we.amount_usd) as total_usd
    from weekly_earnings we
    join profiles p on p.id = we.user_id
    where to_char(we.week_start::date, 'YYYY-MM') = p_month_str
      and p.status in ('member','distributor','manager','executive_manager')
      and p.approved = true
    group by p.id
    order by sum(we.amount_usd) desc
  ) loop
    v_points := greatest(0, 11 - v_rank); -- 1st=10, 2nd=9...10th=1, 11th+=0
    if v_rank > 10 then v_points := 0; end if;

    insert into earner_points (user_id, month_str, rank, points, amount_usd)
    values (r.user_id, p_month_str, v_rank, v_points, r.total_usd);

    v_rank := v_rank + 1;
  end loop;
end;
$$ language plpgsql security definer;

-- =============================================
-- FIX: is_co_admin column (referenced throughout the app code
-- but was missing from the schema — caused profile queries that
-- explicitly select it, e.g. app/scanner/page.tsx, to error out).
-- Safe to run multiple times.
-- =============================================
alter table profiles add column if not exists is_co_admin boolean not null default false;

-- =============================================
-- FIX: group_leader_id column on color_groups (exists live but was
-- missing from this schema file — documenting it here for consistency).
-- =============================================
alter table color_groups add column if not exists group_leader_id uuid references profiles(id);

-- =============================================
-- FEATURE: auto-create a color group when someone is promoted to
-- Senior Manager (or above) and doesn't already lead one. They become
-- the group's 001. No two Senior Managers ever share a color group
-- (enforced already in app code for manual assignment; this covers
-- the automatic case on promotion).
-- =============================================
create or replace function auto_create_sm_color_group()
returns trigger language plpgsql as $$
declare
  v_base_code text;
  v_code text;
  v_suffix int := 0;
  v_group_id uuid;
  v_group_name text;
  v_name_suffix int := 0;
begin
  if new.status in ('senior_manager','executive_manager','director')
     and (old.status is distinct from new.status)
     and old.status not in ('senior_manager','executive_manager','director') then

    -- Skip if they already lead a color group
    if exists (select 1 from color_groups where group_leader_id = new.id) then
      return new;
    end if;

    v_base_code := upper(regexp_replace(coalesce(split_part(new.full_name, ' ', 1), 'GRP'), '[^a-zA-Z]', '', 'g'));
    v_base_code := left(nullif(v_base_code, ''), 6);
    if v_base_code is null then v_base_code := 'GRP'; end if;
    v_code := v_base_code;
    while exists (select 1 from color_groups where code = v_code) loop
      v_suffix := v_suffix + 1;
      v_code := v_base_code || v_suffix::text;
    end loop;

    v_group_name := new.full_name || '''s Group';
    while exists (select 1 from color_groups where name = v_group_name) loop
      v_name_suffix := v_name_suffix + 1;
      v_group_name := new.full_name || '''s Group ' || v_name_suffix::text;
    end loop;

    insert into color_groups (name, code, hex_color, group_leader_id)
    values (v_group_name, v_code, '#' || substr(md5(random()::text), 1, 6), new.id)
    returning id into v_group_id;

    insert into member_id_sequences (color_code, next_number) values (v_code, 2)
    on conflict (color_code) do nothing;

    new.color_group_id := v_group_id;
    if new.member_id is null then
      new.member_id := v_code || '001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_auto_create_sm_color_group on profiles;
create trigger trg_auto_create_sm_color_group
before update on profiles
for each row execute function auto_create_sm_color_group();

-- =============================================
-- FEATURE: track who granted co-admin status, so Directors and Co-Admins
-- can each promote exactly one other co-admin from their own side, while
-- the main Admin can still remove anyone's co-admin status regardless of
-- who granted it.
-- =============================================
alter table profiles add column if not exists co_admin_assigned_by uuid references profiles(id);

-- =============================================
-- NOTIFICATIONS (was referenced in app code but never defined here —
-- documenting it properly now, alongside reviving the notification bell).
-- =============================================
create table if not exists notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'info', -- 'info' | 'success' | 'warning'
  link text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table notifications enable row level security;

drop policy if exists "Users view own notifications" on notifications;
create policy "Users view own notifications" on notifications
  for select using (user_id = auth.uid());

drop policy if exists "Users update own notifications" on notifications;
create policy "Users update own notifications" on notifications
  for update using (user_id = auth.uid());

-- Any authenticated user can create a notification FOR someone else (e.g. a
-- teammate signing in triggers a notification insert targeting other users).
-- This mirrors how the app already inserts notifications from client code.
drop policy if exists "Authenticated users can create notifications" on notifications;
create policy "Authenticated users can create notifications" on notifications
  for insert with check (auth.uid() is not null);

create index if not exists notifications_user_id_created_at_idx
  on notifications (user_id, created_at desc);

-- =============================================
-- ACTIVITY FEED — a global, shared feed everyone can see (distinct from the
-- per-user `notifications` table above). Powers the "someone signed in",
-- "earnings recorded", "new community post", "X just joined the team" feed.
-- =============================================
create table if not exists activity_events (
  id uuid primary key default uuid_generate_v4(),
  type text not null, -- 'sign_in' | 'sign_out' | 'earning' | 'community_post' | 'new_member'
  message text not null,
  actor_id uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table activity_events enable row level security;

drop policy if exists "Anyone approved can view activity" on activity_events;
create policy "Anyone approved can view activity" on activity_events
  for select using (
    exists (select 1 from profiles where id = auth.uid() and approved = true)
  );

drop policy if exists "Authenticated users can post activity" on activity_events;
create policy "Authenticated users can post activity" on activity_events
  for insert with check (auth.uid() is not null);

create index if not exists activity_events_created_at_idx on activity_events (created_at desc);
CLAUDE_EOF_MARKER

echo "Staging and committing..."
git add .
git commit -m "feat: global activity feed (sign-in/out, earnings, community posts, new members)"
git push origin main
echo "Done. Vercel should start redeploying now."
echo "IMPORTANT: also re-run supabase/schema.sql in the Supabase SQL Editor for the new activity_events and notifications tables."
