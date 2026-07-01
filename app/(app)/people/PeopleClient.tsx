'use client'

import { useState, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, ColorGroup, ActivityStatus } from '@/lib/types'
import { getStatusLabel, getStatusColor, formatDate } from '@/lib/utils'
import { ACTIVITY_STATUS_LABELS, ACTIVITY_STATUS_COLORS } from '@/lib/types'
import { Check, X, Search, ChevronDown, ChevronRight, Shield, UserX, UserCheck } from 'lucide-react'

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

  // Hide main admin from directors
  const visibleProfiles = isMainAdmin
    ? allProfiles
    : allProfiles.filter(p => p.id !== mainAdminId)

  // Active vs inactive split
  const activeProfiles = visibleProfiles.filter(p => p.approved && !p.rejected && p.activity_status === 'active')
  const inactiveProfiles = visibleProfiles.filter(p => p.approved && !p.rejected && p.activity_status !== 'active')
  const rejectedProfiles = visibleProfiles.filter(p => p.rejected)

  // Color group → senior manager check
  function getSeniorManagerInColor(colorGroupId: string, excludeId?: string): Profile | null {
    return visibleProfiles.find(p =>
      p.color_group_id === colorGroupId &&
      p.status === 'senior_manager' &&
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

  async function assignColor(profileId: string, colorGroupId: string, currentStatus: string) {
    // Enforce: no two senior managers in same color
    if (currentStatus === 'senior_manager') {
      const existing = getSeniorManagerInColor(colorGroupId, profileId)
      if (existing) {
        setMsg({ type: 'error', text: `${existing.full_name} is already Senior Manager in this color group. Two Senior Managers cannot share a color.` })
        return
      }
    }
    await updateProfile(profileId, { color_group_id: colorGroupId })
  }

  async function toggleCoAdmin(profileId: string, current: boolean) {
    if (!isMainAdmin) return
    await updateProfile(profileId, { is_co_admin: !current })
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
              <div className="font-bold text-gray-900">{p.full_name}</div>
              <div className="text-sm text-gray-400">{p.member_id ?? 'No ID'} · {p.email}</div>
              <div className="flex gap-1.5 mt-1 flex-wrap">
                <span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                <span className={`badge ${ACTIVITY_STATUS_COLORS[actStatus]}`}>{ACTIVITY_STATUS_LABELS[actStatus]}</span>
                {p.is_co_admin && <span className="badge bg-purple-100 text-purple-700">Co-Admin</span>}
              </div>
            </div>
          </div>
          <div className="flex gap-2">
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
              <select className="input" value={p.color_group_id ?? ''} onChange={e => assignColor(p.id, e.target.value, p.status)}>
                <option value="">No group</option>
                {colorGroups.map(g => {
                  const smInGroup = getSeniorManagerInColor(g.id, p.id)
                  const blocked = p.status === 'senior_manager' && !!smInGroup
                  return (
                    <option key={g.id} value={g.id} disabled={blocked}>
                      {g.name}{blocked ? ` (SM: ${smInGroup!.full_name})` : ''}
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

        {/* Co-admin toggle — main admin only */}
        {isMainAdmin && p.id !== currentProfile.id && (
          <div className="flex items-center gap-3 pt-2 border-t border-gray-100">
            <Shield size={15} className="text-purple-500" />
            <span className="text-sm text-gray-700 flex-1">Co-Admin Access</span>
            <button onClick={() => toggleCoAdmin(p.id, p.is_co_admin)}
              className={`px-3 py-1 rounded-lg text-xs font-semibold transition-all ${p.is_co_admin ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-purple-50'}`}>
              {p.is_co_admin ? 'Remove Co-Admin' : 'Make Co-Admin'}
            </button>
          </div>
        )}
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
              <div key={p.id} onClick={() => setSelectedProfile(p === selectedProfile ? null : p)} className="cursor-pointer">
                {selectedProfile?.id === p.id
                  ? <ProfileCard p={p} />
                  : (
                    <div className="card p-4 flex items-center gap-3 hover:shadow-md transition-shadow">
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
                    </div>
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
              <div key={p.id} onClick={() => setSelectedProfile(p === selectedProfile ? null : p)} className="cursor-pointer">
                {selectedProfile?.id === p.id
                  ? <ProfileCard p={p} />
                  : (
                    <div className="card p-4 flex items-center gap-3 opacity-70 hover:opacity-100 transition-opacity">
                      <div className="w-9 h-9 rounded-full bg-gray-300 flex items-center justify-center font-bold text-white text-sm flex-shrink-0">
                        {p.full_name.charAt(0)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="font-semibold text-gray-700 truncate">{p.full_name}</div>
                        <div className="text-xs text-gray-400">{getStatusLabel(p.status)} · <span className={`${ACTIVITY_STATUS_COLORS[(p.activity_status || 'inactive') as ActivityStatus]}`}>{ACTIVITY_STATUS_LABELS[(p.activity_status || 'inactive') as ActivityStatus]}</span></div>
                      </div>
                      <ChevronRight size={16} className="text-gray-300" />
                    </div>
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
