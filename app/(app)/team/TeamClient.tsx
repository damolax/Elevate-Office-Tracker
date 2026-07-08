'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Profile, UserStatus } from '@/lib/types'
import { getStatusLabel, getStatusColor, STATUS_LABELS, STATUS_ORDER, isSmOrAbove } from '@/lib/types'
import { Users, ChevronDown, ChevronRight, Search, Calendar } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { format, subDays } from 'date-fns'

export default function TeamClient({
  profile, isAdmin, myTeam, allProfiles, viewingMember,
  availableFilters, activeFilter, teamCounts,
}: {
  profile: Profile
  isAdmin: boolean
  myTeam: Profile[]
  allProfiles: Profile[]
  viewingMember: Profile | null
  availableFilters: string[]
  activeFilter: string
  teamCounts: Record<string, number>
}) {
  const router = useRouter()
  const [search, setSearch] = useState('')
  const [activityFilter, setActivityFilter] = useState('active')
  const [expandedTree, setExpandedTree] = useState<Set<string>>(new Set())
  const [selectedMember, setSelectedMember] = useState<Profile | null>(viewingMember)
  const [memberAttendance, setMemberAttendance] = useState<any[]>([])
  const [loadingAttendance, setLoadingAttendance] = useState(false)

  function filtered(list: Profile[]) {
    return list.filter(p => {
      const matchSearch = !search ||
        p.full_name.toLowerCase().includes(search.toLowerCase()) ||
        (p.member_id ?? '').toLowerCase().includes(search.toLowerCase())
      const matchActivity = activityFilter === 'all' || p.activity_status === activityFilter
      return matchSearch && matchActivity
    })
  }

  async function viewMemberAttendance(p: Profile) {
    setSelectedMember(p)
    setLoadingAttendance(true)
    const supabase = createClient()
    const from = format(subDays(new Date(), 30), 'yyyy-MM-dd')
    const { data } = await supabase
      .from('attendance')
      .select('*')
      .eq('user_id', p.id)
      .gte('date', from)
      .order('date', { ascending: false })
    setMemberAttendance(data ?? [])
    setLoadingAttendance(false)
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
      const cg = (p as any).color_groups
      return (
        <div key={p.id} style={{ marginLeft: depth * 18 }}>
          <div className="flex items-center gap-2 py-2 px-3 rounded-lg hover:bg-gray-50 group">
            <button onClick={() => toggleTree(p.id)}
              className={`w-5 h-5 flex items-center justify-center flex-shrink-0 ${hasChildren ? 'text-gray-400' : 'text-transparent'}`}>
              {hasChildren ? (expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />) : null}
            </button>
            <div className="w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0"
              style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
              {p.full_name.charAt(0)}
            </div>
            <div className="flex-1 min-w-0 cursor-pointer" onClick={() => viewMemberAttendance(p)}>
              <div className="text-sm font-medium truncate">{p.full_name}</div>
              <div className="text-xs text-gray-400">{p.member_id} · {getStatusLabel(p.status)}</div>
            </div>
            <span className={`badge text-xs ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
          </div>
          {expanded && renderTree(p.id, depth + 1)}
        </div>
      )
    })
  }

  const displayList = filtered(myTeam)

  return (
    <div className="max-w-6xl mx-auto space-y-5">
      {/* Team filter pills — one per available status level */}
      <div className="flex gap-2 flex-wrap">
        {availableFilters.map(f => (
          <button key={f} onClick={() => router.push(`/team?filter=${f}`)}
            className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${activeFilter === f ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
            {f === 'all' ? 'All Team' : getStatusLabel(f as UserStatus) + ' Team'}
            <span className="ml-1.5 opacity-70">({teamCounts[f] ?? 0})</span>
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Team list */}
        <div className="lg:col-span-2 space-y-3">
          <div className="flex gap-3 flex-wrap">
            <div className="relative flex-1 min-w-48">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input className="input pl-8" placeholder="Search name or ID…" value={search} onChange={e => setSearch(e.target.value)} />
            </div>
            <select className="input w-auto" value={activityFilter} onChange={e => setActivityFilter(e.target.value)}>
              <option value="all">All</option>
              <option value="active">Active</option>
              <option value="inactive">Inactive</option>
              <option value="suspended">Suspended</option>
            </select>
          </div>

          <div className="card divide-y divide-gray-50">
            {displayList.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No team members found</p>
            ) : displayList.map(p => {
              const cg = (p as any).color_groups
              const isSelected = selectedMember?.id === p.id
              return (
                <button key={p.id} type="button"
                  className={`w-full flex items-center gap-3 p-3 text-left hover:bg-gray-50 transition-colors ${isSelected ? 'bg-indigo-50' : ''}`}
                  onClick={() => viewMemberAttendance(p)}>
                  <div className="w-9 h-9 rounded-full flex items-center justify-center text-white text-sm font-bold flex-shrink-0"
                    style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
                    {p.full_name.charAt(0)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-sm text-gray-900 truncate">{p.full_name}</div>
                    <div className="text-xs text-gray-400">{p.member_id ?? 'No ID'} · {cg?.name ?? '—'}</div>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <span className={`badge text-xs ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                    <div className={`text-xs mt-0.5 ${p.activity_status === 'active' ? 'text-green-500' : 'text-gray-400'}`}>
                      {p.activity_status}
                    </div>
                  </div>
                </button>
              )
            })}
          </div>
        </div>

        {/* Member detail + attendance */}
        <div className="space-y-4">
          {selectedMember ? (
            <>
              <div className="card p-5">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-lg"
                      style={{ backgroundColor: (selectedMember as any).color_groups?.hex_color ?? '#6366f1' }}>
                      {selectedMember.full_name.charAt(0)}
                    </div>
                    <div>
                      <div className="font-bold text-gray-900">{selectedMember.full_name}</div>
                      <div className="text-xs text-gray-400">{selectedMember.member_id}</div>
                      <span className={`badge text-xs mt-1 ${getStatusColor(selectedMember.status)}`}>{getStatusLabel(selectedMember.status)}</span>
                    </div>
                  </div>
                </div>
                <button
                  className="w-full text-center text-xs font-semibold text-brand-600 hover:text-brand-700 bg-brand-50 rounded-lg py-2 mb-3"
                  onClick={() => router.push(`/member/${selectedMember.id}`)}>
                  View Full Profile →
                </button>
                <div className="text-xs text-gray-500 space-y-1">
                  <div>Week: {selectedMember.week_number ?? '—'}</div>
                  <div>Group: {(selectedMember as any).color_groups?.name ?? '—'}</div>
                  <div>Activity: {selectedMember.activity_status}</div>
                  {selectedMember.last_seen && (
                    <div>Last seen: {format(new Date(selectedMember.last_seen), 'MMM d, HH:mm')}</div>
                  )}
                </div>
              </div>

              <div className="card p-4">
                <div className="flex items-center gap-2 mb-3">
                  <Calendar size={15} className="text-gray-400" />
                  <span className="font-semibold text-sm text-gray-900">Last 30 Days Attendance</span>
                </div>
                {loadingAttendance ? (
                  <div className="text-xs text-gray-400 text-center py-4">Loading…</div>
                ) : memberAttendance.length === 0 ? (
                  <div className="text-xs text-gray-400 text-center py-4">No attendance in last 30 days</div>
                ) : (
                  <div className="space-y-1.5">
                    {memberAttendance.map(a => (
                      <div key={a.id} className="flex items-center justify-between text-xs">
                        <span className="text-gray-600 font-medium">{format(new Date(a.date), 'EEE, MMM d')}</span>
                        <div className="flex gap-2">
                          <span className="text-blue-600">{a.sign_in_time ? format(new Date(a.sign_in_time), 'HH:mm') : '—'}</span>
                          <span className="text-gray-400">→</span>
                          <span className="text-orange-600">{a.sign_out_time ? format(new Date(a.sign_out_time), 'HH:mm') : '—'}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="card p-6 text-center">
              <Users size={32} className="mx-auto mb-2 text-gray-300" />
              <p className="text-sm text-gray-400">Click a team member to view their details and attendance</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
