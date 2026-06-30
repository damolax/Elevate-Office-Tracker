'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  LayoutDashboard, Users, UserCheck, DollarSign, Search,
  Calendar, MessageSquare, Settings, QrCode, Group, LogOut, ChevronRight, Flag, GraduationCap, Crown
} from 'lucide-react'
import type { Profile } from '@/lib/types'
import { isSmOrAbove, getStatusLabel } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

interface NavItem {
  href: string
  label: string
  icon: React.ReactNode
  adminOnly?: boolean
  smOnly?: boolean
}

export default function Sidebar({ profile }: { profile: Profile }) {
  const pathname = usePathname()
  const router = useRouter()
  const isAdmin = profile.is_admin || profile.is_director
  const isSm = isSmOrAbove(profile.status)

  const navItems: NavItem[] = [
    { href: '/dashboard', label: 'Dashboard', icon: <LayoutDashboard size={18} /> },
    { href: '/attendance', label: 'Attendance', icon: <QrCode size={18} /> },
    { href: '/weeks', label: '12-Week Program', icon: <GraduationCap size={18} /> },
    ...(profile.member_id?.endsWith('-001') || profile.is_admin ? [{ href: '/my-group', label: 'My Group', icon: <Crown size={18} /> }] : []),
    { href: '/team', label: 'My Team', icon: <Users size={18} /> },
    { href: '/group', label: 'My Group', icon: <Group size={18} />, smOnly: true },
    { href: '/people', label: 'People', icon: <UserCheck size={18} />, adminOnly: true },
    { href: '/money', label: 'Money Making', icon: <DollarSign size={18} /> },
    { href: '/scouting', label: 'Scouting', icon: <Search size={18} /> },
    { href: '/community', label: 'Community', icon: <MessageSquare size={18} /> },
    { href: '/events', label: 'Events', icon: <Calendar size={18} /> },
    { href: '/feedback', label: 'Feedback', icon: <Flag size={18} /> },
    { href: '/settings', label: 'Settings', icon: <Settings size={18} /> },
  ]

  const visibleItems = navItems.filter(item => {
    if (item.adminOnly && !isAdmin) return false
    if (item.smOnly && !isSm && !isAdmin) return false
    return true
  })

  async function handleSignOut() {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/login')
  }

  return (
    <aside className="hidden md:flex w-60 flex-col bg-white border-r border-gray-200 h-screen overflow-y-auto flex-shrink-0">
      {/* Brand */}
      <div className="p-5 border-b border-gray-100">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 bg-brand-600 rounded-lg flex items-center justify-center">
            <span className="text-white font-black text-sm">E</span>
          </div>
          <div>
            <div className="font-bold text-sm text-gray-900 leading-tight">Elevate</div>
            <div className="text-xs text-gray-400">Office Tracker</div>
          </div>
        </div>
      </div>

      {/* User info */}
      <div className="px-4 py-3 border-b border-gray-100">
        <div className="flex items-center gap-2.5">
          <div
            className="w-9 h-9 rounded-full flex-shrink-0 flex items-center justify-center text-white text-sm font-bold"
            style={{ backgroundColor: profile.color_groups?.hex_color ?? '#4f46e5' }}
          >
            {profile.full_name.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()}
          </div>
          <div className="min-w-0">
            <div className="text-sm font-semibold text-gray-900 truncate">{profile.full_name}</div>
            <div className="text-xs text-gray-400 flex items-center gap-1">
              <span>{profile.member_id ?? 'Pending ID'}</span>
              {profile.is_new_member && (
                <span className="bg-brand-100 text-brand-700 px-1.5 py-0.5 rounded text-[10px] font-bold">NEW</span>
              )}
            </div>
          </div>
        </div>
        <div className="mt-2">
          <span className="text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full font-medium">
            {getStatusLabel(profile.status)}
          </span>
          {(profile.is_admin || profile.is_director) && (
            <span className="ml-1 text-xs bg-brand-100 text-brand-700 px-2 py-0.5 rounded-full font-medium">
              {profile.is_admin ? 'Admin' : 'Director'}
            </span>
          )}
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 p-3 space-y-0.5">
        {visibleItems.map(item => {
          const active = pathname === item.href || pathname.startsWith(item.href + '/')
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                active
                  ? 'bg-brand-600 text-white'
                  : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'
              }`}
            >
              {item.icon}
              {item.label}
              {active && <ChevronRight size={14} className="ml-auto" />}
            </Link>
          )
        })}
      </nav>

      {/* Sign out */}
      <div className="p-3 border-t border-gray-100">
        <button
          onClick={handleSignOut}
          className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-gray-500 hover:bg-red-50 hover:text-red-600 transition-colors"
        >
          <LogOut size={18} />
          Sign Out
        </button>
      </div>
    </aside>
  )
}
