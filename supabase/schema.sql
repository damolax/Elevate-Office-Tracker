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
create policy "Anyone can view approved profiles" on profiles
  for select using (approved = true);

create policy "Users can view own profile" on profiles
  for select using (id = auth.uid());

create policy "Admins view all profiles" on profiles
  for select using (is_admin_or_director());

create policy "Users update own profile" on profiles
  for update using (id = auth.uid())
  with check (id = auth.uid());

create policy "Admins manage all profiles" on profiles
  for all using (is_admin_or_director());

create policy "Allow insert on signup" on profiles
  for insert with check (id = auth.uid());

-- COLOR GROUPS policies
create policy "Anyone can view color groups" on color_groups
  for select using (true);

create policy "Admins manage color groups" on color_groups
  for all using (is_admin_or_director());

-- ATTENDANCE policies
create policy "Users view own attendance" on attendance
  for select using (user_id = auth.uid());

create policy "SM+ view team attendance" on attendance
  for select using (is_sm_or_above());

create policy "Admins view all attendance" on attendance
  for select using (is_admin_or_director());

create policy "Users manage own attendance" on attendance
  for all using (user_id = auth.uid());

create policy "Admins manage all attendance" on attendance
  for all using (is_admin_or_director());

-- WEEKLY EARNINGS policies
create policy "Members view own earnings" on weekly_earnings
  for select using (user_id = auth.uid());

create policy "SM+ view team earnings" on weekly_earnings
  for select using (is_sm_or_above());

create policy "Admins manage earnings" on weekly_earnings
  for all using (is_admin_or_director());

-- SCOUTING policies
create policy "Users view own scouting" on scouting_records
  for select using (user_id = auth.uid());

create policy "SM+ view team scouting" on scouting_records
  for select using (is_sm_or_above());

create policy "Users manage own scouting" on scouting_records
  for all using (user_id = auth.uid());

create policy "Admins manage all scouting" on scouting_records
  for all using (is_admin_or_director());

-- EVENTS policies
create policy "Anyone authenticated can view events" on events
  for select using (auth.uid() is not null);

create policy "Admins manage events" on events
  for all using (is_admin_or_director());

-- COMMUNITY policies
create policy "Anyone authenticated can view posts" on community_posts
  for select using (auth.uid() is not null);

create policy "Users manage own posts" on community_posts
  for all using (user_id = auth.uid());

create policy "Admins manage all posts" on community_posts
  for all using (is_admin_or_director());

-- TASKS policies
create policy "Users view own tasks" on tasks
  for select using (assigned_to = auth.uid() or assigned_by = auth.uid());

create policy "SM+ view and create tasks" on tasks
  for all using (is_sm_or_above());

-- APP SETTINGS policies
create policy "Anyone can read settings" on app_settings
  for select using (true);

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

create policy "Users view own feedback" on feedback
  for select using (user_id = auth.uid());

create policy "Users create feedback" on feedback
  for insert with check (user_id = auth.uid());

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

create policy "Users view own assessments" on week_assessments
  for select using (user_id = auth.uid());

create policy "Admins manage all assessments" on week_assessments
  for all using (is_admin_or_director());

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

create policy "Users view own advancement log" on week_advancement_log
  for select using (user_id = auth.uid());

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

create policy "Anyone can view earner points" on earner_points
  for select using (true);

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
