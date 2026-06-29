import { format, startOfWeek, endOfWeek, addWeeks, parseISO } from 'date-fns'
import type { UserStatus } from './types'

export function cn(...inputs: (string | undefined | null | false)[]) {
  return inputs.filter(Boolean).join(' ')
}

export function formatDate(date: string | Date, fmt = 'MMM d, yyyy') {
  const d = typeof date === 'string' ? parseISO(date) : date
  return format(d, fmt)
}

export function formatTime(ts: string | null) {
  if (!ts) return '—'
  return format(parseISO(ts), 'h:mm a')
}

export function formatCurrency(amount: number) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(amount)
}

// Week starts Saturday, ends Friday
export function getWeekBounds(date = new Date()) {
  const start = startOfWeek(date, { weekStartsOn: 6 })
  const end = endOfWeek(date, { weekStartsOn: 6 })
  return {
    week_start: format(start, 'yyyy-MM-dd'),
    week_end: format(end, 'yyyy-MM-dd'),
  }
}

export function getWeekLabel(weekStart: string) {
  const start = parseISO(weekStart)
  const end = addWeeks(start, 1)
  return `${format(start, 'MMM d')} – ${format(end, 'MMM d, yyyy')}`
}

export function getCurrentMonth() {
  return format(new Date(), 'yyyy-MM')
}

export function getStatusColor(status: UserStatus): string {
  const colors: Record<UserStatus, string> = {
    member: 'bg-gray-100 text-gray-700',
    distributor: 'bg-blue-100 text-blue-700',
    manager: 'bg-green-100 text-green-700',
    senior_manager: 'bg-purple-100 text-purple-700',
    executive_manager: 'bg-orange-100 text-orange-700',
    director: 'bg-red-100 text-red-700',
  }
  return colors[status] ?? 'bg-gray-100 text-gray-700'
}

export function getStatusLabel(status: UserStatus): string {
  const labels: Record<UserStatus, string> = {
    member: 'Member',
    distributor: 'Distributor',
    manager: 'Manager',
    senior_manager: 'Senior Manager',
    executive_manager: 'Executive Manager',
    director: 'Director',
  }
  return labels[status] ?? status
}

export function isSmOrAbove(status: UserStatus) {
  return ['senior_manager', 'executive_manager', 'director'].includes(status)
}

export function isManagerOrBelow(status: UserStatus) {
  return ['member', 'distributor', 'manager'].includes(status)
}

export function getAttendanceWindow(date: Date = new Date()) {
  const day = date.getDay()
  const hour = date.getHours()
  if (hour >= 21) return 'night'
  if (day === 5) return 'friday'
  if (day >= 1 && day <= 4) return 'weekday'
  return null
}

export function isSignInAllowed(date: Date = new Date(), isNight = false) {
  const day = date.getDay()
  const hour = date.getHours()
  const minute = date.getMinutes()
  const timeMinutes = hour * 60 + minute
  if (isNight) return timeMinutes >= 22 * 60
  if (day === 5) return timeMinutes >= 14 * 60
  if (day >= 1 && day <= 4) return timeMinutes >= 11 * 60
  return false
}

export function isSignOutAllowed(date: Date = new Date(), isNight = false) {
  if (isNight) return false
  const day = date.getDay()
  const hour = date.getHours()
  const minute = date.getMinutes()
  const timeMinutes = hour * 60 + minute
  if (day === 5) return timeMinutes >= 19 * 60
  if (day >= 1 && day <= 4) return timeMinutes >= 17 * 60
  return false
}

export function generateAvatarUrl(name: string) {
  const initials = name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(initials)}&background=4f46e5&color=fff&size=128`
}

export function truncate(str: string, len = 100) {
  return str.length > len ? str.slice(0, len) + '…' : str
}

export function getDayAttendanceStats(attendances: { sign_in_time: string | null }[]) {
  return attendances.filter(a => a.sign_in_time !== null).length
}
