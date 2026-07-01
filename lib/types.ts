export type UserStatus =
  | 'member'
  | 'distributor'
  | 'manager'
  | 'senior_manager'
  | 'executive_manager'
  | 'director'
  | 'emerald_director'
  | 'sapphire_director'
  | 'ruby_director_1'
  | 'ruby_director_2'
  | 'ruby_director_3'
  | 'ruby_director_4'
  | 'ruby_director_5'
  | 'diamond_director_1'
  | 'diamond_director_2'
  | 'diamond_director_3'
  | 'diamond_director_4'
  | 'diamond_director_5'

export const STATUS_ORDER: UserStatus[] = [
  'member', 'distributor', 'manager', 'senior_manager',
  'executive_manager', 'director', 'emerald_director', 'sapphire_director',
  'ruby_director_1', 'ruby_director_2', 'ruby_director_3', 'ruby_director_4', 'ruby_director_5',
  'diamond_director_1', 'diamond_director_2', 'diamond_director_3', 'diamond_director_4', 'diamond_director_5',
]

export const STATUS_LABELS: Record<UserStatus, string> = {
  member: 'Member',
  distributor: 'Distributor',
  manager: 'Manager',
  senior_manager: 'Senior Manager',
  executive_manager: 'Executive Manager',
  director: 'Director',
  emerald_director: 'Emerald Director',
  sapphire_director: 'Sapphire Director',
  ruby_director_1: '1 Ruby Director',
  ruby_director_2: '2 Ruby Director',
  ruby_director_3: '3 Ruby Director',
  ruby_director_4: '4 Ruby Director',
  ruby_director_5: '5 Ruby Director',
  diamond_director_1: '1 Diamond Director',
  diamond_director_2: '2 Diamond Director',
  diamond_director_3: '3 Diamond Director',
  diamond_director_4: '4 Diamond Director',
  diamond_director_5: '5 Diamond Director',
}

export const STATUS_COLORS: Record<UserStatus, string> = {
  member: 'bg-gray-100 text-gray-700',
  distributor: 'bg-blue-100 text-blue-700',
  manager: 'bg-green-100 text-green-700',
  senior_manager: 'bg-purple-100 text-purple-700',
  executive_manager: 'bg-orange-100 text-orange-700',
  director: 'bg-red-100 text-red-700',
  emerald_director: 'bg-emerald-100 text-emerald-700',
  sapphire_director: 'bg-cyan-100 text-cyan-700',
  ruby_director_1: 'bg-rose-100 text-rose-700',
  ruby_director_2: 'bg-rose-200 text-rose-800',
  ruby_director_3: 'bg-rose-300 text-rose-900',
  ruby_director_4: 'bg-red-200 text-red-800',
  ruby_director_5: 'bg-red-300 text-red-900',
  diamond_director_1: 'bg-sky-100 text-sky-700',
  diamond_director_2: 'bg-sky-200 text-sky-800',
  diamond_director_3: 'bg-sky-300 text-sky-900',
  diamond_director_4: 'bg-blue-200 text-blue-800',
  diamond_director_5: 'bg-blue-300 text-blue-900',
}

// SM and above are exempt from 12-week system
export function isSmOrAbove(status: UserStatus): boolean {
  return STATUS_ORDER.indexOf(status) >= STATUS_ORDER.indexOf('senior_manager')
}

export function isManagerOrBelow(status: UserStatus): boolean {
  return STATUS_ORDER.indexOf(status) <= STATUS_ORDER.indexOf('manager')
}

export function isDirectorOrAbove(status: UserStatus): boolean {
  return STATUS_ORDER.indexOf(status) >= STATUS_ORDER.indexOf('director')
}

export function statusRank(status: UserStatus): number {
  return STATUS_ORDER.indexOf(status)
}

// Team filter: remove all people of target status or above and their downlines
// Returns IDs of people remaining (your team at that level)
export function computeTeam(
  myId: string,
  targetStatus: UserStatus,
  allProfiles: Profile[]
): string[] {
  // Get full downline of a person
  function getFullDownline(rootId: string): string[] {
    const direct = allProfiles.filter(p => p.sponsor_id === rootId).map(p => p.id)
    return [...direct, ...direct.flatMap(id => getFullDownline(id))]
  }

  const myDownline = getFullDownline(myId)
  const targetRank = statusRank(targetStatus)

  // Find everyone in my downline who is at or above target status
  const toRemove = new Set<string>()
  myDownline.forEach(id => {
    const p = allProfiles.find(x => x.id === id)
    if (p && statusRank(p.status as UserStatus) >= targetRank) {
      // Remove this person and their entire downline
      toRemove.add(id)
      getFullDownline(id).forEach(did => toRemove.add(did))
    }
  })

  return myDownline.filter(id => !toRemove.has(id))
}

