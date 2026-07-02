'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Menu, X, Bell, LayoutDashboard, Users, UserCheck, DollarSign, Search, Calendar, MessageSquare, Settings, QrCode, Group, LogOut } from 'lucide-react'
import type { Profile } from '@/lib/types'
import { getStatusLabel, isSmOrAbove } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

const PAGE_TITLES: Record<string, string> = {
  '/dashboard': 'Dashboard',
  '/attendance': 'Attendance',
  '/team': 'My Team',
  '/group': 'My Group',
  '/people': 'People',
  '/money': 'Money Making',
  '/scouting': 'Scouting',
  '/community': 'Community',
  '/events': 'Events',
  '/settings': 'Settings',
}

export default function Header({ profile }: { profile: Profile }) {
  const pathname = usePathname()
  const router = useRouter()
  const [mobileOpen, setMobileOpen] = useState(false)
  const isAdmin = profile.is_admin || profile.is_director
  const isSm = isSmOrAbove(profile.status)

  const title = Object.entries(PAGE_TITLES).find(([k]) =>
    pathname === k || pathname.startsWith(k + '/')
  )?.[1] ?? 'Elevate'

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
  }

  const navItems = [
    { href: '/dashboard', label: 'Dashboard', icon: <LayoutDashboard size={18} /> },
    { href: '/attendance', label: 'Attendance', icon: <QrCode size={18} /> },
    { href: '/team', label: 'My Team', icon: <Users size={18} /> },
    ...(isSm || isAdmin ? [{ href: '/group', label: 'My Group', icon: <Group size={18} /> }] : []),
    ...(isAdmin ? [{ href: '/people', label: 'People', icon: <UserCheck size={18} /> }] : []),
    { href: '/money', label: 'Money Making', icon: <DollarSign size={18} /> },
    { href: '/scouting', label: 'Scouting', icon: <Search size={18} /> },
    { href: '/community', label: 'Community', icon: <MessageSquare size={18} /> },
    { href: '/events', label: 'Events', icon: <Calendar size={18} /> },
    { href: '/settings', label: 'Settings', icon: <Settings size={18} /> },
  ]

  return (
    <>
      <header className="bg-white border-b border-gray-200 px-4 sm:px-6 py-3 flex items-center justify-between flex-shrink-0">
        {/* Mobile menu button */}
        <button
          className="md:hidden p-2 rounded-lg text-gray-500 hover:bg-gray-100"
          onClick={() => setMobileOpen(true)}
        >
          <Menu size={20} />
        </button>

        <h1 className="text-lg font-bold text-gray-900">{title}</h1>

        <div className="flex items-center gap-2">
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold cursor-pointer"
            style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}
            title={profile.full_name}
          >
            {profile.full_name.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()}
          </div>
        </div>
      </header>

      {/* Mobile sidebar */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div className="absolute inset-0 bg-black/40" onClick={() => setMobileOpen(false)} />
          <aside className="absolute left-0 top-0 bottom-0 w-72 bg-white flex flex-col overflow-y-auto shadow-2xl">
            <div className="flex items-center justify-between p-4 border-b border-gray-100">
              <div className="font-bold text-gray-900">Elevate</div>
              <button onClick={() => setMobileOpen(false)} className="p-2 rounded-lg hover:bg-gray-100">
                <X size={18} />
              </button>
            </div>

            <div className="px-4 py-3 border-b border-gray-100">
              <div className="text-sm font-semibold text-gray-900">{profile.full_name}</div>
              <div className="text-xs text-gray-400">{profile.member_id} · {getStatusLabel(profile.status)}</div>
            </div>

            <nav className="flex-1 p-3 space-y-0.5">
              {navItems.map(item => {
                const active = pathname === item.href
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    onClick={() => setMobileOpen(false)}
                    className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                      active ? 'bg-brand-600 text-white' : 'text-gray-600 hover:bg-gray-100'
                    }`}
                  >
                    {item.icon}
                    {item.label}
                  </Link>
                )
              })}
            </nav>

            <div className="p-3 border-t border-gray-100">
              <button onClick={handleSignOut} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-gray-500 hover:bg-red-50 hover:text-red-600">
                <LogOut size={18} />
                Sign Out
              </button>
            </div>
          </aside>
        </div>
      )}
    </>
  )
}
