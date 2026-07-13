#!/usr/bin/env bash
set -e
echo "Writing updated files..."

mkdir -p "app/(app)/team"
cat > "app/(app)/team/TeamClient.tsx" << 'CLAUDE_EOF_MARKER'
'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Profile, UserStatus } from '@/lib/types'
import { getStatusLabel, getStatusColor, STATUS_LABELS, STATUS_ORDER, isSmOrAbove } from '@/lib/types'
import { Users, ChevronDown, ChevronRight, Search, Calendar } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { format, subDays } from 'date-fns'

export default function TeamClient({
  profile, isAdmin, myTeam, allProfiles, viewingMember,
  availableFilters, activeFilter, teamCounts,
}: {
  profile: Profile
  isAdmin: boolean
  myTeam: Profile[]
  allProfiles: Profile[]
  viewingMember: Profile | null
  availableFilters: string[]
  activeFilter: string
  teamCounts: Record<string, number>
}) {
  const router = useRouter()
  const [search, setSearch] = useState('')
  const [activityFilter, setActivityFilter] = useState('active')
  const [expandedTree, setExpandedTree] = useState<Set<string>>(new Set())
  const [selectedMember, setSelectedMember] = useState<Profile | null>(viewingMember)
  const [memberAttendance, setMemberAttendance] = useState<any[]>([])
  const [loadingAttendance, setLoadingAttendance] = useState(false)

  function filtered(list: Profile[]) {
    return list.filter(p => {
      const matchSearch = !search ||
        p.full_name.toLowerCase().includes(search.toLowerCase()) ||
        (p.member_id ?? '').toLowerCase().includes(search.toLowerCase())
      const matchActivity = activityFilter === 'all' || p.activity_status === activityFilter
      return matchSearch && matchActivity
    })
  }

  async function viewMemberAttendance(p: Profile) {
    setSelectedMember(p)
    setLoadingAttendance(true)
    const supabase = createClient()
    const from = format(subDays(new Date(), 30), 'yyyy-MM-dd')
    const { data } = await supabase
      .from('attendance')
      .select('*')
      .eq('user_id', p.id)
      .gte('date', from)
      .order('date', { ascending: false })
    setMemberAttendance(data ?? [])
    setLoadingAttendance(false)
  }

  function toggleTree(id: string) {
    setExpandedTree(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  const teamIdSet = new Set(myTeam.map(p => p.id))

  function renderTree(parentId: string, depth = 0): React.ReactNode {
    const children = allProfiles.filter(p =>
      p.sponsor_id === parentId && teamIdSet.has(p.id) && p.activity_status === 'active'
    )
    if (!children.length) return null
    return children.map(p => {
      const hasChildren = allProfiles.some(c => c.sponsor_id === p.id && teamIdSet.has(c.id) && c.activity_status === 'active')
      const expanded = expandedTree.has(p.id)
      const cg = (p as any).color_groups
      return (
        <div key={p.id} style={{ marginLeft: depth * 18 }}>
          <div className="flex items-center gap-2 py-2 px-3 rounded-lg hover:bg-gray-50 group">
            <button onClick={() => toggleTree(p.id)}
              className={`w-5 h-5 flex items-center justify-center flex-shrink-0 ${hasChildren ? 'text-gray-400' : 'text-transparent'}`}>
              {hasChildren ? (expanded ? <ChevronDown size={14} /> : <ChevronRight size={14} />) : null}
            </button>
            <div className="w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0"
              style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
              {p.full_name.charAt(0)}
            </div>
            <div className="flex-1 min-w-0 cursor-pointer" onClick={() => viewMemberAttendance(p)}>
              <div className="text-sm font-medium truncate">{p.full_name}</div>
              <div className="text-xs text-gray-400">{p.member_id} · {getStatusLabel(p.status)}</div>
            </div>
            <span className={`badge text-xs ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
          </div>
          {expanded && renderTree(p.id, depth + 1)}
        </div>
      )
    })
  }

  const displayList = filtered(myTeam)
  const inactiveTeamMembers = myTeam.filter(p => p.activity_status !== 'active')
  const [showTree, setShowTree] = useState(true)

  return (
    <div className="max-w-6xl mx-auto space-y-5">
      {/* Team filter pills — one per available status level */}
      <div className="flex gap-2 flex-wrap">
        {availableFilters.map(f => (
          <button key={f} onClick={() => router.push(`/team?filter=${f}`)}
            className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${activeFilter === f ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
            {f === 'all' ? 'All Team' : getStatusLabel(f as UserStatus) + ' Team'}
            <span className="ml-1.5 opacity-70">({teamCounts[f] ?? 0})</span>
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">
        {/* Team list */}
        <div className="lg:col-span-2 space-y-3">
          <div className="flex gap-3 flex-wrap">
            <div className="relative flex-1 min-w-48">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input className="input pl-8" placeholder="Search name or ID…" value={search} onChange={e => setSearch(e.target.value)} />
            </div>
            <div className="flex rounded-lg border border-gray-200 overflow-hidden">
              <button onClick={() => setShowTree(true)} className={`px-3 py-1.5 text-xs font-semibold ${showTree ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>Tree</button>
              <button onClick={() => setShowTree(false)} className={`px-3 py-1.5 text-xs font-semibold ${!showTree ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>List</button>
            </div>
          </div>

          {showTree ? (
            <div className="card p-3">
              <p className="text-xs text-gray-400 px-2 pb-2">Active members in your team, organized by who sponsored whom. Click a name to see their recent attendance; use the arrows to expand.</p>
              {renderTree(profile.id) ?? <p className="text-sm text-gray-400 text-center py-8">No active team members yet.</p>}
            </div>
          ) : (
            <div className="card divide-y divide-gray-50">
              {displayList.length === 0 ? (
                <p className="text-sm text-gray-400 text-center py-8">No team members found</p>
              ) : displayList.map(p => {
                const cg = (p as any).color_groups
                const isSelected = selectedMember?.id === p.id
                return (
                  <button key={p.id} type="button"
                    className={`w-full flex items-center gap-3 p-3 text-left hover:bg-gray-50 transition-colors ${isSelected ? 'bg-indigo-50' : ''}`}
                    onClick={() => viewMemberAttendance(p)}>
                    <div className="w-9 h-9 rounded-full flex items-center justify-center text-white text-sm font-bold flex-shrink-0"
                      style={{ backgroundColor: cg?.hex_color ?? '#6366f1' }}>
                      {p.full_name.charAt(0)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-sm text-gray-900 truncate">{p.full_name}</div>
                      <div className="text-xs text-gray-400">{p.member_id ?? 'No ID'} · {cg?.name ?? '—'}</div>
                    </div>
                    <div className="text-right flex-shrink-0">
                      <span className={`badge text-xs ${getStatusColor(p.status)}`}>{getStatusLabel(p.status)}</span>
                      <div className={`text-xs mt-0.5 ${p.activity_status === 'active' ? 'text-green-500' : 'text-gray-400'}`}>
                        {p.activity_status}
                      </div>
                    </div>
                  </button>
                )
              })}
            </div>
          )}

          {/* Inactive members — separate table, not part of the tree */}
          {inactiveTeamMembers.length > 0 && (
            <div className="card">
              <div className="px-4 py-3 border-b border-gray-100 text-sm font-semibold text-gray-700">
                Inactive Members ({inactiveTeamMembers.length})
              </div>
              <div className="divide-y divide-gray-50">
                {inactiveTeamMembers.map(p => (
                  <button key={p.id} type="button"
                    className="w-full flex items-center gap-3 p-3 text-left hover:bg-gray-50 transition-colors"
                    onClick={() => viewMemberAttendance(p)}>
                    <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0 opacity-60"
                      style={{ backgroundColor: (p as any).color_groups?.hex_color ?? '#6366f1' }}>
                      {p.full_name.charAt(0)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-medium text-sm text-gray-600 truncate">{p.full_name}</div>
                      <div className="text-xs text-gray-400">{p.member_id ?? 'No ID'}</div>
                    </div>
                    <span className="badge text-xs bg-gray-100 text-gray-500">{p.activity_status}</span>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Member detail + attendance */}
        <div className="space-y-4">
          {selectedMember ? (
            <>
              <div className="card p-5">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-lg"
                      style={{ backgroundColor: (selectedMember as any).color_groups?.hex_color ?? '#6366f1' }}>
                      {selectedMember.full_name.charAt(0)}
                    </div>
                    <div>
                      <div className="font-bold text-gray-900">{selectedMember.full_name}</div>
                      <div className="text-xs text-gray-400">{selectedMember.member_id}</div>
                      <span className={`badge text-xs mt-1 ${getStatusColor(selectedMember.status)}`}>{getStatusLabel(selectedMember.status)}</span>
                    </div>
                  </div>
                </div>
                <button
                  className="w-full text-center text-xs font-semibold text-brand-600 hover:text-brand-700 bg-brand-50 rounded-lg py-2 mb-3"
                  onClick={() => router.push(`/member/${selectedMember.id}`)}>
                  View Full Profile →
                </button>
                <div className="text-xs text-gray-500 space-y-1">
                  <div>Week: {selectedMember.week_number ?? '—'}</div>
                  <div>Group: {(selectedMember as any).color_groups?.name ?? '—'}</div>
                  <div>Activity: {selectedMember.activity_status}</div>
                  {selectedMember.last_seen && (
                    <div>Last seen: {format(new Date(selectedMember.last_seen), 'MMM d, HH:mm')}</div>
                  )}
                </div>
              </div>

              <div className="card p-4">
                <div className="flex items-center gap-2 mb-3">
                  <Calendar size={15} className="text-gray-400" />
                  <span className="font-semibold text-sm text-gray-900">Last 30 Days Attendance</span>
                </div>
                {loadingAttendance ? (
                  <div className="text-xs text-gray-400 text-center py-4">Loading…</div>
                ) : memberAttendance.length === 0 ? (
                  <div className="text-xs text-gray-400 text-center py-4">No attendance in last 30 days</div>
                ) : (
                  <div className="space-y-1.5">
                    {memberAttendance.map(a => (
                      <div key={a.id} className="flex items-center justify-between text-xs">
                        <span className="text-gray-600 font-medium">{format(new Date(a.date), 'EEE, MMM d')}</span>
                        <div className="flex gap-2">
                          <span className="text-blue-600">{a.sign_in_time ? format(new Date(a.sign_in_time), 'HH:mm') : '—'}</span>
                          <span className="text-gray-400">→</span>
                          <span className="text-orange-600">{a.sign_out_time ? format(new Date(a.sign_out_time), 'HH:mm') : '—'}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="card p-6 text-center">
              <Users size={32} className="mx-auto mb-2 text-gray-300" />
              <p className="text-sm text-gray-400">Click a team member to view their details and attendance</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
CLAUDE_EOF_MARKER

mkdir -p "supabase"
cat > "supabase/schema.sql" << 'CLAUDE_EOF_MARKER'
-- =============================================
-- ELEVATE OFFICE TRACKER — COMPLETE SCHEMA
-- Run this in Supabase SQL Editor
-- =============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- =============================================
-- COLOR GROUPS
-- =============================================
create table if not exists color_groups (
  id uuid primary key default uuid_generate_v4(),
  name text not null unique,
  code text not null unique,        -- RED, GRN, BLU, etc.
  hex_color text not null default '#6366f1',
  member_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- Insert default color groups
insert into color_groups (name, code, hex_color) values
  ('Red',    'RED', '#ef4444'),
  ('Blue',   'BLU', '#3b82f6'),
  ('Green',  'GRN', '#22c55e'),
  ('Orange', 'ORG', '#f97316'),
  ('Yellow', 'YEL', '#eab308'),
  ('Purple', 'PRP', '#a855f7'),
  ('White',  'WHT', '#e5e7eb'),
  ('Gold',   'GLD', '#f59e0b'),
  ('Silver', 'SLV', '#94a3b8'),
  ('Black',  'BLK', '#1e293b')
on conflict do nothing;

-- =============================================
-- PROFILES (extends Supabase auth.users)
-- =============================================
do $$ begin
  create type user_status as enum (
    'member', 'distributor', 'manager',
    'senior_manager', 'executive_manager', 'director'
  );
exception when duplicate_object then null;
end $$;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null unique,
  member_id text unique,             -- e.g. RED001
  status user_status not null default 'member',
  color_group_id uuid references color_groups(id),
  sponsor_id uuid references profiles(id),
  upline_sm_id uuid references profiles(id),
  is_admin boolean not null default false,
  is_director boolean not null default false,
  approved boolean not null default false,
  rejected boolean not null default false,
  rejection_reason text,
  profile_picture text,              -- storage URL
  about text,
  phone text,
  week_number integer not null default 1 check (week_number between 1 and 12),
  week_confirmed boolean not null default false,
  is_new_member boolean not null default false,
  new_member_month text,             -- YYYY-MM
  is_office_already boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trigger: auto-update updated_at
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists profiles_updated_at on profiles;
create trigger profiles_updated_at before update on profiles
  for each row execute function update_updated_at();

-- =============================================
-- ATTENDANCE
-- =============================================
create table if not exists attendance (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  date date not null,
  sign_in_time timestamptz,
  sign_out_time timestamptz,
  is_night_session boolean not null default false,
  sign_in_note text,                 -- what did you do with your business yesterday/weekend
  sign_out_note text,                -- what did you do in the office today
  late_in boolean not null default false,
  late_out boolean not null default false,
  created_at timestamptz not null default now(),
  unique(user_id, date, is_night_session)
);

-- =============================================
-- WEEKLY EARNINGS
-- =============================================
create table if not exists weekly_earnings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  week_start date not null,          -- Saturday
  week_end date not null,            -- Friday
  amount_usd numeric(12,2) not null default 0,
  recorded_by uuid references profiles(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, week_start)
);

drop trigger if exists weekly_earnings_updated_at on weekly_earnings;
create trigger weekly_earnings_updated_at before update on weekly_earnings
  for each row execute function update_updated_at();

-- =============================================
-- SCOUTING RECORDS
-- =============================================
create table if not exists scouting_records (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  business_name text not null,
  rating text,
  reviews text,
  band text,
  profile_link text,
  industry text,
  email text,
  match_score text,
  issues_found text,
  status text default 'Pending',
  message_sent text,
  their_reply text,
  source text default 'Scout App',
  scouted_at timestamptz not null default now(),
  upload_batch_id uuid,
  unique(user_id, profile_link)
);

-- =============================================
-- EVENTS
-- =============================================
create table if not exists events (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  event_date date not null,
  event_time time,
  location text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

-- =============================================
-- COMMUNITY POSTS
-- =============================================
create table if not exists community_posts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  attachment_url text,
  attachment_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists community_posts_updated_at on community_posts;
create trigger community_posts_updated_at before update on community_posts
  for each row execute function update_updated_at();

-- =============================================
-- TASKS (assigned by SM to team)
-- =============================================
create table if not exists tasks (
  id uuid primary key default uuid_generate_v4(),
  title text not null,
  description text,
  assigned_to uuid not null references profiles(id) on delete cascade,
  assigned_by uuid references profiles(id),
  due_date date,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

-- =============================================
-- APP SETTINGS
-- =============================================
create table if not exists app_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);

insert into app_settings (key, value) values
  ('app_name', 'Elevate Office Tracker'),
  ('app_logo', ''),
  ('about_us', 'Welcome to Elevate — where excellence meets accountability.'),
  ('primary_color', '#4f46e5'),
  ('font_family', 'Inter')
on conflict do nothing;

-- =============================================
-- MEMBER ID SEQUENCE per color group
-- =============================================
create table if not exists member_id_sequences (
  color_code text primary key,
  next_number integer not null default 1
);

insert into member_id_sequences (color_code, next_number)
select code, 1 from color_groups
on conflict do nothing;

-- Function to generate next member ID
create or replace function generate_member_id(p_color_code text)
returns text language plpgsql as $$
declare
  v_num integer;
  v_id text;
begin
  update member_id_sequences
  set next_number = next_number + 1
  where color_code = p_color_code
  returning next_number - 1 into v_num;

  if not found then
    insert into member_id_sequences (color_code, next_number) values (p_color_code, 2);
    v_num := 1;
  end if;

  v_id := p_color_code || lpad(v_num::text, 3, '0');
  return v_id;
end; $$;

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================

alter table profiles enable row level security;
alter table attendance enable row level security;
alter table weekly_earnings enable row level security;
alter table scouting_records enable row level security;
alter table events enable row level security;
alter table community_posts enable row level security;
alter table tasks enable row level security;
alter table color_groups enable row level security;
alter table app_settings enable row level security;

-- Helper: get current user's profile
create or replace function get_my_profile()
returns profiles language sql security definer stable as $$
  select * from profiles where id = auth.uid();
$$;

-- Helper: is admin or director
create or replace function is_admin_or_director()
returns boolean language sql security definer stable as $$
  select coalesce(
    (select is_admin or is_director or is_co_admin from profiles where id = auth.uid()),
    false
  );
$$;

-- Helper: is senior manager or above
create or replace function is_sm_or_above()
returns boolean language sql security definer stable as $$
  select coalesce(
    (select status in ('senior_manager','executive_manager','director')
     from profiles where id = auth.uid()),
    false
  );
$$;

-- PROFILES policies
drop policy if exists "Anyone can view approved profiles" on profiles;
create policy "Anyone can view approved profiles" on profiles
  for select using (approved = true);

drop policy if exists "Users can view own profile" on profiles;
create policy "Users can view own profile" on profiles
  for select using (id = auth.uid());

drop policy if exists "Admins view all profiles" on profiles;
create policy "Admins view all profiles" on profiles
  for select using (is_admin_or_director());

drop policy if exists "Users update own profile" on profiles;
create policy "Users update own profile" on profiles
  for update using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists "Admins manage all profiles" on profiles;
create policy "Admins manage all profiles" on profiles
  for all using (is_admin_or_director());

drop policy if exists "Allow insert on signup" on profiles;
create policy "Allow insert on signup" on profiles
  for insert with check (id = auth.uid());

-- COLOR GROUPS policies
drop policy if exists "Anyone can view color groups" on color_groups;
create policy "Anyone can view color groups" on color_groups
  for select using (true);

drop policy if exists "Admins manage color groups" on color_groups;
create policy "Admins manage color groups" on color_groups
  for all using (is_admin_or_director());

-- ATTENDANCE policies
drop policy if exists "Users view own attendance" on attendance;
create policy "Users view own attendance" on attendance
  for select using (user_id = auth.uid());

drop policy if exists "SM+ view team attendance" on attendance;
create policy "SM+ view team attendance" on attendance
  for select using (is_sm_or_above());

drop policy if exists "Admins view all attendance" on attendance;
create policy "Admins view all attendance" on attendance
  for select using (is_admin_or_director());

drop policy if exists "Users manage own attendance" on attendance;
create policy "Users manage own attendance" on attendance
  for all using (user_id = auth.uid());

drop policy if exists "Admins manage all attendance" on attendance;
create policy "Admins manage all attendance" on attendance
  for all using (is_admin_or_director());

-- WEEKLY EARNINGS policies
drop policy if exists "Members view own earnings" on weekly_earnings;
create policy "Members view own earnings" on weekly_earnings
  for select using (user_id = auth.uid());

drop policy if exists "SM+ view team earnings" on weekly_earnings;
create policy "SM+ view team earnings" on weekly_earnings
  for select using (is_sm_or_above());

drop policy if exists "Admins manage earnings" on weekly_earnings;
create policy "Admins manage earnings" on weekly_earnings
  for all using (is_admin_or_director());

-- SCOUTING policies
drop policy if exists "Users view own scouting" on scouting_records;
create policy "Users view own scouting" on scouting_records
  for select using (user_id = auth.uid());

drop policy if exists "SM+ view team scouting" on scouting_records;
create policy "SM+ view team scouting" on scouting_records
  for select using (is_sm_or_above());

drop policy if exists "Users manage own scouting" on scouting_records;
create policy "Users manage own scouting" on scouting_records
  for all using (user_id = auth.uid());

drop policy if exists "Admins manage all scouting" on scouting_records;
create policy "Admins manage all scouting" on scouting_records
  for all using (is_admin_or_director());

-- EVENTS policies
drop policy if exists "Anyone authenticated can view events" on events;
create policy "Anyone authenticated can view events" on events
  for select using (auth.uid() is not null);

drop policy if exists "Admins manage events" on events;
create policy "Admins manage events" on events
  for all using (is_admin_or_director());

-- COMMUNITY policies
drop policy if exists "Anyone authenticated can view posts" on community_posts;
create policy "Anyone authenticated can view posts" on community_posts
  for select using (auth.uid() is not null);

drop policy if exists "Users manage own posts" on community_posts;
create policy "Users manage own posts" on community_posts
  for all using (user_id = auth.uid());

drop policy if exists "Admins manage all posts" on community_posts;
create policy "Admins manage all posts" on community_posts
  for all using (is_admin_or_director());

-- TASKS policies
drop policy if exists "Users view own tasks" on tasks;
create policy "Users view own tasks" on tasks
  for select using (assigned_to = auth.uid() or assigned_by = auth.uid());

drop policy if exists "SM+ view and create tasks" on tasks;
create policy "SM+ view and create tasks" on tasks
  for all using (is_sm_or_above());

-- APP SETTINGS policies
drop policy if exists "Anyone can read settings" on app_settings;
create policy "Anyone can read settings" on app_settings
  for select using (true);

drop policy if exists "Admins update settings" on app_settings;
create policy "Admins update settings" on app_settings
  for all using (is_admin_or_director());

-- =============================================
-- FEEDBACK
-- =============================================
create table if not exists feedback (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  message text not null,
  category text not null default 'general',  -- general, bug, feature, complaint
  status text not null default 'open',        -- open, in_review, resolved
  admin_response text,
  responded_by uuid references profiles(id),
  responded_at timestamptz,
  created_at timestamptz not null default now()
);

alter table feedback enable row level security;

drop policy if exists "Users view own feedback" on feedback;
create policy "Users view own feedback" on feedback
  for select using (user_id = auth.uid());

drop policy if exists "Users create feedback" on feedback;
create policy "Users create feedback" on feedback
  for insert with check (user_id = auth.uid());

drop policy if exists "Admins manage all feedback" on feedback;
create policy "Admins manage all feedback" on feedback
  for all using (is_admin_or_director());

-- =============================================
-- STORAGE BUCKETS (run separately in dashboard)
-- =============================================
-- Create buckets: 'avatars' (public), 'attachments' (public)
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('attachments', 'attachments', true) on conflict (id) do nothing;

-- =============================================
-- SEED: Admin user setup
-- After running this schema, sign up normally, then run this in SQL Editor:
-- UPDATE profiles SET is_admin = true, is_director = true, approved = true,
--   status = 'director', week_number = 12
--   WHERE email = 'YOUR_ADMIN_EMAIL_HERE';
-- =============================================

-- =============================================
-- WEEK TRACKING SYSTEM
-- =============================================

-- Weekly assessment submissions
create table if not exists week_assessments (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  week_number integer not null check (week_number between 1 and 12),
  submitted boolean not null default false,
  submitted_at timestamptz,
  graded boolean not null default false,
  graded_at timestamptz,
  graded_by uuid references profiles(id),
  grade text,                          -- pass / fail / excellent
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, week_number)
);

alter table week_assessments enable row level security;

drop policy if exists "Users view own assessments" on week_assessments;
create policy "Users view own assessments" on week_assessments
  for select using (user_id = auth.uid());

drop policy if exists "Admins manage all assessments" on week_assessments;
create policy "Admins manage all assessments" on week_assessments
  for all using (is_admin_or_director());

drop policy if exists "SM view team assessments" on week_assessments;
create policy "SM view team assessments" on week_assessments
  for select using (is_sm_or_above());

-- Week advancement log (tracks who advanced, who repeated, pardons)
create table if not exists week_advancement_log (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  from_week integer not null,
  to_week integer not null,
  action text not null,               -- 'advanced' | 'repeated' | 'pardoned'
  attendance_days integer not null default 0,
  assessment_submitted boolean not null default false,
  assessment_graded boolean not null default false,
  admin_notes text,
  actioned_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

alter table week_advancement_log enable row level security;

drop policy if exists "Users view own advancement log" on week_advancement_log;
create policy "Users view own advancement log" on week_advancement_log
  for select using (user_id = auth.uid());

drop policy if exists "Admins manage advancement log" on week_advancement_log;
create policy "Admins manage advancement log" on week_advancement_log
  for all using (is_admin_or_director());

-- Absence email log (tracks which emails were sent to avoid duplicates)
create table if not exists absence_emails (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  email_type text not null,           -- 'daily_miss' | 'weekly_summary'
  sent_at timestamptz not null default now(),
  date_missed date,                   -- for daily miss
  week_number integer,                -- for weekly summary
  miss_count integer,                 -- how many days missed that week
  delivered boolean not null default true,
  unique(user_id, email_type, date_missed)
);

alter table absence_emails enable row level security;

drop policy if exists "Admins manage absence emails" on absence_emails;
create policy "Admins manage absence emails" on absence_emails
  for all using (is_admin_or_director());

-- =============================================
-- ACTIVITY STATUS & MONTHLY EARNINGS
-- =============================================

-- Add activity_status to profiles
alter table profiles add column if not exists activity_status text not null default 'active'
  check (activity_status in ('active','suspended','inactive','left_office','another_location','moved_to_another_office'));

-- Monthly earnings view
create or replace view monthly_earnings as
select
  user_id,
  date_trunc('month', week_start::date)::date as month,
  to_char(week_start::date, 'YYYY-MM') as month_str,
  sum(amount_usd) as total_usd,
  count(*) as weeks_with_earnings
from weekly_earnings
group by user_id, date_trunc('month', week_start::date)::date, to_char(week_start::date, 'YYYY-MM');

-- =============================================
-- GROUP LEADER & CONSISTENT EARNER POINTS
-- =============================================

-- Add is_group_leader to profiles (set when member_id ends in 001)
alter table profiles add column if not exists is_group_leader boolean not null default false;

-- Consistent earner points table
create table if not exists earner_points (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  month_str text not null,           -- 'YYYY-MM'
  rank integer not null,             -- 1st, 2nd, 3rd etc
  points integer not null,           -- 10,9,8...1,0
  amount_usd numeric not null,
  created_at timestamptz not null default now(),
  unique(user_id, month_str)
);

alter table earner_points enable row level security;

drop policy if exists "Anyone can view earner points" on earner_points;
create policy "Anyone can view earner points" on earner_points
  for select using (true);

drop policy if exists "Admins manage earner points" on earner_points;
create policy "Admins manage earner points" on earner_points
  for all using (is_admin_or_director());

-- Function: auto-calculate and upsert earner points for a month
create or replace function calculate_earner_points(p_month_str text)
returns void as $$
declare
  r record;
  v_rank integer := 1;
  v_points integer;
begin
  -- Delete existing points for this month
  delete from earner_points where month_str = p_month_str;

  -- Recalculate from weekly_earnings
  for r in (
    select
      p.id as user_id,
      sum(we.amount_usd) as total_usd
    from weekly_earnings we
    join profiles p on p.id = we.user_id
    where to_char(we.week_start::date, 'YYYY-MM') = p_month_str
      and p.status in ('member','distributor','manager','executive_manager')
      and p.approved = true
    group by p.id
    order by sum(we.amount_usd) desc
  ) loop
    v_points := greatest(0, 11 - v_rank); -- 1st=10, 2nd=9...10th=1, 11th+=0
    if v_rank > 10 then v_points := 0; end if;

    insert into earner_points (user_id, month_str, rank, points, amount_usd)
    values (r.user_id, p_month_str, v_rank, v_points, r.total_usd);

    v_rank := v_rank + 1;
  end loop;
end;
$$ language plpgsql security definer;

-- =============================================
-- FIX: is_co_admin column (referenced throughout the app code
-- but was missing from the schema — caused profile queries that
-- explicitly select it, e.g. app/scanner/page.tsx, to error out).
-- Safe to run multiple times.
-- =============================================
alter table profiles add column if not exists is_co_admin boolean not null default false;

-- =============================================
-- FIX: group_leader_id column on color_groups (exists live but was
-- missing from this schema file — documenting it here for consistency).
-- =============================================
alter table color_groups add column if not exists group_leader_id uuid references profiles(id);

-- =============================================
-- FEATURE: auto-create a color group when someone is promoted to
-- Senior Manager (or above) and doesn't already lead one. They become
-- the group's 001. No two Senior Managers ever share a color group
-- (enforced already in app code for manual assignment; this covers
-- the automatic case on promotion).
-- =============================================
create or replace function auto_create_sm_color_group()
returns trigger language plpgsql as $$
declare
  v_base_code text;
  v_code text;
  v_suffix int := 0;
  v_group_id uuid;
  v_group_name text;
  v_name_suffix int := 0;
begin
  if new.status in ('senior_manager','executive_manager','director')
     and (old.status is distinct from new.status)
     and old.status not in ('senior_manager','executive_manager','director') then

    -- Skip if they already lead a color group
    if exists (select 1 from color_groups where group_leader_id = new.id) then
      return new;
    end if;

    v_base_code := upper(regexp_replace(coalesce(split_part(new.full_name, ' ', 1), 'GRP'), '[^a-zA-Z]', '', 'g'));
    v_base_code := left(nullif(v_base_code, ''), 6);
    if v_base_code is null then v_base_code := 'GRP'; end if;
    v_code := v_base_code;
    while exists (select 1 from color_groups where code = v_code) loop
      v_suffix := v_suffix + 1;
      v_code := v_base_code || v_suffix::text;
    end loop;

    v_group_name := new.full_name || '''s Group';
    while exists (select 1 from color_groups where name = v_group_name) loop
      v_name_suffix := v_name_suffix + 1;
      v_group_name := new.full_name || '''s Group ' || v_name_suffix::text;
    end loop;

    insert into color_groups (name, code, hex_color, group_leader_id)
    values (v_group_name, v_code, '#' || substr(md5(random()::text), 1, 6), new.id)
    returning id into v_group_id;

    insert into member_id_sequences (color_code, next_number) values (v_code, 2)
    on conflict (color_code) do nothing;

    new.color_group_id := v_group_id;
    if new.member_id is null then
      new.member_id := v_code || '001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_auto_create_sm_color_group on profiles;
create trigger trg_auto_create_sm_color_group
before update on profiles
for each row execute function auto_create_sm_color_group();

-- =============================================
-- FEATURE: track who granted co-admin status, so Directors and Co-Admins
-- can each promote exactly one other co-admin from their own side, while
-- the main Admin can still remove anyone's co-admin status regardless of
-- who granted it.
-- =============================================
alter table profiles add column if not exists co_admin_assigned_by uuid references profiles(id);

-- =============================================
-- NOTIFICATIONS (was referenced in app code but never defined here —
-- documenting it properly now, alongside reviving the notification bell).
-- =============================================
create table if not exists notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'info', -- 'info' | 'success' | 'warning'
  link text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table notifications enable row level security;

drop policy if exists "Users view own notifications" on notifications;
create policy "Users view own notifications" on notifications
  for select using (user_id = auth.uid());

drop policy if exists "Users update own notifications" on notifications;
create policy "Users update own notifications" on notifications
  for update using (user_id = auth.uid());

-- Any authenticated user can create a notification FOR someone else (e.g. a
-- teammate signing in triggers a notification insert targeting other users).
-- This mirrors how the app already inserts notifications from client code.
drop policy if exists "Authenticated users can create notifications" on notifications;
create policy "Authenticated users can create notifications" on notifications
  for insert with check (auth.uid() is not null);

create index if not exists notifications_user_id_created_at_idx
  on notifications (user_id, created_at desc);

-- =============================================
-- ACTIVITY FEED — a global, shared feed everyone can see (distinct from the
-- per-user `notifications` table above). Powers the "someone signed in",
-- "earnings recorded", "new community post", "X just joined the team" feed.
-- =============================================
create table if not exists activity_events (
  id uuid primary key default uuid_generate_v4(),
  type text not null, -- 'sign_in' | 'sign_out' | 'earning' | 'community_post' | 'new_member'
  message text not null,
  actor_id uuid references profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table activity_events enable row level security;

drop policy if exists "Anyone approved can view activity" on activity_events;
create policy "Anyone approved can view activity" on activity_events
  for select using (
    exists (select 1 from profiles where id = auth.uid() and approved = true)
  );

drop policy if exists "Authenticated users can post activity" on activity_events;
create policy "Authenticated users can post activity" on activity_events
  for insert with check (auth.uid() is not null);

create index if not exists activity_events_created_at_idx on activity_events (created_at desc);

-- =============================================
-- FIX: dashboard leaderboards (Top Earners, Consistent Earners, Top
-- Punctuality, Most Consistent Attendance, Top Scouts, Group Scouting) were
-- silently empty for regular Members/Distributors/Managers — not a bug in
-- app code, but RLS itself blocking them from seeing anyone else's rows on
-- these tables (only "own row", SM+, or admin could see everything). These
-- leaderboards are meant to be visible to the whole team, so any approved
-- user can now READ (not write) all rows on these three tables. Write access
-- is untouched — still just "own row" or admin/director/co-admin.
-- =============================================
drop policy if exists "Approved users view all earnings for leaderboards" on weekly_earnings;
create policy "Approved users view all earnings for leaderboards" on weekly_earnings
  for select using (exists (select 1 from profiles where id = auth.uid() and approved = true));

drop policy if exists "Approved users view all attendance for leaderboards" on attendance;
create policy "Approved users view all attendance for leaderboards" on attendance
  for select using (exists (select 1 from profiles where id = auth.uid() and approved = true));

drop policy if exists "Approved users view all scouting for leaderboards" on scouting_records;
create policy "Approved users view all scouting for leaderboards" on scouting_records
  for select using (exists (select 1 from profiles where id = auth.uid() and approved = true));
CLAUDE_EOF_MARKER

echo "Staging and committing..."
git add .
git commit -m "fix: RLS was blocking leaderboards for regular users; wire up the actual team tree renderer"
git push origin main
echo "Done. Vercel should start redeploying now."
echo "IMPORTANT: also re-run supabase/schema.sql in the Supabase SQL Editor for the new leaderboard read policies."