// Earnings targets
export const EARNINGS_TARGETS: Partial<Record<UserStatus, number>> = {
  member: 200,    // per month, from week 4
  distributor: 300, // per month minimum
}

export type ActivityStatus =
  | 'active'
  | 'suspended'
  | 'inactive'
  | 'left_office'
  | 'another_location'
  | 'moved_to_another_office'

export const ACTIVITY_STATUS_LABELS: Record<ActivityStatus, string> = {
  active: 'Active',
  suspended: 'Suspended',
  inactive: 'Inactive',
  left_office: 'Left Office',
  another_location: 'Another Location',
  moved_to_another_office: 'Moved to Another Office',
}

export const ACTIVITY_STATUS_COLORS: Record<ActivityStatus, string> = {
  active: 'bg-green-100 text-green-700',
  suspended: 'bg-red-100 text-red-700',
  inactive: 'bg-gray-100 text-gray-500',
  left_office: 'bg-orange-100 text-orange-700',
  another_location: 'bg-blue-100 text-blue-700',
  moved_to_another_office: 'bg-purple-100 text-purple-700',
}

export const ATTENDANCE_RULES = {
  weekday: { sign_in_open: '11:00', sign_in_close: '17:00', sign_out_open: '17:00', sign_out_close: '20:00' },
  friday: { sign_in_open: '14:00', sign_in_close: '19:00', sign_out_open: '19:00', sign_out_close: '20:00' },
  night: { sign_in_open: '22:00', sign_in_close: '06:00', sign_out_open: null, sign_out_close: '11:00' },
}

export interface ColorGroup {
  id: string
  name: string
  code: string
  hex_color: string
  member_count: number
  group_leader_id: string | null
  created_at: string
}

export interface Profile {
  id: string
  full_name: string
  email: string
  phone: string | null
  member_id: string | null
  status: UserStatus
  color_group_id: string | null
  sponsor_id: string | null
  upline_sm_id: string | null
  is_admin: boolean
  is_director: boolean
  is_co_admin: boolean
  activity_status: ActivityStatus
  added_by: string | null
  approved: boolean
  rejected: boolean
  rejection_reason: string | null
  week_number: number | null
  about: string | null
  profile_picture: string | null
  last_seen: string | null
  earnings_target: number | null
  created_at: string
  color_groups?: ColorGroup
}

export interface Attendance {
  id: string
  user_id: string
  date: string
  sign_in_time: string | null
  sign_out_time: string | null
  sign_in_note: string | null
  sign_out_note: string | null
  is_night_session: boolean
  created_at: string
}

export interface Earnings {
  id: string
  user_id: string
  amount: number
  week_start: string
  week_end: string
  note: string | null
  logged_by: string | null
  created_at: string
}

export interface Notification {
  id: string
  user_id: string
  title: string
  body: string
  type: 'success' | 'error' | 'info' | 'warning'
  read: boolean
  link: string | null
  created_at: string
}

export interface CommunityPost {
  id: string
  user_id: string
  content: string
  attachment_url: string | null
  attachment_type: string | null
  created_at: string
  updated_at: string
  profiles?: Pick<Profile, 'id' | 'full_name' | 'member_id' | 'profile_picture' | 'status'>
}

export interface Task {
  id: string
  title: string
  description: string | null
  assigned_to: string
  assigned_by: string | null
  due_date: string | null
  completed: boolean
  completed_at: string | null
  created_at: string
  assignee?: Pick<Profile, 'id' | 'full_name' | 'member_id'>
  assigner?: Pick<Profile, 'id' | 'full_name'>
}

export interface ScannerSession {
  id: string
  date: string
  token: string
  created_by: string | null
  created_at: string
}

export interface AppSettings {
  app_name: string
  app_logo: string
  about_us: string
  primary_color: string
  font_family: string
}

export function getStatusLabel(status: string): string {
  return STATUS_LABELS[status as UserStatus] ?? status
}

export function getStatusColor(status: string): string {
  return STATUS_COLORS[status as UserStatus] ?? 'bg-gray-100 text-gray-600'
}
