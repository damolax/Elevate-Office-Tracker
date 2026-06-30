'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ColorGroup, ActivityStatus } from '@/lib/types'
import { getStatusLabel, getStatusColor, formatDate } from '@/lib/utils'
import { ACTIVITY_STATUS_LABELS, ACTIVITY_STATUS_COLORS } from '@/lib/types'
import { Check, X, Search, ChevronDown, ChevronRight } from 'lucide-react'

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
  const [tab, setTab] = useState<'pending' | 'all' | 'tree' | 'weeks' | 'add'>('pending')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [weekFilter, setWeekFilter] = useState<number | 'all'>('all')
  const [loading, setLoading] = useState<string | null>(null)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [selectedProfile, setSelectedProfile] = useState<Profile | null>(null)
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  const [confirmAction, setConfirmAction] = useState<{ type: 'approve' | 'reject'; profile: Profile } | null>(null)
  const [rejectReason, setRejectReason] = useState('')
  const [addForm, setAddForm] = useState({
    full_name: '', email: '', phone: '', status: 'member',
    color_group_id: '', sponsor_id: '', week_number: 1, is_new_member: false,
  })
  const [addLoading, setAddLoading] = useState(false)

  // For directors: hide main admin
  const visibleProfiles = isMainAdmin
    ? allProfiles
    : allProfiles.filter(p => p.id !== mainAdminId)

  // Build downline recursively
  function getDownline(rootId: string, profiles: Profile[]): string[] {
    const direct = profiles.filter(p => p.sponsor_id === rootId).map(p => p.id)
    return [...direct, ...direct.flatMap(id => getDownline(id, profiles))]
  }

  const myDownlineIds = isMainAdmin
    ? allProfiles.map(p => p.id)
    : [currentProfile.id, ...getDownline(currentProfile.id, allProfiles)]

  const treeProfiles = visibleProfiles.filter(p => myDownlineIds.includes(p.id))

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
    const { error } = await supabase.from('profiles').update({ approved: true, rejected: false, member_id: memberId }).eq('id', p.id)
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: `✓ Approved! Member ID: ${memberId ?? 'N/A'}` })
      if (!isMainAdmin) {
        fetch('/api/notify-admin-approval', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ approved_by_name: currentProfile.full_name, new_member_name: p.full_name, new_member_email: p.email, new_member_status: p.status, member_id: memberId }),
        }).catch(() => {})
      }
      setTimeout(() => window.location.reload(), 1500)
    }
    setConfirmAction(null)
    setLoading(null)
  }

  async function confirmReject(p: Profile) {
    setLoading(p.id)
    const supabase = createClient()
    await supabase.from('profiles').update({ rejected: true, rejection_reason: rejectReason || null }).eq('id', p.id)
    setMsg({ type: 'success', text: `${p.full_name} rejected. They can re-apply anytime.` })
    setConfirmAction(null)
    setRejectReason('')
    setTimeout(() => window.location.reload(), 1200)
    setLoading(null)
  }

  async function updateProfile(profileId: string, updates: Record<string, unknown>) {
    const supabase = createClient()
    const { error } = await supabase.from('profiles').update(updates).eq('id', profileId)
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: 'Updated!' })
      if (selectedProfile?.id === profileId) {
        setSelectedProfile(prev => prev ? { ...prev, ...updates } as Profile : null)
      }
      setTimeout(() => window.location.reload(), 800)
    }
  }

  async function addMemberManually() {
    setAddLoading(true)
    setMsg(null)
    const tempPassword = `Elevate${Math.random().toString(36).slice(2, 8).toUpperCase()}!`
    const res = await fetch('/api/admin/create-user', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...addForm, temp_password: tempPassword }),
    })
    const result = await res.json()
    if (!res.ok) setMsg({ type: 'error', text: result.error ?? 'Failed' })
    else { setMsg({ type: 'success', text: `Created! Temp password: ${tempPassword}` }); setTab('all'); setTimeout(() => window.location.reload(), 2000) }
    setAddLoading(false)
  }

  const filtered = visibleProfiles.filter(p => {
    const matchSearch = !search || p.full_name.toLowerCase().includes(search.toLowerCase()) || (p.member_id ?? '').toLowerCase().includes(search.toLowerCase()) || p.email.toLowerCase().includes(search.toLowerCase())
    const matchStatus = statusFilter === 'all' || (statusFilter === 'approved' && p.approved) || (statusFilter === 'pending' && !p.approved && !p.rejected) || (statusFilter === 'rejected' && p.rejected) || statusFilter === p.status || statusFilter === (p as any).activity_status
    return matchSearch && matchStatus
  })

  const weekFiltered = treeProfiles.filter(p =>
    weekFilter === 'all' || p.week_number === weekFilter
  )

  function TreeNode({ profileId, depth = 0 }: { profileId: string; depth?: number }) {
    const p = treeProfiles.find(x => x.id === profileId)
    if (!p) return null
    const children = treeProfiles.filter(x => x.sponsor_id === profileId)
    const isExpanded = expandedNodes.has(profileId)
    return (
      <div className={depth > 0 ? 'ml-5 border-l-2 border-gray-100 pl-3' : ''}>
        <div className={`flex items-center gap-2 p-2.5 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors ${selectedProfile?.id === profileId ? 'bg-brand-50 border border-brand-200' : ''}`}
          onClick={() => setSelectedProfile(p)}>
          {children.length > 0 ? (
            <button onClick={e => { e.stopPropagation(); setExpandedNodes(prev => { const n = new Set(prev); n.has(profileId) ? n.delete(profileId) : n.add(profileId); return n }) }} className="text-gray-400 hover:text-gray-600 flex-shrink-0">
              {isExpanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
            </button>
          ) : <div className="w-3.5 flex-shrink-0" />}
          <div className="w-7 h-7 rounded-lg flex-shrink-0 flex items-center justify-center text-white text-xs font-bold" style={{ backgroundColor: (p as any).color_groups?.hex_color ?? '#4f46e5' }}>
            {p.full_name.slice(0, 1)}
          </div>
          <div className="flex-1 min-w-0">
            <div className="font-medium text-sm text-gray-900 truncate">{p.full_name}</div>
            <div className="text-xs text-gray-400">{p.member_id} · Wk {p.week_number} · {getStatusLabel(p.status)}</div>
          </div>
          {children.length > 0 && <span className="text-xs text-gray-400 flex-shrink-0">{children.length}</span>}
        </div>
        {isExpanded && children.map(c => <TreeNode key={c.id} profileId={c.id} depth={depth + 1} />)}
      </div>
    )
  }

  const treeRoots = treeProfiles.filter(p => !p.sponsor_id || !treeProfiles.find(x => x.id === p.sponsor_id))
  const weekCounts = Array.from({ length: 12 }, (_, i) => i + 1).map(w => ({ week: w, count: treeProfiles.filter(p => p.week_number === w && ['member','distributor','manager'].includes(p.status)).length }))

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      {msg && <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>{msg.text}</div>}

      {/* Confirm Dialog */}
      {confirmAction && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl p-6 max-w-md w-full shadow-xl">
            <h3 className="font-bold text-lg mb-2">
              {confirmAction.type === 'approve' ? '✓ Confirm Approval' : '✗ Confirm Rejection'}
            </h3>
            <p className="text-gray-600 text-sm mb-4">
              {confirmAction.type === 'approve'
                ? `Approve ${confirmAction.profile.full_name}? This will assign them a Member ID and give them access to the app.`
                : `Reject ${confirmAction.profile.full_name}? They can re-apply at any time.`}
            </p>
            {confirmAction.type === 'reject' && (
              <div className="mb-4">
                <label className="label">Reason for rejection (optional)</label>
                <textarea className="input resize-none" rows={2} value={rejectReason} onChange={e => setRejectReason(e.target.value)} placeholder="e.g. Incomplete information..." />
              </div>
            )}
            {!confirmAction.profile.color_group_id && confirmAction.type === 'approve' && (
              <div className="mb-4">
                <label className="label">Assign color group first</label>
                <select className="input" onChange={e => updateProfile(confirmAction.profile.id, { color_group_id: e.target.value })}>
                  <option value="">Select color group…</option>
                  {colorGroups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
                </select>
              </div>
            )}
            <div className="flex gap-3">
              <button onClick={() => { setConfirmAction(null); setRejectReason('') }} className="btn-secondary flex-1">Cancel</button>
              <button
                onClick={() => confirmAction.type === 'approve' ? confirmApprove(confirmAction.profile) : confirmReject(confirmAction.profile)}
                disabled={!!loading}
                className={`flex-1 ${confirmAction.type === 'approve' ? 'btn-primary' : 'btn-danger'}`}>
                {loading ? 'Processing…' : confirmAction.type === 'approve' ? 'Confirm Approve' : 'Confirm Reject'}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {[
          { id: 'pending', label: `Pending (${pendingProfiles.length})` },
          { id: 'all', label: `All People (${visibleProfiles.length})` },
          { id: 'tree', label: 'Team Tree' },
          { id: 'weeks', label: 'By Week' },
          ...(isMainAdmin ? [{ id: 'add', label: 'Add Member' }] : []),
        ].map(t => (
          <button key={t.id} onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* PENDING */}
      {tab === 'pending' && (
        <div className="space-y-3">
          {!isMainAdmin && <div className="card p-3 bg-blue-50 border-blue-200 text-blue-700 text-sm">You can approve members. The main admin is notified by email when you approve someone.</div>}
          {pendingProfiles.length === 0 ? (
            <div className="card p-8 text-center text-gray-400">No pending approvals</div>
          ) : pendingProfiles.map(p => (
            <div key={p.id} className="card p-5">
              <div className="flex items-start justify-between gap-4 flex-wrap">
                <div>
                  <div className="font-semibold text-gray-900">{p.full_name}</div>
                  <div className="text-sm text-gray-500">{p.email} · {p.phone}</div>
                  <div className="flex items-center gap-2 mt-2 flex-wrap">
                    <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                    {(p as any).color_groups ? (
                      <span className="flex items-center gap-1 text-xs text-gray-500">
                        <div className="w-3 h-3 rounded-full" style={{ backgroundColor: (p as any).color_groups.hex_color }} />{(p as any).color_groups.name}
                      </span>
                    ) : <span className="badge bg-gray-100 text-gray-500">No color yet</span>}
                    {p.is_new_member && <span className="badge bg-brand-100 text-brand-700">New Member</span>}
                  </div>
                  {(p as any).sponsor && <div className="text-xs text-gray-400 mt-1">Sponsor: {(p as any).sponsor.full_name} ({(p as any).sponsor.member_id})</div>}
                  {p.is_office_already !== undefined && <div className="text-xs text-gray-400">Office: {p.is_office_already ? 'Was already coming' : 'New this month'}</div>}
                  <div className="text-xs text-gray-400">Applied: {formatDate(p.created_at)}</div>
                </div>
                <div className="flex gap-2 flex-shrink-0">
                  <button onClick={() => setConfirmAction({ type: 'approve', profile: p })} className="btn-primary btn-sm flex items-center gap-1"><Check size={14} /> Approve</button>
                  <button onClick={() => setConfirmAction({ type: 'reject', profile: p })} className="btn-danger btn-sm flex items-center gap-1"><X size={14} /> Reject</button>
                </div>
              </div>
              {!p.color_group_id && (
                <div className="mt-3 pt-3 border-t border-gray-100">
                  <div className="text-xs text-gray-500 mb-2">Assign color group before approving:</div>
                  <div className="flex gap-2 flex-wrap">
                    {colorGroups.map(g => (
                      <button key={g.id} onClick={() => updateProfile(p.id, { color_group_id: g.id })}
                        className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-gray-200 text-xs font-medium hover:border-brand-400 transition-colors">
                        <div className="w-3 h-3 rounded-full" style={{ backgroundColor: g.hex_color }} />{g.name}
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* ALL PEOPLE */}
      {tab === 'all' && (
        <div className="space-y-4">
          <div className="flex gap-3 flex-wrap">
            <div className="relative flex-1 min-w-48">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input className="input pl-9" placeholder="Search name, ID, email…" value={search} onChange={e => setSearch(e.target.value)} />
            </div>
            <select className="input w-44" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
              <option value="all">All</option>
              <option value="approved">Approved</option>
              <option value="pending">Pending</option>
              <option value="rejected">Rejected</option>
              <optgroup label="Role">
                <option value="member">Member</option>
                <option value="distributor">Distributor</option>
                <option value="manager">Manager</option>
                <option value="senior_manager">Senior Manager</option>
                <option value="executive_manager">Executive Manager</option>
                <option value="director">Director</option>
              </optgroup>
              <optgroup label="Activity">
                <option value="active">Active</option>
                <option value="suspended">Suspended</option>
                <option value="inactive">Inactive</option>
                <option value="left_office">Left Office</option>
                <option value="another_location">Another Location</option>
                <option value="moved_to_another_office">Moved Office</option>
              </optgroup>
            </select>
          </div>

          <div className="space-y-2">
            {filtered.map(p => (
              <div key={p.id} className="card p-4 flex items-center gap-3 cursor-pointer hover:border-brand-300 transition-colors"
                onClick={() => setSelectedProfile(selectedProfile?.id === p.id ? null : p)}>
                <div className="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden">
                  {p.profile_picture ? (
                    <img src={p.profile_picture} alt={p.full_name} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-white font-bold" style={{ backgroundColor: (p as any).color_groups?.hex_color ?? '#4f46e5' }}>
                      {p.full_name.slice(0, 1)}
                    </div>
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-gray-900">{p.full_name}</div>
                  <div className="text-xs text-gray-400">{p.member_id ?? 'No ID'} · {p.email}</div>
                </div>
                <div className="flex items-center gap-2 flex-shrink-0 flex-wrap justify-end">
                  <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                  {(p as any).activity_status && (p as any).activity_status !== 'active' && (
                    <span className={`badge ${ACTIVITY_STATUS_COLORS[(p as any).activity_status as ActivityStatus] ?? 'bg-gray-100 text-gray-500'}`}>
                      {ACTIVITY_STATUS_LABELS[(p as any).activity_status as ActivityStatus] ?? (p as any).activity_status}
                    </span>
                  )}
                  {!p.approved && !p.rejected && <span className="badge bg-amber-100 text-amber-700">Pending</span>}
                  {p.rejected && <span className="badge bg-red-100 text-red-700">Rejected</span>}
                </div>
              </div>
            ))}
            {filtered.length === 0 && <div className="card p-8 text-center text-gray-400">No members found</div>}
          </div>

          {/* Profile detail panel */}
          {selectedProfile && (
            <div className="card p-5 border-brand-200">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-xl overflow-hidden flex-shrink-0">
                    {selectedProfile.profile_picture ? (
                      <img src={selectedProfile.profile_picture} alt={selectedProfile.full_name} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-white font-bold" style={{ backgroundColor: (selectedProfile as any).color_groups?.hex_color ?? '#4f46e5' }}>
                        {selectedProfile.full_name.slice(0, 1)}
                      </div>
                    )}
                  </div>
                  <div>
                    <div className="font-bold text-gray-900">{selectedProfile.full_name}</div>
                    <div className="text-sm text-gray-400">{selectedProfile.member_id} · {selectedProfile.email}</div>
                  </div>
                </div>
                <button onClick={() => setSelectedProfile(null)} className="text-gray-400 hover:text-gray-600"><X size={18} /></button>
              </div>

              <div className="grid grid-cols-2 gap-2 text-sm mb-4">
                {[
                  { label: 'Status', value: getStatusLabel(selectedProfile.status) },
                  { label: 'Week', value: `Week ${selectedProfile.week_number}` },
                  { label: 'Color Group', value: (selectedProfile as any).color_groups?.name ?? 'None' },
                  { label: 'Phone', value: selectedProfile.phone ?? '—' },
                  { label: 'Joined', value: formatDate(selectedProfile.created_at) },
                  { label: 'Sponsor', value: (selectedProfile as any).sponsor?.full_name ?? '—' },
                ].map(({ label, value }) => (
                  <div key={label} className="bg-gray-50 rounded-lg p-2.5">
                    <div className="text-xs text-gray-400">{label}</div>
                    <div className="font-medium text-gray-900 mt-0.5 text-sm">{value}</div>
                  </div>
                ))}
              </div>

              <div className="space-y-2">
                <div className="flex gap-2 flex-wrap">
                  <select className="input py-1.5 text-sm w-44" value={selectedProfile.status}
                    onChange={e => updateProfile(selectedProfile.id, { status: e.target.value })}>
                    {['member','distributor','manager','senior_manager','executive_manager','director'].map(s => (
                      <option key={s} value={s}>{getStatusLabel(s as any)}</option>
                    ))}
                  </select>
                  <select className="input py-1.5 text-sm w-44" value={(selectedProfile as any).activity_status ?? 'active'}
                    onChange={e => updateProfile(selectedProfile.id, { activity_status: e.target.value })}>
                    {ACTIVITY_OPTIONS.map(s => <option key={s} value={s}>{ACTIVITY_STATUS_LABELS[s]}</option>)}
                  </select>
                </div>
                <div className="flex gap-2 flex-wrap">
                  <select className="input py-1.5 text-sm w-44" value={selectedProfile.color_group_id ?? ''}
                    onChange={e => updateProfile(selectedProfile.id, { color_group_id: e.target.value || null })}>
                    <option value="">No color group</option>
                    {colorGroups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
                  </select>
                  <input type="number" min={1} max={12} className="input py-1.5 text-sm w-24"
                    value={selectedProfile.week_number}
                    onChange={e => updateProfile(selectedProfile.id, { week_number: parseInt(e.target.value) })}
                    placeholder="Week #" />
                </div>
                {!selectedProfile.approved && !selectedProfile.rejected && (
                  <div className="flex gap-2">
                    <button onClick={() => setConfirmAction({ type: 'approve', profile: selectedProfile })} className="btn-primary btn-sm">Approve</button>
                    <button onClick={() => setConfirmAction({ type: 'reject', profile: selectedProfile })} className="btn-danger btn-sm">Reject</button>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      )}

      {/* TREE */}
      {tab === 'tree' && (
        <div className="grid md:grid-cols-2 gap-4">
          <div className="card p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="section-title">{isMainAdmin ? 'Full Team Structure' : 'My Team'}</h2>
              <span className="text-xs text-gray-400">{treeProfiles.length} members</span>
            </div>
            <div className="space-y-1 max-h-[600px] overflow-y-auto">
              {treeRoots.length === 0 ? <p className="text-sm text-gray-400 text-center py-8">No team members yet</p>
                : treeRoots.map(p => <TreeNode key={p.id} profileId={p.id} />)}
            </div>
          </div>
          {selectedProfile && (
            <div className="card p-4">
              <div className="flex items-center justify-between mb-3">
                <h2 className="section-title">{selectedProfile.full_name}</h2>
                <button onClick={() => setSelectedProfile(null)} className="text-gray-400"><X size={16} /></button>
              </div>
              <div className="space-y-1.5 text-sm">
                {[
                  { label: 'Member ID', value: selectedProfile.member_id ?? 'Pending' },
                  { label: 'Role', value: getStatusLabel(selectedProfile.status) },
                  { label: 'Activity', value: ACTIVITY_STATUS_LABELS[(selectedProfile as any).activity_status as ActivityStatus] ?? 'Active' },
                  { label: 'Week', value: `Week ${selectedProfile.week_number}` },
                  { label: 'Color Group', value: (selectedProfile as any).color_groups?.name ?? 'None' },
                  { label: 'Email', value: selectedProfile.email },
                  { label: 'Sponsor', value: (selectedProfile as any).sponsor?.full_name ?? '—' },
                  { label: 'Joined', value: formatDate(selectedProfile.created_at) },
                ].map(({ label, value }) => (
                  <div key={label} className="flex justify-between py-1.5 border-b border-gray-50">
                    <span className="text-gray-400">{label}</span>
                    <span className="font-medium text-gray-900 text-right max-w-40 truncate">{value}</span>
                  </div>
                ))}
              </div>
              <div className="mt-3 flex gap-2">
                <select className="input py-1.5 text-sm flex-1" value={selectedProfile.week_number}
                  onChange={e => updateProfile(selectedProfile.id, { week_number: parseInt(e.target.value) })}>
                  {Array.from({ length: 12 }, (_, i) => i + 1).map(w => <option key={w} value={w}>Week {w}</option>)}
                </select>
                <select className="input py-1.5 text-sm flex-1" value={(selectedProfile as any).activity_status ?? 'active'}
                  onChange={e => updateProfile(selectedProfile.id, { activity_status: e.target.value })}>
                  {ACTIVITY_OPTIONS.map(s => <option key={s} value={s}>{ACTIVITY_STATUS_LABELS[s]}</option>)}
                </select>
              </div>
            </div>
          )}
        </div>
      )}

      {/* BY WEEK */}
      {tab === 'weeks' && (
        <div className="space-y-4">
          <div className="card p-4">
            <h2 className="section-title mb-3">Members by Week</h2>
            <div className="grid grid-cols-4 sm:grid-cols-6 gap-2 mb-4">
              <button onClick={() => setWeekFilter('all')}
                className={`py-2 rounded-lg text-sm font-medium border-2 transition-all ${weekFilter === 'all' ? 'border-brand-500 bg-brand-50 text-brand-700' : 'border-gray-200 text-gray-500 hover:border-gray-300'}`}>
                All
              </button>
              {weekCounts.map(({ week, count }) => (
                <button key={week} onClick={() => setWeekFilter(week)}
                  className={`py-2 rounded-lg text-sm font-medium border-2 transition-all relative ${weekFilter === week ? 'border-brand-500 bg-brand-50 text-brand-700' : 'border-gray-200 text-gray-500 hover:border-gray-300'}`}>
                  Wk {week}
                  {count > 0 && <span className="absolute -top-1.5 -right-1.5 bg-brand-600 text-white text-xs w-4 h-4 rounded-full flex items-center justify-center font-bold">{count}</span>}
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            {weekFiltered
              .filter(p => ['member','distributor','manager'].includes(p.status))
              .map(p => (
                <div key={p.id} className="card p-4 flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl flex-shrink-0 overflow-hidden">
                    {p.profile_picture ? (
                      <img src={p.profile_picture} alt="" className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-white font-bold text-sm" style={{ backgroundColor: (p as any).color_groups?.hex_color ?? '#4f46e5' }}>
                        {p.full_name.slice(0, 1)}
                      </div>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-sm text-gray-900">{p.full_name}</div>
                    <div className="text-xs text-gray-400">{p.member_id} · {getStatusLabel(p.status)} · {(p as any).color_groups?.name ?? 'No group'}</div>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <div className={`text-sm font-bold rounded-lg px-3 py-1 ${p.week_number >= 10 ? 'bg-green-100 text-green-700' : p.week_number >= 5 ? 'bg-brand-100 text-brand-700' : 'bg-gray-100 text-gray-600'}`}>
                      Week {p.week_number}
                    </div>
                  </div>
                </div>
              ))}
            {weekFiltered.filter(p => ['member','distributor','manager'].includes(p.status)).length === 0 && (
              <div className="card p-8 text-center text-gray-400 text-sm">
                {weekFilter === 'all' ? 'No trackable members found' : `No members currently in Week ${weekFilter}`}
              </div>
            )}
          </div>
        </div>
      )}

      {/* ADD MEMBER */}
      {tab === 'add' && isMainAdmin && (
        <div className="card p-6 max-w-lg">
          <h2 className="section-title mb-4">Add Member Manually</h2>
          <div className="space-y-3">
            <div><label className="label">Full Name *</label><input className="input" value={addForm.full_name} onChange={e => setAddForm(f => ({ ...f, full_name: e.target.value }))} /></div>
            <div><label className="label">Email *</label><input className="input" type="email" value={addForm.email} onChange={e => setAddForm(f => ({ ...f, email: e.target.value }))} /></div>
            <div><label className="label">Phone</label><input className="input" value={addForm.phone} onChange={e => setAddForm(f => ({ ...f, phone: e.target.value }))} /></div>
            <div><label className="label">Role Status</label>
              <select className="input" value={addForm.status} onChange={e => setAddForm(f => ({ ...f, status: e.target.value }))}>
                {['member','distributor','manager','senior_manager','executive_manager','director'].map(s => <option key={s} value={s}>{getStatusLabel(s as any)}</option>)}
              </select>
            </div>
            <div><label className="label">Color Group</label>
              <select className="input" value={addForm.color_group_id} onChange={e => setAddForm(f => ({ ...f, color_group_id: e.target.value }))}>
                <option value="">None</option>
                {colorGroups.map(g => <option key={g.id} value={g.id}>{g.name}</option>)}
              </select>
            </div>
            <div><label className="label">Starting Week</label>
              <input className="input" type="number" min={1} max={12} value={addForm.week_number} onChange={e => setAddForm(f => ({ ...f, week_number: parseInt(e.target.value) }))} />
            </div>
            <div className="flex items-center gap-2">
              <input type="checkbox" id="nm" checked={addForm.is_new_member} onChange={e => setAddForm(f => ({ ...f, is_new_member: e.target.checked }))} />
              <label htmlFor="nm" className="text-sm text-gray-600">Brand new member (joined this month)</label>
            </div>
            <button onClick={addMemberManually} disabled={addLoading || !addForm.full_name || !addForm.email} className="btn-primary w-full">
              {addLoading ? 'Creating…' : 'Create Member Account'}
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
