'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile, Task, ColorGroup } from '@/lib/types'
import { getStatusLabel, formatDate } from '@/lib/utils'
import { CheckCircle, User, Palette, Info, CheckSquare, Plus, Trash2, Edit2, Check, X } from 'lucide-react'

export default function SettingsClient({
  profile, settings, isAdmin, myTasks,
}: {
  profile: Profile
  settings: Record<string, string>
  isAdmin: boolean
  myTasks: Task[]
}) {
  const [tab, setTab] = useState('profile')
  const [profileForm, setProfileForm] = useState({
    full_name: profile.full_name,
    phone: profile.phone ?? '',
    about: profile.about ?? '',
  })
  const [appForm, setAppForm] = useState({
    app_name: settings.app_name ?? 'Elevate Office Tracker',
    about_us: settings.about_us ?? '',
    primary_color: settings.primary_color ?? '#4f46e5',
  })
  const [pw, setPw] = useState({ new_pw: '', confirm: '' })
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [loading, setLoading] = useState(false)
  const [colorGroups, setColorGroups] = useState<ColorGroup[]>([])
  const [colorLoading, setColorLoading] = useState(false)
  const [newColor, setNewColor] = useState({ name: '', hex_color: '#6366f1', code: '' })
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editForm, setEditForm] = useState({ name: '', hex_color: '', code: '' })

  useEffect(() => {
    if (isAdmin) loadColorGroups()
  }, [isAdmin])

  async function loadColorGroups() {
    const supabase = createClient()
    const { data } = await supabase.from('color_groups').select('*').order('name')
    if (data) setColorGroups(data)
  }

  async function saveProfile() {
    setLoading(true); setMsg(null)
    const supabase = createClient()
    const { error } = await supabase.from('profiles').update({
      full_name: profileForm.full_name,
      phone: profileForm.phone || null,
      about: profileForm.about || null,
    }).eq('id', profile.id)
    if (error) setMsg({ type: 'error', text: error.message })
    else setMsg({ type: 'success', text: 'Profile updated!' })
    setLoading(false)
  }

  async function changePassword() {
    if (pw.new_pw !== pw.confirm) { setMsg({ type: 'error', text: 'Passwords do not match' }); return }
    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.auth.updateUser({ password: pw.new_pw })
    if (error) setMsg({ type: 'error', text: error.message })
    else { setMsg({ type: 'success', text: 'Password changed!' }); setPw({ new_pw: '', confirm: '' }) }
    setLoading(false)
  }

  async function saveAppSettings() {
    setLoading(true); setMsg(null)
    const supabase = createClient()
    for (const [key, value] of Object.entries(appForm)) {
      await supabase.from('app_settings').upsert({ key, value }, { onConflict: 'key' })
    }
    setMsg({ type: 'success', text: 'Settings saved!' })
    setLoading(false)
  }

  async function markTaskDone(taskId: string) {
    const supabase = createClient()
    await supabase.from('tasks').update({ completed: true, completed_at: new Date().toISOString() }).eq('id', taskId)
    setTimeout(() => window.location.reload(), 500)
  }

  async function uploadAvatar(file: File) {
    const supabase = createClient()
    const ext = file.name.split('.').pop()
    const path = `${profile.id}/avatar.${ext}`
    const { error: uploadError } = await supabase.storage.from('avatars').upload(path, file, { upsert: true })
    if (uploadError) { setMsg({ type: 'error', text: uploadError.message }); return }
    const { data: { publicUrl } } = supabase.storage.from('avatars').getPublicUrl(path)
    await supabase.from('profiles').update({ profile_picture: publicUrl }).eq('id', profile.id)
    setMsg({ type: 'success', text: 'Profile picture updated!' })
    setTimeout(() => window.location.reload(), 1000)
  }

  async function addColorGroup() {
    if (!newColor.name.trim() || !newColor.code.trim()) {
      setMsg({ type: 'error', text: 'Name and code are required' }); return
    }
    setColorLoading(true)
    const supabase = createClient()
    const { error } = await supabase.from('color_groups').insert({
      name: newColor.name.trim(),
      hex_color: newColor.hex_color,
      code: newColor.code.trim().toUpperCase().slice(0, 6),
      member_count: 0,
    })
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setNewColor({ name: '', hex_color: '#6366f1', code: '' })
      setMsg({ type: 'success', text: 'Color group added!' })
      loadColorGroups()
    }
    setColorLoading(false)
  }

  async function saveEditColor(id: string) {
    if (!editForm.name.trim() || !editForm.code.trim()) return
    setColorLoading(true)
    const supabase = createClient()
    const { error } = await supabase.from('color_groups').update({
      name: editForm.name.trim(),
      hex_color: editForm.hex_color,
      code: editForm.code.trim().toUpperCase().slice(0, 6),
    }).eq('id', id)
    if (error) setMsg({ type: 'error', text: error.message })
    else { setEditingId(null); loadColorGroups(); setMsg({ type: 'success', text: 'Updated!' }) }
    setColorLoading(false)
  }

  async function deleteColorGroup(id: string, name: string) {
    if (!confirm(`Delete "${name}"? Members in this group will become unassigned.`)) return
    setColorLoading(true)
    const supabase = createClient()
    const { error } = await supabase.from('color_groups').delete().eq('id', id)
    if (error) setMsg({ type: 'error', text: error.message })
    else { loadColorGroups(); setMsg({ type: 'success', text: 'Deleted' }) }
    setColorLoading(false)
  }

  function startEdit(g: ColorGroup) {
    setEditingId(g.id)
    setEditForm({ name: g.name, hex_color: g.hex_color, code: g.code })
  }

  const tabs = [
    { id: 'profile', label: 'My Profile', icon: User },
    { id: 'tasks', label: `Tasks (${myTasks.length})`, icon: CheckSquare },
    { id: 'week', label: 'Week Progress', icon: Info },
    ...(isAdmin ? [
      { id: 'colors', label: 'Color Groups', icon: Palette },
      { id: 'app', label: 'App Settings', icon: Palette },
    ] : []),
  ]

  return (
    <div className="space-y-6 max-w-3xl mx-auto">
      {msg && (
        <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {tabs.map(t => {
          const Icon = t.icon
          return (
            <button key={t.id} onClick={() => setTab(t.id)} className={`flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-medium transition-all ${tab === t.id ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'}`}>
              <Icon size={16} />{t.label}
            </button>
          )
        })}
      </div>

      {tab === 'profile' && (
        <div className="space-y-4">
          <div className="card p-6">
            <h2 className="section-title mb-4">Profile Information</h2>
            <div className="flex items-center gap-4 mb-6">
              <div className="w-16 h-16 rounded-2xl flex items-center justify-center text-white text-xl font-bold" style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}>
                {profile.full_name.slice(0, 1)}
              </div>
              <div>
                <div className="font-semibold text-gray-900">{profile.full_name}</div>
                <div className="text-sm text-gray-400">{profile.member_id} · {getStatusLabel(profile.status)}</div>
                <label className="mt-1 btn-secondary btn-sm inline-flex cursor-pointer">
                  Change Photo
                  <input type="file" className="hidden" accept="image/*" onChange={e => e.target.files?.[0] && uploadAvatar(e.target.files[0])} />
                </label>
              </div>
            </div>
            <div className="space-y-4">
              <div><label className="label">Full Name</label><input className="input" value={profileForm.full_name} onChange={e => setProfileForm(p => ({ ...p, full_name: e.target.value }))} /></div>
              <div><label className="label">Phone</label><input className="input" value={profileForm.phone} onChange={e => setProfileForm(p => ({ ...p, phone: e.target.value }))} placeholder="+234 xxx xxx xxxx" /></div>
              <div><label className="label">About Me</label><textarea className="input resize-none" rows={3} value={profileForm.about} onChange={e => setProfileForm(p => ({ ...p, about: e.target.value }))} placeholder="A brief bio..." /></div>
              <button onClick={saveProfile} disabled={loading} className="btn-primary">Save Profile</button>
            </div>
          </div>

          <div className="card p-6">
            <h2 className="section-title mb-4">Change Password</h2>
            <div className="space-y-4">
              <div><label className="label">New Password</label><input className="input" type="password" value={pw.new_pw} onChange={e => setPw(p => ({ ...p, new_pw: e.target.value }))} placeholder="Min. 8 characters" /></div>
              <div><label className="label">Confirm New Password</label><input className="input" type="password" value={pw.confirm} onChange={e => setPw(p => ({ ...p, confirm: e.target.value }))} placeholder="Repeat new password" /></div>
              <button onClick={changePassword} disabled={loading} className="btn-primary">Change Password</button>
            </div>
          </div>

          <div className="card p-5">
            <h2 className="section-title mb-3">Account Details</h2>
            <div className="space-y-2 text-sm">
              {[
                { label: 'Email', value: profile.email },
                { label: 'Member ID', value: profile.member_id ?? 'Pending' },
                { label: 'Status', value: getStatusLabel(profile.status) },
                { label: 'Color Group', value: profile.color_groups?.name ?? 'Not assigned' },
                { label: 'Week Number', value: ['member','distributor','manager'].includes(profile.status) ? `Week ${profile.week_number}` : 'N/A' },
                { label: 'Member Since', value: formatDate(profile.created_at) },
              ].map(({ label, value }) => (
                <div key={label} className="flex justify-between py-1.5 border-b border-gray-50 last:border-0">
                  <span className="text-gray-500">{label}</span>
                  <span className="font-medium text-gray-900">{value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {tab === 'tasks' && (
        <div className="card p-5">
          <h2 className="section-title mb-4">My Tasks</h2>
          {myTasks.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">No pending tasks — you are all caught up!</p>
          ) : (
            <div className="space-y-3">
              {myTasks.map(t => (
                <div key={t.id} className="flex items-start gap-3 p-4 rounded-xl bg-gray-50 border border-gray-100">
                  <button onClick={() => markTaskDone(t.id)} className="mt-0.5 text-gray-300 hover:text-green-500 flex-shrink-0"><CheckCircle size={18} /></button>
                  <div className="flex-1">
                    <div className="font-medium text-gray-900">{t.title}</div>
                    {t.description && <p className="text-sm text-gray-500 mt-0.5">{t.description}</p>}
                    <div className="text-xs text-gray-400 mt-1">From: {(t as any).assigner?.full_name ?? 'Admin'}{t.due_date && ` · Due: ${formatDate(t.due_date)}`}</div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {tab === 'week' && (
        <div className="card p-5">
          <h2 className="section-title mb-2">Week Progression</h2>
          {['senior_manager','executive_manager','director'].includes(profile.status) ? (
            <p className="text-sm text-gray-500">Week progression is for Members, Distributors, and Managers only.</p>
          ) : (
            <>
              <p className="text-sm text-gray-500 mb-6">Track your progress through the 12-week orientation program.</p>
              <div className="grid grid-cols-4 sm:grid-cols-6 gap-3">
                {Array.from({ length: 12 }, (_, i) => i + 1).map(w => {
                  const done = w < profile.week_number
                  const current = w === profile.week_number
                  return (
                    <div key={w} className={`text-center p-3 rounded-xl border-2 ${done ? 'bg-green-50 border-green-300 text-green-700' : current ? 'bg-brand-50 border-brand-400 text-brand-700' : 'bg-gray-50 border-gray-200 text-gray-400'}`}>
                      <div className="text-lg font-extrabold">{w}</div>
                      <div className="text-xs mt-0.5">{done ? 'Done' : current ? 'Current' : 'Locked'}</div>
                    </div>
                  )
                })}
              </div>
              <div className="mt-4 p-3 bg-gray-50 rounded-xl text-sm text-gray-600">
                <span className="font-medium">Current Week: {profile.week_number}</span> — Contact your upline SM to advance.
              </div>
            </>
          )}
        </div>
      )}

      {tab === 'colors' && isAdmin && (
        <div className="space-y-4">
          <div className="card p-6">
            <h2 className="section-title mb-4">Add New Color Group</h2>
            <div className="grid grid-cols-1 sm:grid-cols-4 gap-3 items-end">
              <div className="sm:col-span-2">
                <label className="label">Group Name *</label>
                <input className="input" value={newColor.name} onChange={e => setNewColor(p => ({ ...p, name: e.target.value }))} placeholder="e.g. Silver" />
              </div>
              <div>
                <label className="label">Short Code *</label>
                <input className="input" value={newColor.code} onChange={e => setNewColor(p => ({ ...p, code: e.target.value.toUpperCase().slice(0, 6) }))} placeholder="e.g. SLV" maxLength={6} />
              </div>
              <div>
                <label className="label">Colour</label>
                <div className="flex items-center gap-2">
                  <input type="color" value={newColor.hex_color} onChange={e => setNewColor(p => ({ ...p, hex_color: e.target.value }))} className="w-10 h-10 rounded cursor-pointer border border-gray-200 flex-shrink-0" />
                  <input className="input" value={newColor.hex_color} onChange={e => setNewColor(p => ({ ...p, hex_color: e.target.value }))} placeholder="#6366f1" />
                </div>
              </div>
            </div>
            <button onClick={addColorGroup} disabled={colorLoading} className="btn-primary mt-4 flex items-center gap-2">
              <Plus size={16} /> Add Color Group
            </button>
          </div>

          <div className="card p-6">
            <h2 className="section-title mb-4">Existing Color Groups</h2>
            {colorGroups.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No color groups yet</p>
            ) : (
              <div className="space-y-2">
                {colorGroups.map(g => (
                  <div key={g.id} className="flex items-center gap-3 p-3 rounded-xl border border-gray-100 bg-gray-50">
                    {editingId === g.id ? (
                      <>
                        <input type="color" value={editForm.hex_color} onChange={e => setEditForm(p => ({ ...p, hex_color: e.target.value }))} className="w-9 h-9 rounded cursor-pointer border border-gray-200 flex-shrink-0" />
                        <input className="input py-1.5 flex-1" value={editForm.name} onChange={e => setEditForm(p => ({ ...p, name: e.target.value }))} placeholder="Name" />
                        <input className="input py-1.5 w-24" value={editForm.code} onChange={e => setEditForm(p => ({ ...p, code: e.target.value.toUpperCase().slice(0,6) }))} placeholder="Code" maxLength={6} />
                        <button onClick={() => saveEditColor(g.id)} disabled={colorLoading} className="btn-primary btn-sm flex items-center gap-1"><Check size={14} /> Save</button>
                        <button onClick={() => setEditingId(null)} className="btn-secondary btn-sm"><X size={14} /></button>
                      </>
                    ) : (
                      <>
                        <div className="w-9 h-9 rounded-lg flex-shrink-0 border border-white shadow-sm" style={{ backgroundColor: g.hex_color }} />
                        <div className="flex-1 min-w-0">
                          <div className="font-semibold text-gray-900">{g.name}</div>
                          <div className="text-xs text-gray-400">{g.code} · {g.member_count} members</div>
                        </div>
                        <button onClick={() => startEdit(g)} className="btn-secondary btn-sm flex items-center gap-1"><Edit2 size={13} /> Edit</button>
                        <button onClick={() => deleteColorGroup(g.id, g.name)} className="btn-danger btn-sm flex items-center gap-1"><Trash2 size={13} /></button>
                      </>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {tab === 'app' && isAdmin && (
        <div className="card p-6 space-y-4">
          <h2 className="section-title">App Settings</h2>
          <div><label className="label">App Name</label><input className="input" value={appForm.app_name} onChange={e => setAppForm(p => ({ ...p, app_name: e.target.value }))} /></div>
          <div><label className="label">About Us</label><textarea className="input resize-none" rows={4} value={appForm.about_us} onChange={e => setAppForm(p => ({ ...p, about_us: e.target.value }))} /></div>
          <div>
            <label className="label">Primary Color</label>
            <div className="flex items-center gap-3">
              <input type="color" value={appForm.primary_color} onChange={e => setAppForm(p => ({ ...p, primary_color: e.target.value }))} className="w-12 h-10 rounded cursor-pointer border border-gray-200" />
              <input className="input w-32" value={appForm.primary_color} onChange={e => setAppForm(p => ({ ...p, primary_color: e.target.value }))} placeholder="#4f46e5" />
            </div>
          </div>
          <button onClick={saveAppSettings} disabled={loading} className="btn-primary">Save App Settings</button>
        </div>
      )}
    </div>
  )
}
