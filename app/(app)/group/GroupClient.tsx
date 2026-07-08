'use client'

import type { Profile } from '@/lib/types'
import { getStatusLabel, getStatusColor } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function GroupClient({
  profile, groupMembers, scoutingByMember, totalGroupScouting,
}: {
  profile: Profile
  groupMembers: Profile[]
  scoutingByMember: Record<string, number>
  totalGroupScouting: number
}) {
  const router = useRouter()
  const [taskForm, setTaskForm] = useState({ title: '', description: '', assignee: '', due_date: '' })
  const [taskMsg, setTaskMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState(false)

  async function assignTask() {
    if (!taskForm.title || !taskForm.assignee) return
    setLoading(true)
    setTaskMsg(null)
    const supabase = createClient()
    const { error } = await supabase.from('tasks').insert({
      title: taskForm.title,
      description: taskForm.description || null,
      assigned_to: taskForm.assignee,
      assigned_by: profile.id,
      due_date: taskForm.due_date || null,
    })
    if (error) setTaskMsg({ type: 'error', text: error.message })
    else {
      setTaskMsg({ type: 'success', text: 'Task assigned!' })
      setTaskForm({ title: '', description: '', assignee: '', due_date: '' })
    }
    setLoading(false)
  }

  const groupColor = profile.color_groups?.hex_color ?? '#4f46e5'
  const groupName = profile.color_groups?.name ?? 'Your Group'

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Group header */}
      <div className="card p-5 flex items-center gap-4">
        <div className="w-14 h-14 rounded-2xl flex items-center justify-center text-white font-black text-xl" style={{ backgroundColor: groupColor }}>
          {groupName[0]}
        </div>
        <div>
          <div className="text-xl font-bold text-gray-900">{groupName} Group</div>
          <div className="text-sm text-gray-500">{groupMembers.length} members · {totalGroupScouting.toLocaleString()} total businesses scouted</div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Total Members', value: groupMembers.length },
          { label: 'Total Scouted', value: totalGroupScouting.toLocaleString() },
          { label: 'Active Today', value: '—' },
          { label: 'New Members', value: groupMembers.filter(m => m.is_new_member).length },
        ].map(s => (
          <div key={s.label} className="card p-4 text-center">
            <div className="text-2xl font-extrabold text-gray-900">{s.value}</div>
            <div className="text-xs text-gray-400 mt-0.5">{s.label}</div>
          </div>
        ))}
      </div>

      {/* Group members table */}
      <div className="card overflow-x-auto">
        <div className="p-4 border-b border-gray-100">
          <h2 className="section-title">Group Members</h2>
        </div>
        <table className="w-full text-sm">
          <thead className="border-b border-gray-100">
            <tr>
              <th className="table-th">Name</th>
              <th className="table-th">ID</th>
              <th className="table-th">Status</th>
              <th className="table-th">Sponsor</th>
              <th className="table-th">Week</th>
              <th className="table-th">Scouted (All Time)</th>
            </tr>
          </thead>
          <tbody>
            {groupMembers.map(m => (
              <tr key={m.id} className="table-row">
                <td className="table-td">
                  <button className="font-medium text-brand-600 hover:text-brand-700 hover:underline text-left" onClick={() => router.push(`/member/${m.id}`)}>
                    {m.full_name}
                  </button>
                  {m.is_new_member && <span className="badge bg-brand-100 text-brand-700 text-xs ml-1.5">NEW</span>}
                </td>
                <td className="table-td text-gray-400">{m.member_id ?? '—'}</td>
                <td className="table-td"><span className={`badge ${getStatusColor(m.status)}`}>{getStatusLabel(m.status)}</span></td>
                <td className="table-td text-xs text-gray-400">{(m as any).sponsor?.full_name ?? '—'}</td>
                <td className="table-td">
                  {['member','distributor','manager'].includes(m.status)
                    ? <span className="badge bg-blue-100 text-blue-700">Wk {m.week_number}</span>
                    : '—'}
                </td>
                <td className="table-td font-medium">{(scoutingByMember[m.id] ?? 0).toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Assign task */}
      <div className="card p-5">
        <h2 className="section-title mb-4">Assign Task to Group Member</h2>
        <div className="grid grid-cols-2 gap-4">
          <div className="col-span-2">
            <label className="label">Task Title *</label>
            <input className="input" value={taskForm.title} onChange={e => setTaskForm(p => ({ ...p, title: e.target.value }))} placeholder="e.g. Follow up with 5 prospects" />
          </div>
          <div className="col-span-2">
            <label className="label">Description</label>
            <textarea className="input resize-none" rows={2} value={taskForm.description} onChange={e => setTaskForm(p => ({ ...p, description: e.target.value }))} />
          </div>
          <div>
            <label className="label">Assign To *</label>
            <select className="input" value={taskForm.assignee} onChange={e => setTaskForm(p => ({ ...p, assignee: e.target.value }))}>
              <option value="">Select member…</option>
              {groupMembers.filter(m => m.id !== profile.id).map(m => (
                <option key={m.id} value={m.id}>{m.full_name} ({m.member_id})</option>
              ))}
            </select>
          </div>
          <div>
            <label className="label">Due Date</label>
            <input className="input" type="date" value={taskForm.due_date} onChange={e => setTaskForm(p => ({ ...p, due_date: e.target.value }))} />
          </div>
        </div>

        {taskMsg && (
          <div className={`mt-3 px-4 py-2.5 rounded-lg text-sm border ${taskMsg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
            {taskMsg.text}
          </div>
        )}

        <button onClick={assignTask} disabled={loading} className="btn-primary mt-4">
          {loading ? 'Assigning…' : 'Assign Task'}
        </button>
      </div>
    </div>
  )
}
