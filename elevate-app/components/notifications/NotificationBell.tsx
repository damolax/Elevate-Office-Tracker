'use client'

import { useState, useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Bell } from 'lucide-react'
import { formatDistanceToNow } from 'date-fns'

interface Notification {
  id: string
  title: string
  body: string
  type: string
  read: boolean
  link: string | null
  created_at: string
}

export default function NotificationBell({ userId }: { userId: string }) {
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  const unread = notifications.filter(n => !n.read).length

  async function loadNotifications() {
    const supabase = createClient()
    const { data } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(20)
    if (data) setNotifications(data)
  }

  async function markAllRead() {
    const supabase = createClient()
    const unreadIds = notifications.filter(n => !n.read).map(n => n.id)
    if (!unreadIds.length) return
    await supabase.from('notifications').update({ read: true }).in('id', unreadIds)
    setNotifications(prev => prev.map(n => ({ ...n, read: true })))
  }

  async function markRead(id: string) {
    const supabase = createClient()
    await supabase.from('notifications').update({ read: true }).eq('id', id)
    setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n))
  }

  useEffect(() => {
    loadNotifications()
    const supabase = createClient()
    // Real-time subscription for new notifications
    const channel = supabase
      .channel('notifications')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${userId}`,
      }, (payload) => {
        setNotifications(prev => [payload.new as Notification, ...prev])
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [userId])

  // Close on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  const typeColor: Record<string, string> = {
    success: 'bg-green-100 text-green-700',
    error: 'bg-red-100 text-red-700',
    info: 'bg-blue-100 text-blue-700',
    warning: 'bg-amber-100 text-amber-700',
  }

  return (
    <div className="relative" ref={ref}>
      <button onClick={() => { setOpen(!open); if (!open) loadNotifications() }}
        className="relative p-2 rounded-xl hover:bg-gray-100 transition-colors">
        <Bell size={20} className={unread > 0 ? 'text-indigo-600' : 'text-gray-500'} />
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-red-500 text-white text-xs rounded-full flex items-center justify-center font-bold">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 top-10 w-80 bg-white rounded-2xl shadow-2xl border border-gray-100 z-50 overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
            <span className="font-bold text-gray-900 text-sm">Notifications</span>
            {unread > 0 && (
              <button onClick={markAllRead} className="text-xs text-indigo-600 hover:underline">
                Mark all read
              </button>
            )}
          </div>

          <div className="overflow-y-auto max-h-80">
            {notifications.length === 0 ? (
              <div className="text-center py-8 text-sm text-gray-400">No notifications yet</div>
            ) : notifications.map(n => (
              <div key={n.id}
                onClick={() => { markRead(n.id); if (n.link) window.location.href = n.link }}
                className={`px-4 py-3 border-b border-gray-50 cursor-pointer hover:bg-gray-50 transition-colors ${!n.read ? 'bg-indigo-50/50' : ''}`}>
                <div className="flex items-start gap-2">
                  {!n.read && <div className="w-2 h-2 rounded-full bg-indigo-500 flex-shrink-0 mt-1.5" />}
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-semibold text-gray-900">{n.title}</div>
                    <div className="text-xs text-gray-500 mt-0.5 line-clamp-2">{n.body}</div>
                    <div className="text-xs text-gray-400 mt-1">
                      {formatDistanceToNow(new Date(n.created_at), { addSuffix: true })}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
