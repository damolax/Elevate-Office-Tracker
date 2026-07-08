'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Profile } from '@/lib/types'
import { getStatusLabel, getStatusColor, STATUS_ORDER } from '@/lib/types'
import { formatCurrency } from '@/lib/utils'
import { TrendingUp, Target, Users, Zap, Star, ArrowLeft, Pencil } from 'lucide-react'

const RANGES = [
  { value: 'today', label: 'Today' },
  { value: 'yesterday', label: 'Yesterday' },
  { value: 'this_week', label: 'This Week' },
  { value: 'last_7_days', label: 'Last 7 Days' },
  { value: 'this_month', label: 'This Month' },
  { value: 'last_3_months', label: 'Last 3 Months' },
  { value: 'all_time', label: 'All Time' },
]

export default function MemberDetailClient({
  viewer, target, canEdit, range,
  totalEarnings, scoutingCount, teamSize, memberStartsThisMonth, teamStartsThisMonth,
  totalPoints, fullDownline,
}: {
  viewer: Profile
  target: Profile & { color_groups?: any; sponsor?: any }
  canEdit: boolean
  range: string
  totalEarnings: number
  scoutingCount: number
  teamSize: number
  memberStartsThisMonth: number
  teamStartsThisMonth: number
  totalPoints: number
  fullDownline: any[]
}) {
  const router = useRouter()
  const [editing, setEditing] = useState(false)
  const [saving, setSaving] = useState(false)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [form, setForm] = useState({
    full_name: target.full_name,
    status: target.status,
    week_number: target.week_number ?? 1,
  })

  const cg = (target as any).color_groups

  function changeRange(r: string) {
    router.push(`/member/${target.id}?range=${r}`)
  }

  async function save() {
    setSaving(true)
    setMsg(null)
    const res = await fetch('/api/update-profile', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user_id: target.id, actor_id: viewer.id, updates: form }),
    })
    const json = await res.json()
    setSaving(false)
    if (!res.ok) {
      setMsg({ type: 'error', text: json.error ?? 'Failed to save' })
      return
    }
    setMsg({ type: 'success', text: 'Saved.' })
    setEditing(false)
    router.refresh()
  }

  // Build a shallow tree (direct downline grouped by sponsor) for display
  function renderStructure(parentId: string, depth = 0): React.ReactNode {
    const children = fullDownline.filter(p => p.sponsor_id === parentId)
    if (!children.length) return null
    return (
      <div style={{ marginLeft: depth ? 16 : 0 }} className={depth ? 'border-l border-gray-100 pl-3 mt-1' : ''}>
        {children.map(c => (
          <div key={c.id}>
            <div className="flex items-center gap-2 py-1.5">
              <div className="w-6 h-6 rounded-full flex items-center justify-center text-white text-[10px] font-bold flex-shrink-0"
                style={{ backgroundColor: '#6366f1' }}>
                {c.full_name?.charAt(0)}
              </div>
              <button className="text-sm text-gray-700 hover:text-brand-600 truncate" onClick={() => router.push(`/member/${c.id}`)}>
                {c.full_name}
              </button>
              <span className={`badge text-[10px] ${getStatusColor(c.status)}`}>{getStatusLabel(c.status)}</span>
            </div>
            {renderStructure(c.id, depth + 1)}
          </div>
        ))}
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto space-y-5">
      <button onClick={() => router.back()} className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700">
        <ArrowLeft size={16} /> Back
      </button>

      <div className="card p-5 flex items-start justify-between gap-4 flex-wrap">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-full flex items-center justify-center text-white text-xl font-bold flex-shrink-0"
            style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
            {target.profile_picture ? (
              <img src={target.profile_picture} alt={target.full_name} className="w-16 h-16 rounded-full object-cover" />
            ) : target.full_name?.charAt(0)}
          </div>
          <div>
            <h1 className="text-lg font-bold text-gray-900">{target.full_name}</h1>
            <p className="text-xs text-gray-400">{target.member_id ?? 'No ID yet'} · {cg?.name ?? 'No group'}</p>
            <span className={`badge text-xs mt-1 ${getStatusColor(target.status)}`}>{getStatusLabel(target.status)}</span>
            {target.sponsor && (
              <p className="text-xs text-gray-400 mt-1">Sponsor: {target.sponsor.full_name}</p>
            )}
          </div>
        </div>
        {canEdit && (
          <button onClick={() => setEditing(v => !v)} className="btn-secondary text-sm flex items-center gap-1.5">
            <Pencil size={14} /> {editing ? 'Cancel' : 'Edit'}
          </button>
        )}
      </div>

      {editing && canEdit && (
        <div className="card p-5 space-y-3">
          <div>
            <label className="text-xs text-gray-500">Full Name</label>
            <input className="input" value={form.full_name} onChange={e => setForm(f => ({ ...f, full_name: e.target.value }))} />
          </div>
          <div>
            <label className="text-xs text-gray-500">Status</label>
            <select className="input" value={form.status} onChange={e => setForm(f => ({ ...f, status: e.target.value as any }))}>
              {STATUS_ORDER.map(s => <option key={s} value={s}>{getStatusLabel(s)}</option>)}
            </select>
          </div>
          <div>
            <label className="text-xs text-gray-500">Current Week (12-week program)</label>
            <input type="number" min={1} max={12} className="input" value={form.week_number}
              onChange={e => setForm(f => ({ ...f, week_number: Number(e.target.value) }))} />
          </div>
          <button className="btn-primary text-sm" disabled={saving} onClick={save}>
            {saving ? 'Saving…' : 'Save Changes'}
          </button>
          {msg && <p className={`text-xs ${msg.type === 'success' ? 'text-green-600' : 'text-red-600'}`}>{msg.text}</p>}
          <p className="text-xs text-gray-400">To change color, sponsor, or profile picture, use the People page.</p>
        </div>
      )}

      {/* Range filter */}
      <div className="flex gap-2 flex-wrap">
        {RANGES.map(r => (
          <button key={r.value} onClick={() => changeRange(r.value)}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${range === r.value ? 'bg-brand-600 text-white' : 'bg-white border border-gray-200 text-gray-600 hover:border-brand-300'}`}>
            {r.label}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <StatCard icon={<TrendingUp size={16} />} label="Earnings" value={formatCurrency(totalEarnings)} />
        <StatCard icon={<Target size={16} />} label="Businesses Scouted" value={scoutingCount} />
        <StatCard icon={<Users size={16} />} label="Team Size" value={teamSize} />
        <StatCard icon={<Zap size={16} />} label="Members Start" value={memberStartsThisMonth} sub="this month, direct" />
        <StatCard icon={<Users size={16} />} label="Team Starts" value={teamStartsThisMonth} sub="this month" />
        <StatCard icon={<Star size={16} />} label="Consistency Points" value={totalPoints} sub="all time" />
      </div>

      <div className="card p-5">
        <h2 className="text-sm font-semibold text-gray-900 mb-3">Team Structure</h2>
        {fullDownline.length === 0 ? (
          <p className="text-sm text-gray-400">No downline yet.</p>
        ) : renderStructure(target.id)}
      </div>
    </div>
  )
}

function StatCard({ icon, label, value, sub }: { icon: React.ReactNode; label: string; value: string | number; sub?: string }) {
  return (
    <div className="card p-4">
      <div className="flex items-center gap-2 text-gray-400 mb-1.5">{icon}<span className="text-xs font-medium">{label}</span></div>
      <div className="text-xl font-bold text-gray-900">{value}</div>
      {sub && <div className="text-xs text-gray-400 mt-0.5">{sub}</div>}
    </div>
  )
}
