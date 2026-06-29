export type UserStatus =
  | 'member'
  | 'distributor'
  | 'manager'
  | 'senior_manager'
  | 'executive_manager'
  | 'director'

export const STATUS_LABELS: Record<UserStatus, string> = {
  member: 'Member',
  distributor: 'Distributor',
  manager: 'Manager',
  senior_manager: 'Senior Manager',
  executive_manager: 'Executive Manager',
  director: 'Director',
}

export const STATUS_ORDER: UserStatus[] = [
  'member', 'distributor', 'manager',
  'senior_manager', 'executive_manager', 'director',
]

export function isSmOrAbove(status: UserStatus) {
  return ['senior_manager', 'executive_manager', 'director'].includes(status)
}

export function isManagerOrBelow(status: UserStatus) {
  return ['member', 'distributor', 'manager'].includes(status)
}

export interface ColorGroup {
  id: string
  name: string
  code: string
  hex_color: string
  member_count: number
  created_at: string
}

export interface Profile {
  id: string
  full_name: string
  email: string
  member_id: string | null
  status: UserStatus
  color_group_id: string | null
  sponsor_id: string | null
  upline_sm_id: string | null
  is_admin: boolean
  is_director: boolean
  approved: boolean
  rejected: boolean
  rejection_reason: string | null
  profile_picture: string | null
  about: string | null
  phone: string | null
  week_number: number
  week_confirmed: boolean
  is_new_member: boolean
  new_member_month: string | null
  is_office_already: boolean
  created_at: string
  updated_at: string
  color_groups?: ColorGroup
  sponsor?: Pick<Profile, 'id' | 'full_name' | 'member_id'>
  upline_sm?: Pick<Profile, 'id' | 'full_name' | 'member_id'>
}

export interface Attendance {
  id: string
  user_id: string
  date: string
  sign_in_time: string | null
  sign_out_time: string | null
  is_night_session: boolean
  sign_in_note: string | null
  sign_out_note: string | null
  late_in: boolean
  late_out: boolean
  created_at: string
  profiles?: Pick<Profile, 'id' | 'full_name' | 'member_id' | 'color_group_id'>
}

export interface WeeklyEarning {
  id: string
  user_id: string
  week_start: string
  week_end: string
  amount_usd: number
  recorded_by: string | null
  notes: string | null
  created_at: string
  updated_at: string
  profiles?: Pick<Profile, 'id' | 'full_name' | 'member_id' | 'status' | 'color_group_id'>
}

export interface ScoutingRecord {
  id: string
  user_id: string
  business_name: string
  rating: string | null
  reviews: string | null
  band: string | null
  profile_link: string | null
  industry: string | null
  email: string | null
  match_score: string | null
  issues_found: string | null
  status: string
  message_sent: string | null
  their_reply: string | null
  source: string
  scouted_at: string
  upload_batch_id: string | null
  profiles?: Pick<Profile, 'id' | 'full_name' | 'member_id'>
}

export interface Event {
  id: string
  title: string
  description: string | null
  event_date: string
  event_time: string | null
  location: string | null
  created_by: string | null
  created_at: string
  profiles?: Pick<Profile, 'id' | 'full_name'>
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

export interface AppSettings {
  app_name: string
  app_logo: string
  about_us: string
  primary_color: string
  font_family: string
}

// Attendance time rules
export const ATTENDANCE_RULES = {
  // Mon-Thu
  weekday: { sign_in_after: '11:00', sign_out_after: '17:00' },
  // Friday
  friday: { sign_in_after: '14:00', sign_out_after: '19:00' },
  // Night (any day)
  night: { sign_in_after: '22:00', sign_out_after: null },
}
