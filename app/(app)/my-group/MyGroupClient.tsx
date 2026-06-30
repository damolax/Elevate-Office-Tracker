'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, Task } from '@/lib/types'
import { getStatusLabel, getStatusColor, formatDate } from '@/lib/utils'
import { CheckCircle, Plus, X, Users, ChevronRight } from 'lucide-react'
import { format, parseISO } from 'date-fns'

export default function MyGroupClient({
  profile, groupMembers, myTasks, groupAttendance, myDownline,
}: {
  profile: Profile
  groupMembers: Profile[]
  myTasks: Task[]
  groupAttendance: any[]
  myDownline: any[]
}) {
  const [tab, setTab] = useState<'members' | 'tasks' | 'downline'>('members')
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [taskForm, setTaskForm] = useState({ title: '', description: '', assigned_to: '', due_date: '' })
  const [loading, setLoading] = useState(false)

  const groupName = profile.color_groups?.name ?? 'My Group'
  const groupColor = profile.color_groups?.hex_color ?? '#4f46e5'

  // This week attendance per member
  const weekDays = ['Mon','Tue','Wed','Thu','Fri']
  const today = new Date()
  const weekDates = Array.from({ length: 5 }, (_, i) => {
    const d = new Date(today)
    d.setDate(today.getDate() - today.getDay() + 1 + i)
    return d.toISOString().slice(0, 10)
  })

  function getAttendedDays(userId: string) {
    return groupAttendance.filter(a => a.user_id === userId).map(a => a.date)
  }

  async function createTask() {
    if (!taskForm.title || !taskForm.assigned_to) return
    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.from('tasks').insert({
      title: taskForm.title,
      description: taskForm.description || null,
      assigned_to: taskForm.assigned_to,
      assigned_by: profile.id,
      due_date: taskForm.due_date || null,
      completed: false,
    })
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: 'Task assigned!' })
      setTaskForm({ title: '', description: '', assigned_to: '', due_date: '' })
      setTimeout(() => window.location.reload(), 800)
    }
    setLoading(false)
  }

  async function completeTask(taskId: string) {
    const supabase = createClient()
    await supabase.from('tasks').update({ completed: true, completed_at: new Date().toISOString() }).eq('id', taskId)
    setMsg({ type: 'success', text: 'Task marked done' })
    setTimeout(() => window.location.reload(), 600)
  }

  async function deleteTask(taskId: string) {
    const supabase = createClient()
    await supabase.from('tasks').delete().eq('id', taskId)
    setTimeout(() => window.location.reload(), 400)
  }

  const pendingTasks = myTasks.filter(t => !t.completed)
  const doneTasks = myTasks.filter(t => t.completed)

  return (
    <div className="space-y-6 max-w-5xl mx-auto animate-fade-in">
      {msg && (
        <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      {/* Header */}
      <div className="card p-5" style={{ borderLeft: `4px solid ${groupColor}` }}>
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-xl flex items-center justify-center text-white font-extrabold text-lg" style={{ backgroundColor: groupColor }}>
            {groupName.slice(0, 1)}
          </div>
          <div>
            <h1 className="text-xl font-extrabold text-gray-900">{groupName} Group</h1>
            <p className="text-sm text-gray-400">Group Leader · {groupMembers.length} members in group · {myDownline.length} in your line</p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
        {[
          { id: 'members', label: `Group Members (${groupMembers.length})` },
          { id: 'tasks', label: `Tasks (${pendingTasks.length})` },
          { id: 'downline', label: `My Line (${myDownline.length})` },
        ].map(t => (
          <button key={t.id} onClick={() => setTab(t.id as any)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
            {t.label}
          </button>
        ))}
      </div>

      {/* GROUP MEMBERS */}
      {tab === 'members' && (
        <div className="space-y-4">
          <div className="card overflow-hidden">
            <div className="px-5 py-3 border-b border-gray-100">
              <h2 className="font-bold text-gray-900">This Week Attendance</h2>
              <p className="text-xs text-gray-400">All members in {groupName} color group</p>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="border-b border-gray-100 bg-gray-50">
                  <th className="table-th">Member</th>
                  {weekDays.map((d, i) => (
                    <th key={d} className="table-th text-center">
                      <div>{d}</div>
                      <div className="text-xs font-normal text-gray-400">{weekDates[i]?.slice(5)}</div>
                    </th>
                  ))}
                  <th className="table-th text-center">Days</th>
                </tr></thead>
                <tbody>
                  {groupMembers.map(m => {
                    const attended = getAttendedDays(m.id)
                    const total = attended.length
                    return (
                      <tr key={m.id} className="table-row">
                        <td className="table-td">
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 rounded-full flex-shrink-0 overflow-hidden">
                              {(m as any).profile_picture ? (
                                <img src={(m as any).profile_picture} alt="" className="w-full h-full object-cover" />
                              ) : (
                                <div className="w-full h-full flex items-center justify-center text-white text-xs font-bold" style={{ backgroundColor: groupColor }}>
                                  {m.full_name.slice(0, 1)}
                                </div>
                              )}
                            </div>
                            <div>
                              <div className="font-medium text-gray-900">{m.full_name}</div>
                              <div className="text-xs text-gray-400">{m.member_id}</div>
                            </div>
                          </div>
                        </td>
                        {weekDates.map(date => (
                          <td key={date} className="table-td text-center">
                            {attended.includes(date) ? (
                              <div className="w-5 h-5 bg-green-100 rounded-full flex items-center justify-center mx-auto">
                                <div className="w-2.5 h-2.5 bg-green-500 rounded-full" />
                              </div>
                            ) : (
                              <div className="w-5 h-5 bg-gray-100 rounded-full mx-auto" />
                            )}
                          </td>
                        ))}
                        <td className="table-td text-center">
                          <span className={`font-bold text-sm ${total >= 4 ? 'text-green-600' : total >= 2 ? 'text-amber-600' : 'text-red-600'}`}>
                            {total}/5
                          </span>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* TASKS */}
      {tab === 'tasks' && (
        <div className="space-y-4">
          {/* Assign task form */}
          <div className="card p-5">
            <h2 className="section-title mb-4">Assign New Task</h2>
            <div className="space-y-3">
              <div>
                <label className="label">Assign to *</label>
                <select className="input" value={taskForm.assigned_to} onChange={e => setTaskForm(f => ({ ...f, assigned_to: e.target.value }))}>
                  <option value="">Select group member…</option>
                  {groupMembers.map(m => <option key={m.id} value={m.id}>{m.full_name} ({m.member_id})</option>)}
                </select>
              </div>
              <div>
                <label className="label">Task Title *</label>
                <input className="input" value={taskForm.title} onChange={e => setTaskForm(f => ({ ...f, title: e.target.value }))} placeholder="e.g. Submit assessment by Monday" />
              </div>
              <div>
                <label className="label">Description</label>
                <textarea className="input resize-none" rows={2} value={taskForm.description} onChange={e => setTaskForm(f => ({ ...f, description: e.target.value }))} placeholder="Additional details…" />
              </div>
              <div>
                <label className="label">Due Date</label>
                <input className="input" type="date" value={taskForm.due_date} onChange={e => setTaskForm(f => ({ ...f, due_date: e.target.value }))} />
              </div>
              <button onClick={createTask} disabled={loading || !taskForm.title || !taskForm.assigned_to} className="btn-primary flex items-center gap-2">
                <Plus size={16} /> Assign Task
              </button>
            </div>
          </div>

          {/* Pending tasks */}
          {pendingTasks.length > 0 && (
            <div className="card p-5">
              <h2 className="section-title mb-3">Pending Tasks ({pendingTasks.length})</h2>
              <div className="space-y-3">
                {pendingTasks.map(t => (
                  <div key={t.id} className="flex items-start gap-3 p-3 rounded-xl bg-gray-50 border border-gray-100">
                    <button onClick={() => completeTask(t.id)} className="text-gray-300 hover:text-green-500 flex-shrink-0 mt-0.5 transition-colors">
                      <CheckCircle size={18} />
                    </button>
                    <div className="flex-1">
                      <div className="font-medium text-gray-900">{t.title}</div>
                      {t.description && <p className="text-sm text-gray-500 mt-0.5">{t.description}</p>}
                      <div className="text-xs text-gray-400 mt-1">
                        → {(t as any).assignee?.full_name ?? 'Unknown'}
                        {t.due_date && ` · Due: ${formatDate(t.due_date)}`}
                      </div>
                    </div>
                    <button onClick={() => deleteTask(t.id)} className="text-gray-300 hover:text-red-400 flex-shrink-0 transition-colors"><X size={15} /></button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Done tasks */}
          {doneTasks.length > 0 && (
            <div className="card p-5">
              <h2 className="section-title mb-3 text-gray-400">Completed ({doneTasks.length})</h2>
              <div className="space-y-2">
                {doneTasks.slice(0, 10).map(t => (
                  <div key={t.id} className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 opacity-60">
                    <CheckCircle size={16} className="text-green-500 flex-shrink-0" />
                    <div className="flex-1">
                      <div className="font-medium text-gray-600 line-through">{t.title}</div>
                      <div className="text-xs text-gray-400">{(t as any).assignee?.full_name}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {pendingTasks.length === 0 && doneTasks.length === 0 && (
            <div className="card p-8 text-center text-gray-400 text-sm">No tasks yet — assign one above</div>
          )}
        </div>
      )}

      {/* DOWNLINE */}
      {tab === 'downline' && (
        <div className="card p-5">
          <h2 className="section-title mb-1">My Personal Line</h2>
          <p className="text-sm text-gray-400 mb-4">People connected to you through your sponsorship chain</p>
          {myDownline.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No one in your line yet</p>
          ) : (
            <div className="space-y-2">
              {myDownline.map(m => (
                <div key={m.id} className="flex items-center gap-3 p-3 rounded-xl border border-gray-100 hover:bg-gray-50 transition-colors">
                  <div className="w-9 h-9 rounded-full flex-shrink-0 overflow-hidden">
                    {m.profile_picture ? (
                      <img src={m.profile_picture} alt="" className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center text-white text-sm font-bold" style={{ backgroundColor: m.color_groups?.hex_color ?? '#4f46e5' }}>
                        {m.full_name.slice(0, 1)}
                      </div>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-sm text-gray-900">{m.full_name}</div>
                    <div className="text-xs text-gray-400">{m.member_id} · {m.color_groups?.name ?? 'No group'}</div>
                  </div>
                  <span className={`badge ${getStatusColor(m.status)}`}>{getStatusLabel(m.status)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
