'use client'

import { useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'

// Updates last_seen every 4 minutes while app is open
export function useLastSeen(userId: string | null) {
  useEffect(() => {
    if (!userId) return

    const supabase = createClient()

    async function ping() {
      await supabase.rpc('update_last_seen', { p_user_id: userId })
    }

    ping() // immediate on mount
    const interval = setInterval(ping, 4 * 60 * 1000) // every 4 min
    return () => clearInterval(interval)
  }, [userId])
}

// Returns whether a user is online (last_seen within 5 minutes)
export function isOnline(lastSeen: string | null): boolean {
  if (!lastSeen) return false
  return Date.now() - new Date(lastSeen).getTime() < 5 * 60 * 1000
}

export function lastSeenLabel(lastSeen: string | null): string {
  if (!lastSeen) return 'Never seen'
  const diff = Date.now() - new Date(lastSeen).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'Just now'
  if (mins < 5) return `${mins}m ago`
  if (mins < 60) return `${mins} minutes ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  return `${days}d ago`
}
