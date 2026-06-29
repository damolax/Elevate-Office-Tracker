'use client'

import { useState } from 'react'
import { format, parseISO, isFuture, isToday } from 'date-fns'
import { createClient } from '@/lib/supabase/client'
import type { Profile, Event } from '@/lib/types'
import { Calendar, Plus, Trash2, MapPin, Clock } from 'lucide-react'

export default function EventsClient({
  profile, events, isAdmin,
}: {
  profile: Profile
  events: Event[]
  isAdmin: boolean
}) {
  const [showAdd, setShowAdd] = useState(false)
  const [form, setForm] = useState({ title: '', description: '', event_date: '', event_time: '', location: '' })
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  const upcoming = events.filter(e => isFuture(parseISO(e.event_date)) || isToday(parseISO(e.event_date)))
  const past = events.filter(e => !isFuture(parseISO(e.event_date)) && !isToday(parseISO(e.event_date)))

  async function addEvent() {
    if (!form.title || !form.event_date) return
    setLoading(true)
    const supabase = createClient()
    const { error } = await supabase.from('events').insert({
      title: form.title,
      description: form.description || null,
      event_date: form.event_date,
      event_time: form.event_time || null,
      location: form.location || null,
      created_by: profile.id,
    })
    if (error) setMsg({ type: 'error', text: error.message })
    else {
      setMsg({ type: 'success', text: 'Event added!' })
      setShowAdd(false)
      setForm({ title: '', description: '', event_date: '', event_time: '', location: '' })
      setTimeout(() => window.location.reload(), 1000)
    }
    setLoading(false)
  }

  async function deleteEvent(id: string) {
    const supabase = createClient()
    await supabase.from('events').delete().eq('id', id)
    setTimeout(() => window.location.reload(), 500)
  }

  const EventCard = ({ event }: { event: Event }) => (
    <div className="card p-5 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between gap-4">
        <div className="flex gap-4">
          <div className="flex-shrink-0 text-center bg-brand-50 rounded-xl p-3 w-14">
            <div className="text-xs font-medium text-brand-600 uppercase">
              {format(parseISO(event.event_date), 'MMM')}
            </div>
            <div className="text-2xl font-extrabold text-brand-700 leading-none">
              {format(parseISO(event.event_date), 'd')}
            </div>
          </div>
          <div>
            <div className="font-bold text-gray-900">{event.title}</div>
            {event.description && <p className="text-sm text-gray-500 mt-0.5">{event.description}</p>}
            <div className="flex items-center gap-4 mt-2 flex-wrap">
              {event.event_time && (
                <div className="flex items-center gap-1 text-xs text-gray-400">
                  <Clock size={12} />
                  {event.event_time}
                </div>
              )}
              {event.location && (
                <div className="flex items-center gap-1 text-xs text-gray-400">
                  <MapPin size={12} />
                  {event.location}
                </div>
              )}
            </div>
          </div>
        </div>
        {isAdmin && (
          <button
            onClick={() => deleteEvent(event.id)}
            className="p-1.5 rounded-lg text-gray-300 hover:text-red-500 hover:bg-red-50 flex-shrink-0"
          >
            <Trash2 size={14} />
          </button>
        )}
      </div>
    </div>
  )

  return (
    <div className="space-y-6 max-w-3xl mx-auto">
      {msg && (
        <div className={`px-4 py-3 rounded-lg text-sm border ${msg.type === 'success' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-red-50 text-red-700 border-red-200'}`}>
          {msg.text}
        </div>
      )}

      {/* Add event */}
      {isAdmin && (
        <div>
          {!showAdd ? (
            <button onClick={() => setShowAdd(true)} className="btn-primary">
              <Plus size={16} /> Add Event
            </button>
          ) : (
            <div className="card p-5 space-y-4">
              <h2 className="section-title">Add New Event</h2>
              <div>
                <label className="label">Title *</label>
                <input className="input" value={form.title} onChange={e => setForm(p => ({ ...p, title: e.target.value }))} placeholder="e.g. Kit Opening, Check Rally" />
              </div>
              <div>
                <label className="label">Description</label>
                <textarea className="input resize-none" rows={2} value={form.description} onChange={e => setForm(p => ({ ...p, description: e.target.value }))} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label">Date *</label>
                  <input className="input" type="date" value={form.event_date} onChange={e => setForm(p => ({ ...p, event_date: e.target.value }))} />
                </div>
                <div>
                  <label className="label">Time</label>
                  <input className="input" type="time" value={form.event_time} onChange={e => setForm(p => ({ ...p, event_time: e.target.value }))} />
                </div>
              </div>
              <div>
                <label className="label">Location</label>
                <input className="input" value={form.location} onChange={e => setForm(p => ({ ...p, location: e.target.value }))} placeholder="Venue or online link" />
              </div>
              <div className="flex gap-3">
                <button onClick={addEvent} disabled={loading} className="btn-primary">
                  {loading ? 'Adding…' : 'Add Event'}
                </button>
                <button onClick={() => setShowAdd(false)} className="btn-secondary">Cancel</button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Upcoming */}
      <div>
        <h2 className="section-title mb-3 flex items-center gap-2">
          <Calendar size={18} className="text-brand-600" />
          Upcoming Events ({upcoming.length})
        </h2>
        {upcoming.length === 0 ? (
          <div className="card p-8 text-center text-gray-400">No upcoming events</div>
        ) : (
          <div className="space-y-3">
            {upcoming.map(e => <EventCard key={e.id} event={e} />)}
          </div>
        )}
      </div>

      {/* Past events */}
      {past.length > 0 && (
        <div>
          <h2 className="section-title mb-3 text-gray-400">Past Events</h2>
          <div className="space-y-3 opacity-60">
            {past.slice(0, 5).map(e => <EventCard key={e.id} event={e} />)}
          </div>
        </div>
      )}
    </div>
  )
}
