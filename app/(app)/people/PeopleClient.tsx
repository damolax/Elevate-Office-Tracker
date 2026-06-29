'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ColorGroup } from '@/lib/types'
import { getStatusLabel, getStatusColor, formatDate } from '@/lib/utils'
import { UserPlus, Check, X, Search, Filter } from 'lucide-react'

type StatusFilter = 'all' | 'pending' | 'approved' | 'rejected'

export default function PeopleClient({
  currentProfile, allProfiles, pendingProfiles, colorGroups, isMainAdmin,
}: {
  currentProfile: Profile
  allProfiles: Profile[]
  pendingProfiles: Profile[]
  colorGroups: ColorGroup[]
  isMainAdmin: boolean
}) {
  const [tab, setTab] = useState<'all' | 'pending' | 'add'>('pending')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [loading, setLoading] = useState<string | null>(null)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [selectedProfile, setSelectedProfile] = useState<Profile | null>(null)

  // Add member form
  const [addForm, setAddForm] = useState({
    full_name: '', email: '', phone: '', status: 'member',
    color_group_id: '', sponsor_id: '', upline_sm_id: '',
    week_number: 1, is_new_member: false,
  })
  const [addLoading, setAddLoading] = useState(false)

  async function approveUser(profileId: string, profile: Profile) {
    setLoading(profileId)
    setMsg(null)
    const supabase = createClient()

    // Generate member ID
    const colorGroup = colorGroups.find(g => g.id === profile.color_group_id)
    let memberId = null

    if (colorGroup) {
      const { data: seqData } = await supabase.rpc('generate_member_id', { p_color_code: colorGroup.code })
      memberId = seqData

      // Update color group count
      await supabase.from('color_groups')
        .update({ member_count: colorGroup.member_count + 1 })
        .eq('id', colorGroup.id)
    }

    const { error } = await supabase.from('profiles')
      .update({ approved: true, rejected: false, member_id: memberId })
      .eq('id', profileId)

    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: `Approved! Member ID: ${memberId ?? 'N/A'}` })
      setTimeout(() => window.location.reload(), 1500)
    }
    setLoading(null)
  }

  async function rejectUser(profileId: string, reason: string) {
    setLoading(profileId)
    const supabase = createClient()
    await supabase.from('profiles')
      .update({ rejected: true, rejection_reason: reason })
      .eq('id', profileId)
    setTimeout(() => window.location.reload(), 1000)
  }

  async function updateProfile(profileId: string, updates: Partial<Profile>) {
    const supabase = createClient()
    const { error } = await supabase.from('profiles').update(updates).eq('id', profileId)
    if (error) setMsg({ type: 'error', text: error.message })
    else { setMsg({ type: 'success', text: 'Updated!' }); setSelectedProfile(null); setTimeout(() => window.location.reload(), 1000) }
  }

  async function addMemberManually() {
    setAddLoading(true)
    setMsg(null)
    const supabase = createClient()

    // Generate temp password
    const tempPassword = `Elevate${Math.random().toString(36).slice(2, 8).toUpperCase()}!`

    // Create auth user
    const res = await fetch('/api/admin/create-user', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...addForm, temp_password: tempPassword }),
    })

    const result = await res.json()
    if (!res.ok) {
      setMsg({ type: 'error', text: result.error ?? 'Failed to create user' })
    } else {
      setMsg({ type: 'success', text: `Created! Temp password: ${tempPassword}` })
      setTab('all')
      setTimeout(() => window.location.reload(), 2000)
    }
    setAddLoading(false)
  }

  const filtered = allProfiles.filter(p => {
    const matchSearch = !search ||
      p.full_name.toLowerCase().includes(search.toLowerCase()) ||
      (p.member_id ?? '').toLowerCase().includes(search.toLowerCase()) ||
      p.email.toLowerCase().includes(search.toLowerCase())
    const matchStatus = statusFilter === 'all' ||
      (statusFilter === 'approved' && p.approved) ||
      (statusFilter === 'pending' && !p.approved && !p.rejected) ||
      (statusFilter === 'rejected' && p.rejected) ||
      statusFilter === p.status
    return matchSearch && matchStatus
  })

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      {msg && (
        <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
        {[
          { id: 'pending', label: `Pending (${pendingProfiles.length})` },
          { id: 'all', label: `All People (${allProfiles.length})` },
          { id: 'add', label: 'Add Member' },
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

      {/* Pending approvals */}
      {tab === 'pending' && (
        <div className="space-y-3">
          {pendingProfiles.length === 0 ? (
            <div className="card p-8 text-center text-gray-400">No pending approvals</div>
          ) : (
            pendingProfiles.map(p => (
              <div key={p.id} className="card p-5">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="font-semibold text-gray-900">{p.full_name}</div>
                    <div className="text-sm text-gray-500">{p.email} · {p.phone}</div>
                    <div className="flex items-center gap-2 mt-2 flex-wrap">
                      <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                      {(p as any).color_groups && (
                        <span className="flex items-center gap-1 text-xs text-gray-500">
                          <div className="w-3 h-3 rounded-full" style={{ backgroundColor: (p as any).color_groups.hex_color }} />
                          {(p as any).color_groups.name}
                        </span>
                      )}
                      {!p.color_group_id && <span className="badge bg-gray-100 text-gray-500">No color yet</span>}
                      {p.is_new_member && <span className="badge bg-brand-100 text-brand-700">New Member</span>}
                    </div>
                    {(p as any).sponsor && (
                      <div className="text-xs text-gray-400 mt-1">
                        Sponsor: {(p as any).sponsor.full_name} ({(p as any).sponsor.member_id})
                      </div>
                    )}
                    <div className="text-xs text-gray-400 mt-0.5">
                      Applied: {formatDate(p.created_at)}
                    </div>
                  </div>
                  <div className="flex gap-2 flex-shrink-0">
                    <button
                      onClick={() => approveUser(p.id, p)}
                      disabled={loading === p.id}
                      className="btn-primary btn-sm"
                    >
                      <Check size={14} /> Approve
                    </button>
                    <button
                      onClick={() => {
                        const reason = prompt('Rejection reason (optional):') ?? ''
                        rejectUser(p.id, reason)
                      }}
                      disabled={loading === p.id}
                      className="btn-danger btn-sm"
                    >
                      <X size={14} /> Reject
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {/* All people */}
      {tab === 'all' && (
        <div className="card">
          <div className="p-4 border-b border-gray-100 flex gap-3 flex-wrap">
            <div className="relative flex-1 min-w-40">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                className="input pl-8 py-2"
                placeholder="Search by name, ID, email…"
                value={search}
                onChange={e => setSearch(e.target.value)}
              />
            </div>
            <select
              className="input w-auto"
              value={statusFilter}
              onChange={e => setStatusFilter(e.target.value)}
            >
              <option value="all">All Statuses</option>
              <option value="approved">Approved</option>
              <option value="pending">Pending</option>
              <option value="rejected">Rejected</option>
              <option value="member">Members</option>
              <option value="distributor">Distributors</option>
              <option value="manager">Managers</option>
              <option value="senior_manager">Senior Managers</option>
              <option value="executive_manager">Executive Managers</option>
              <option value="director">Directors</option>
            </select>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b border-gray-100">
                <tr>
                  <th className="table-th">Name</th>
                  <th className="table-th">ID</th>
                  <th className="table-th">Status</th>
                  <th className="table-th">Group</th>
                  <th className="table-th">Sponsor</th>
                  <th className="table-th">Week</th>
                  <th className="table-th">State</th>
                  <th className="table-th">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(p => (
                  <tr key={p.id} className="table-row">
                    <td className="table-td">
                      <div className="font-medium">{p.full_name}</div>
                      <div className="text-xs text-gray-400">{p.email}</div>
                    </td>
                    <td className="table-td text-gray-500">{p.member_id ?? '—'}</td>
                    <td className="table-td">
                      <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                    </td>
                    <td className="table-td">
                      {(p as any).color_groups ? (
                        <div className="flex items-center gap-1.5">
                          <div className="w-3 h-3 rounded-full" style={{ backgroundColor: (p as any).color_groups.hex_color }} />
                          {(p as any).color_groups.name}
                        </div>
                      ) : '—'}
                    </td>
                    <td className="table-td text-gray-400 text-xs">
                      {(p as any).sponsor?.full_name ?? '—'}
                    </td>
                    <td className="table-td text-center">
                      {['member','distributor','manager'].includes(p.status) ? (
                        <span className="badge bg-blue-100 text-blue-700">Wk {p.week_number}</span>
                      ) : '—'}
                    </td>
                    <td className="table-td">
                      {p.approved ? (
                        <span className="badge bg-green-100 text-green-700">Active</span>
                      ) : p.rejected ? (
                        <span className="badge bg-red-100 text-red-700">Rejected</span>
                      ) : (
                        <span className="badge bg-yellow-100 text-yellow-700">Pending</span>
                      )}
                    </td>
                    <td className="table-td">
                      <button
                        onClick={() => setSelectedProfile(p)}
                        className="btn-ghost btn-sm text-brand-600"
                      >
                        Edit
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Edit profile modal */}
      {selectedProfile && (
        <div className="fixed inset-0 bg-black/40 z-50 flex items-center justify-center p-4">
          <div className="card w-full max-w-lg p-6 space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between">
              <h2 className="section-title">Edit {selectedProfile.full_name}</h2>
              <button onClick={() => setSelectedProfile(null)} className="btn-ghost btn-sm">✕</button>
            </div>

            <ProfileEditForm
              profile={selectedProfile}
              colorGroups={colorGroups}
              allProfiles={allProfiles}
              isMainAdmin={isMainAdmin}
              onSave={(updates) => updateProfile(selectedProfile.id, updates)}
              onClose={() => setSelectedProfile(null)}
            />
          </div>
        </div>
      )}

      {/* Add member tab */}
      {tab === 'add' && (
        <div className="card p-6 max-w-2xl">
          <h2 className="section-title mb-4">Add Member Manually</h2>
          <div className="grid grid-cols-2 gap-4">
            {[
              { key: 'full_name', label: 'Full Name', type: 'text' },
              { key: 'email', label: 'Email', type: 'email' },
              { key: 'phone', label: 'Phone', type: 'text' },
            ].map(f => (
              <div key={f.key} className={f.key === 'full_name' ? 'col-span-2' : ''}>
                <label className="label">{f.label}</label>
                <input
                  className="input"
                  type={f.type}
                  value={(addForm as any)[f.key]}
                  onChange={e => setAddForm(prev => ({ ...prev, [f.key]: e.target.value }))}
                />
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
                <option value="">Auto-assign (smallest group)</option>
                {colorGroups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
              </select>
            </div>

            <div>
              <label className="label">Week Number</label>
              <input
                className="input"
                type="number"
                min={1}
                max={12}
                value={addForm.week_number}
                onChange={e => setAddForm(p => ({ ...p, week_number: Number(e.target.value) }))}
              />
            </div>
          </div>

          {msg && (
            <div className={`mt-4 px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
              {msg.text}
            </div>
          )}

          <button
            onClick={addMemberManually}
            disabled={addLoading || !addForm.full_name || !addForm.email}
            className="btn-primary mt-4"
          >
            {addLoading ? 'Creating…' : 'Create Member'}
          </button>
        </div>
      )}
    </div>
  )
}

function ProfileEditForm({
  profile, colorGroups, allProfiles, isMainAdmin, onSave, onClose,
}: {
  profile: Profile
  colorGroups: ColorGroup[]
  allProfiles: Profile[]
  isMainAdmin: boolean
  onSave: (updates: Partial<Profile>) => void
  onClose: () => void
}) {
  const [form, setForm] = useState({
    status: profile.status,
    color_group_id: profile.color_group_id ?? '',
    week_number: profile.week_number,
    week_confirmed: profile.week_confirmed,
    approved: profile.approved,
    is_new_member: profile.is_new_member,
    sponsor_id: profile.sponsor_id ?? '',
    upline_sm_id: profile.upline_sm_id ?? '',
    is_admin: profile.is_admin,
    is_director: profile.is_director,
  })

  const checkboxes = [
    { key: 'week_confirmed', label: 'Week Confirmed' },
    { key: 'approved', label: 'Approved' },
    { key: 'is_new_member', label: 'New Member Badge' },
    { key: 'is_director', label: 'Director (Co-Admin)' },
    ...(isMainAdmin ? [{ key: 'is_admin', label: 'Full Admin' }] : []),
  ]

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="label">Status</label>
          <select className="input" value={form.status} onChange={e => setForm(p => ({ ...p, status: e.target.value as any }))}>
            {['member','distributor','manager','senior_manager','executive_manager','director'].map(s => (
              <option key={s} value={s}>{getStatusLabel(s as any)}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label">Color Group</label>
          <select className="input" value={form.color_group_id} onChange={e => setForm(p => ({ ...p, color_group_id: e.target.value }))}>
            <option value="">No group</option>
            {colorGroups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
          </select>
        </div>
        <div>
          <label className="label">Week Number (1–12)</label>
          <input className="input" type="number" min={1} max={12} value={form.week_number} onChange={e => setForm(p => ({ ...p, week_number: Number(e.target.value) }))} />
        </div>
        <div className="flex flex-col gap-2 mt-6">
          {checkboxes.map(({ key, label }) => (
            <label key={key} className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={(form as any)[key]}
                onChange={e => setForm(p => ({ ...p, [key]: e.target.checked }))}
              />
              {label}
            </label>
          ))}
        </div>
      </div>

      {(form.is_admin || form.is_director) && (
        <div className="px-3 py-2 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-700">
          {form.is_admin
            ? '⚠ Full Admin — this person will have the same access level as you.'
            : '⚠ Co-Admin (Director) — this person can manage members and content but cannot see your specific team numbers.'}
        </div>
      )}

      <div className="flex gap-3 pt-2">
        <button onClick={() => onSave(form as any)} className="btn-primary flex-1">Save Changes</button>
        <button onClick={onClose} className="btn-secondary">Cancel</button>
      </div>
    </div>
  )
}
