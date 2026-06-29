'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Profile } from '@/lib/types'
import { getStatusLabel, getStatusColor, isSmOrAbove } from '@/lib/utils'
import { Users, ChevronDown, ChevronRight, Search } from 'lucide-react'

export default function TeamClient({
  profile, isAdmin, myTeam, mySmTeam, directDownlines, allProfiles, viewingMember,
}: {
  profile: Profile
  isAdmin: boolean
  myTeam: Profile[]
  mySmTeam: Profile[]
  directDownlines: Profile[]
  allProfiles: Profile[]
  viewingMember: Profile | null
}) {
  const router = useRouter()
  const [tab, setTab] = useState<'all' | 'sm-team' | 'direct' | 'tree'>('all')
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [expandedTree, setExpandedTree] = useState<Set<string>>(new Set())
  const [memberSearch, setMemberSearch] = useState('')
  const [memberOptions, setMemberOptions] = useState<Profile[]>([])

  const isSm = isSmOrAbove(profile.status)

  function filtered(list: Profile[]) {
    return list.filter(p => {
      const matchSearch = !search ||
        p.full_name.toLowerCase().includes(search.toLowerCase()) ||
        (p.member_id ?? '').toLowerCase().includes(search.toLowerCase())
      const matchStatus = statusFilter === 'all' || p.status === statusFilter
      return matchSearch && matchStatus
    })
  }

  function searchMembers(q: string) {
    setMemberSearch(q)
    if (q.length < 2) { setMemberOptions([]); return }
    const matches = allProfiles.filter(p =>
      p.full_name.toLowerCase().includes(q.toLowerCase()) ||
      (p.member_id ?? '').toLowerCase().includes(q.toLowerCase())
    ).slice(0, 8)
    setMemberOptions(matches)
  }

  function toggleTree(id: string) {
    setExpandedTree(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  function renderTree(parentId: string, depth = 0): React.ReactNode {
    const children = allProfiles.filter(p => p.sponsor_id === parentId)
    if (!children.length) return null
    return children.map(p => {
      const hasChildren = allProfiles.some(c => c.sponsor_id === p.id)
      const expanded = expandedTree.has(p.id)
      return (
        <div key={p.id} style={{ marginLeft: depth * 20 }}>
          <div className={`flex items-center gap-2 py-2 px-3 rounded-lg hover:bg-gray-50 group ${depth === 0 ? 'border-l-2 border-brand-200' : 'border-l border-gray-200'}`}>
            <button
              onClick={() => toggleTree(p.id)}
              className={`w-5 h-5 flex items-center justify-center flex-shrink-0 ${hasChildren ? 'text-gray-400 hover:text-gray-600' : 'text-transparent'}`}
            >
              {hasChildren ? (expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />) : null}
            </button>
            <div
              className="w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0"
              style={{ backgroundColor: (p as any).color_groups?.hex_color ?? '#4f46e5' }}
            >
              {p.full_name.slice(0, 1).toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-sm font-medium truncate">{p.full_name}</div>
              <div className="text-xs text-gray-400">{p.member_id ?? '—'}</div>
            </div>
            <span className={`badge text-xs ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
            <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: (p as any).color_groups?.hex_color ?? '#ccc' }} title={(p as any).color_groups?.name} />
          </div>
          {expanded && renderTree(p.id, depth + 1)}
        </div>
      )
    })
  }

  const tabs = [
    { id: 'all', label: `All Team (${myTeam.length})` },
    { id: 'sm-team', label: `SM Team (${mySmTeam.length})`, hidden: !isSm && !isAdmin },
    { id: 'direct', label: `Direct (${directDownlines.length})` },
    { id: 'tree', label: 'Structure' },
  ].filter(t => !t.hidden)

  const PersonRow = ({ p }: { p: Profile }) => (
    <tr className="table-row">
      <td className="table-td">
        <div className="flex items-center gap-2.5">
          <div
            className="w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0"
            style={{ backgroundColor: (p as any).color_groups?.hex_color ?? '#4f46e5' }}
          >
            {p.full_name.slice(0, 1)}
          </div>
          <div>
            <div className="font-medium text-sm">{p.full_name}</div>
            <div className="text-xs text-gray-400">{p.email}</div>
          </div>
        </div>
      </td>
      <td className="table-td text-gray-400">{p.member_id ?? '—'}</td>
      <td className="table-td"><span className={`badge ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span></td>
      <td className="table-td">
        {(p as any).color_groups ? (
          <div className="flex items-center gap-1.5 text-sm">
            <div className="w-3 h-3 rounded-full" style={{ backgroundColor: (p as any).color_groups.hex_color }} />
            {(p as any).color_groups.name}
          </div>
        ) : '—'}
      </td>
      <td className="table-td text-xs text-gray-400">{(p as any).sponsor?.full_name ?? '—'}</td>
      <td className="table-td">
        {['member','distributor','manager'].includes(p.status)
          ? <span className="badge bg-blue-100 text-blue-700">Wk {p.week_number}</span>
          : '—'}
      </td>
      {isAdmin && (
        <td className="table-td">
          <button
            onClick={() => router.push(`/team?member=${p.id}`)}
            className="btn-ghost btn-sm text-brand-600"
          >
            View Tree
          </button>
        </td>
      )}
    </tr>
  )

  return (
    <div className="space-y-6 max-w-6xl mx-auto">
      {/* Viewing member tree (admin) */}
      {viewingMember && isAdmin && (
        <div className="card p-4 bg-brand-50 border-brand-200">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm font-semibold text-brand-900">Viewing tree for: {viewingMember.full_name} ({viewingMember.member_id})</div>
              <div className="text-xs text-brand-700">{getStatusLabel(viewingMember.status)}</div>
            </div>
            <button onClick={() => router.push('/team')} className="btn-secondary btn-sm">Clear</button>
          </div>
        </div>
      )}

      {/* Admin: search for any member tree */}
      {isAdmin && (
        <div className="card p-4">
          <label className="label">View any member&apos;s team structure</label>
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              className="input pl-8"
              placeholder="Search member name or ID…"
              value={memberSearch}
              onChange={e => searchMembers(e.target.value)}
            />
          </div>
          {memberOptions.length > 0 && (
            <div className="mt-1 border border-gray-200 rounded-lg overflow-hidden shadow-sm">
              {memberOptions.map(m => (
                <button
                  key={m.id}
                  onClick={() => { router.push(`/team?member=${m.id}`); setMemberOptions([]); setMemberSearch('') }}
                  className="w-full text-left px-4 py-2.5 text-sm hover:bg-gray-50 border-b border-gray-100 last:border-0"
                >
                  <span className="font-medium">{m.full_name}</span>
                  <span className="text-gray-400 ml-2">{m.member_id} · {getStatusLabel(m.status)}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
        {tabs.map(t => (
          <button
            key={t.id}
            onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Filters */}
      {tab !== 'tree' && (
        <div className="flex gap-3">
          <div className="relative flex-1 max-w-xs">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input className="input pl-8 py-2" placeholder="Search…" value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <select className="input w-auto" value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
            <option value="all">All Statuses</option>
            {['member','distributor','manager','senior_manager','executive_manager','director'].map(s => (
              <option key={s} value={s}>{getStatusLabel(s as any)}</option>
            ))}
          </select>
        </div>
      )}

      {/* Tables */}
      {tab !== 'tree' && (
        <div className="card overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="border-b border-gray-100">
              <tr>
                <th className="table-th">Name</th>
                <th className="table-th">ID</th>
                <th className="table-th">Status</th>
                <th className="table-th">Group</th>
                <th className="table-th">Sponsor</th>
                <th className="table-th">Week</th>
                {isAdmin && <th className="table-th">Tree</th>}
              </tr>
            </thead>
            <tbody>
              {filtered(
                tab === 'all' ? myTeam :
                tab === 'sm-team' ? mySmTeam :
                directDownlines
              ).map(p => <PersonRow key={p.id} p={p} />)}
            </tbody>
          </table>
        </div>
      )}

      {/* Tree view */}
      {tab === 'tree' && (
        <div className="card p-5">
          <h2 className="section-title mb-4">
            {viewingMember ? `${viewingMember.full_name}'s Team Structure` : 'My Team Structure'}
          </h2>
          <div className="space-y-1">
            {renderTree(viewingMember?.id ?? profile.id)}
          </div>
          {!myTeam.length && (
            <p className="text-sm text-gray-400 text-center py-8">No team members yet</p>
          )}
        </div>
      )}
    </div>
  )
}
