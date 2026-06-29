'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { Profile } from '@/lib/types'
import { formatDate } from '@/lib/utils'
import { MessageSquare, Send, CheckCircle, Clock, AlertCircle } from 'lucide-react'

const CATEGORIES = [
  { value: 'general', label: 'General', color: 'bg-blue-100 text-blue-700' },
  { value: 'bug', label: 'Bug / Issue', color: 'bg-red-100 text-red-700' },
  { value: 'feature', label: 'Feature Request', color: 'bg-purple-100 text-purple-700' },
  { value: 'complaint', label: 'Complaint', color: 'bg-amber-100 text-amber-700' },
]

const STATUS_STYLES: Record<string, { label: string; color: string; icon: React.ReactNode }> = {
  open: { label: 'Open', color: 'bg-blue-100 text-blue-700', icon: <Clock size={12} /> },
  in_review: { label: 'In Review', color: 'bg-amber-100 text-amber-700', icon: <AlertCircle size={12} /> },
  resolved: { label: 'Resolved', color: 'bg-green-100 text-green-700', icon: <CheckCircle size={12} /> },
}

export default function FeedbackClient({
  profile, isAdmin, myFeedback, allFeedback,
}: {
  profile: Profile
  isAdmin: boolean
  myFeedback: any[]
  allFeedback: any[]
}) {
  const [tab, setTab] = useState<'submit' | 'mine' | 'all'>(isAdmin ? 'all' : 'submit')
  const [form, setForm] = useState({ title: '', message: '', category: 'general' })
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)
  const [respondingTo, setRespondingTo] = useState<string | null>(null)
  const [responseText, setResponseText] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')

  async function submitFeedback() {
    if (!form.title.trim() || !form.message.trim()) return
    setLoading(true)
    setMsg(null)
    const supabase = createClient()
    const { error } = await supabase.from('feedback').insert({
      user_id: profile.id,
      title: form.title.trim(),
      message: form.message.trim(),
      category: form.category,
    })
    if (error) {
      setMsg({ type: 'error', text: error.message })
    } else {
      setMsg({ type: 'success', text: 'Feedback submitted! We\'ll get back to you soon.' })
      setForm({ title: '', message: '', category: 'general' })
      setTimeout(() => window.location.reload(), 1500)
    }
    setLoading(false)
  }

  async function respondToFeedback(id: string) {
    if (!responseText.trim()) return
    const supabase = createClient()
    const { error } = await supabase.from('feedback').update({
      admin_response: responseText.trim(),
      status: 'resolved',
      responded_by: profile.id,
      responded_at: new Date().toISOString(),
    }).eq('id', id)
    if (!error) {
      setRespondingTo(null)
      setResponseText('')
      setTimeout(() => window.location.reload(), 500)
    }
  }

  async function updateStatus(id: string, status: string) {
    const supabase = createClient()
    await supabase.from('feedback').update({ status }).eq('id', id)
    setTimeout(() => window.location.reload(), 400)
  }

  const filteredAll = allFeedback.filter(f => statusFilter === 'all' || f.status === statusFilter)

  const categoryInfo = (cat: string) => CATEGORIES.find(c => c.value === cat) ?? CATEGORIES[0]
  const statusInfo = (s: string) => STATUS_STYLES[s] ?? STATUS_STYLES.open

  const FeedbackCard = ({ f, showUser }: { f: any; showUser: boolean }) => (
    <div className="card p-5 space-y-3">
      <div className="flex items-start justify-between gap-4">
        <div className="flex-1">
          <div className="flex items-center gap-2 flex-wrap mb-1">
            <span className="font-semibold text-gray-900">{f.title}</span>
            <span className={`badge text-xs ${categoryInfo(f.category).color}`}>
              {categoryInfo(f.category).label}
            </span>
            <span className={`badge flex items-center gap-1 text-xs ${statusInfo(f.status).color}`}>
              {statusInfo(f.status).icon}
              {statusInfo(f.status).label}
            </span>
          </div>
          {showUser && f.user && (
            <div className="text-xs text-gray-400 mb-1">
              From: {f.user.full_name} ({f.user.member_id ?? f.user.email})
            </div>
          )}
          <div className="text-xs text-gray-400">{formatDate(f.created_at)}</div>
        </div>

        {isAdmin && (
          <div className="flex gap-2 flex-shrink-0">
            <select
              className="input py-1 text-xs w-32"
              value={f.status}
              onChange={e => updateStatus(f.id, e.target.value)}
            >
              <option value="open">Open</option>
              <option value="in_review">In Review</option>
              <option value="resolved">Resolved</option>
            </select>
          </div>
        )}
      </div>

      <p className="text-sm text-gray-700 leading-relaxed bg-gray-50 rounded-lg p-3">{f.message}</p>

      {f.admin_response && (
        <div className="bg-brand-50 border border-brand-100 rounded-lg p-3">
          <div className="text-xs font-semibold text-brand-700 mb-1 flex items-center gap-1">
            <MessageSquare size={12} />
            Admin Response
            {f.responder && <span className="text-brand-500">· {f.responder.full_name}</span>}
          </div>
          <p className="text-sm text-brand-900">{f.admin_response}</p>
        </div>
      )}

      {isAdmin && respondingTo === f.id && (
        <div className="space-y-2">
          <textarea
            className="input resize-none text-sm"
            rows={3}
            placeholder="Write your response…"
            value={responseText}
            onChange={e => setResponseText(e.target.value)}
          />
          <div className="flex gap-2">
            <button onClick={() => respondToFeedback(f.id)} className="btn-primary btn-sm">Send Response</button>
            <button onClick={() => { setRespondingTo(null); setResponseText('') }} className="btn-secondary btn-sm">Cancel</button>
          </div>
        </div>
      )}

      {isAdmin && respondingTo !== f.id && (
        <button
          onClick={() => { setRespondingTo(f.id); setResponseText(f.admin_response ?? '') }}
          className="btn-ghost btn-sm text-brand-600"
        >
          {f.admin_response ? 'Edit Response' : '↩ Respond'}
        </button>
      )}
    </div>
  )

  return (
    <div className="space-y-6 max-w-3xl mx-auto">
      {msg && (
        <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit flex-wrap">
        {[
          { id: 'submit', label: '✍ Submit Feedback' },
          { id: 'mine', label: `My Feedback (${myFeedback.length})` },
          ...(isAdmin ? [{ id: 'all', label: `All Feedback (${allFeedback.length})` }] : []),
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

      {/* Submit feedback */}
      {tab === 'submit' && (
        <div className="card p-6 space-y-4">
          <div>
            <h2 className="section-title mb-1">Share Your Feedback</h2>
            <p className="text-sm text-gray-500">
              Found a bug? Have a suggestion? Something feel off? Let us know — your feedback goes directly to the admin.
            </p>
          </div>

          <div>
            <label className="label">Category</label>
            <div className="flex flex-wrap gap-2">
              {CATEGORIES.map(c => (
                <button
                  key={c.value}
                  onClick={() => setForm(f => ({ ...f, category: c.value }))}
                  className={`px-3 py-1.5 rounded-lg text-sm font-medium border transition-all ${
                    form.category === c.value
                      ? c.color + ' border-current'
                      : 'bg-gray-50 text-gray-500 border-gray-200 hover:bg-gray-100'
                  }`}
                >
                  {c.label}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="label">Title *</label>
            <input
              className="input"
              placeholder="Brief summary of your feedback"
              value={form.title}
              onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
            />
          </div>

          <div>
            <label className="label">Message *</label>
            <textarea
              className="input resize-none"
              rows={5}
              placeholder="Describe your feedback in detail…"
              value={form.message}
              onChange={e => setForm(f => ({ ...f, message: e.target.value }))}
            />
          </div>

          <button
            onClick={submitFeedback}
            disabled={loading || !form.title.trim() || !form.message.trim()}
            className="btn-primary flex items-center gap-2"
          >
            <Send size={15} />
            {loading ? 'Submitting…' : 'Submit Feedback'}
          </button>
        </div>
      )}

      {/* My feedback */}
      {tab === 'mine' && (
        <div className="space-y-4">
          {myFeedback.length === 0 ? (
            <div className="card p-8 text-center">
              <MessageSquare size={32} className="text-gray-300 mx-auto mb-3" />
              <p className="text-gray-400">You haven&apos;t submitted any feedback yet.</p>
              <button onClick={() => setTab('submit')} className="btn-primary mt-4">Submit Feedback</button>
            </div>
          ) : (
            myFeedback.map(f => <FeedbackCard key={f.id} f={f} showUser={false} />)
          )}
        </div>
      )}

      {/* All feedback (admin) */}
      {tab === 'all' && isAdmin && (
        <div className="space-y-4">
          <div className="flex items-center gap-3">
            <select
              className="input w-auto"
              value={statusFilter}
              onChange={e => setStatusFilter(e.target.value)}
            >
              <option value="all">All Statuses</option>
              <option value="open">Open</option>
              <option value="in_review">In Review</option>
              <option value="resolved">Resolved</option>
            </select>
            <span className="text-sm text-gray-500">{filteredAll.length} item{filteredAll.length !== 1 ? 's' : ''}</span>
          </div>

          {filteredAll.length === 0 ? (
            <div className="card p-8 text-center text-gray-400">No feedback yet.</div>
          ) : (
            filteredAll.map(f => <FeedbackCard key={f.id} f={f} showUser={true} />)
          )}
        </div>
      )}
    </div>
  )
}
