'use client'

import { useState, useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Bell, LogIn, LogOut, DollarSign, MessageSquare, UserPlus } from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

interface ActivityEvent {
  id: string
  type: string
  message: string
  created_at: string
}

const ICONS: Record<string, React.ReactNode> = {
  sign_in: <LogIn size={14} className="text-green-500" />,
  sign_out: <LogOut size={14} className="text-gray-400" />,
  earning: <DollarSign size={14} className="text-green-600" />,
  community_post: <MessageSquare size={14} className="text-blue-500" />,
  new_member: <UserPlus size={14} className="text-brand-500" />,
}

const LAST_SEEN_KEY = 'activity_feed_last_seen'

export default function ActivityFeed() {
  const [events, setEvents] = useState<ActivityEvent[]>([])
  const [open, setOpen] = useState(false)
  const [unread, setUnread] = useState(0)
  const ref = useRef<HTMLDivElement>(null)

  async function load() {
    const supabase = createClient()
    const { data } = await supabase
      .from('activity_events')
      .select('id, type, message, created_at')
      .order('created_at', { ascending: false })
      .limit(30)
    if (data) {
      setEvents(data)
      const lastSeen = localStorage.getItem(LAST_SEEN_KEY)
      const lastSeenTime = lastSeen ? new Date(lastSeen).getTime() : 0
      setUnread(data.filter(e => new Date(e.created_at).getTime() > lastSeenTime).length)
    }
  }

  useEffect(() => {
    load()
    const supabase = createClient()
    const channel = supabase
      .channel('activity_events')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'activity_events' }, () => {
        load()
      })
      .subscribe()
    return () => { supabase.removeChannel(channel) }
  }, [])

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  function toggle() {
    const next = !open
    setOpen(next)
    if (next) {
      localStorage.setItem(LAST_SEEN_KEY, new Date().toISOString())
      setUnread(0)
    }
  }

  return (
    <div className="relative" ref={ref}>
      <button onClick={toggle} className="relative w-8 h-8 rounded-full flex items-center justify-center text-gray-500 hover:bg-gray-100 transition-colors" title="Activity">
        <Bell size={18} />
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>
      {open && (
        <div className="absolute right-0 mt-2 w-80 max-h-96 overflow-y-auto bg-white rounded-xl shadow-lg border border-gray-100 z-50">
          <div className="px-4 py-3 border-b border-gray-100 font-semibold text-sm text-gray-900">Activity</div>
          {events.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-8">Nothing yet</p>
          ) : (
            events.map(e => (
              <div key={e.id} className="px-4 py-2.5 border-b border-gray-50 flex items-start gap-2.5 hover:bg-gray-50">
                <div className="mt-0.5">{ICONS[e.type] ?? <Bell size={14} className="text-gray-400" />}</div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-gray-700">{e.message}</p>
                  <p className="text-xs text-gray-400">{formatDistanceToNow(new Date(e.created_at), { addSuffix: true })}</p>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}
