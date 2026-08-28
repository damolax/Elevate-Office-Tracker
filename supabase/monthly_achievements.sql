-- ELEVATE OFFICE TRACKER — FINALIZED MONTHLY ACHIEVEMENTS
-- Run once in Supabase SQL Editor. Safe to run repeatedly.

create table if not exists monthly_achievements (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  month_str text not null check (month_str ~ '^\d{4}-\d{2}$'),
  category text not null check (category in (
    'top_earner',
    'top_scout',
    'consistent_earner',
    'punctuality',
    'attendance'
  )),
  rank integer not null default 1 check (rank = 1),
  value numeric,
  detail text,
  finalized_at timestamptz not null default now(),
  unique(month_str, category)
);

create index if not exists monthly_achievements_user_idx
  on monthly_achievements (user_id, month_str desc);

alter table monthly_achievements enable row level security;

drop policy if exists "Anyone approved can view monthly achievements" on monthly_achievements;
create policy "Anyone approved can view monthly achievements" on monthly_achievements
  for select using (
    exists (select 1 from profiles where id = auth.uid() and approved = true)
  );

drop policy if exists "Admins manage monthly achievements" on monthly_achievements;
create policy "Admins manage monthly achievements" on monthly_achievements
  for all using (is_admin_or_director());

-- Finalizes one COMPLETED calendar month. The unique(month_str, category)
-- constraint makes this immutable/idempotent: once the winner is recorded,
-- rerunning this function does not replace them if historical data changes.
create or replace function finalize_monthly_achievements(p_month_str text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month_start date;
  v_month_end date;
  v_user_id uuid;
  v_value numeric;
begin
  if p_month_str !~ '^\d{4}-\d{2}$' then
    raise exception 'Invalid month format. Expected YYYY-MM';
  end if;

  v_month_start := to_date(p_month_str || '-01', 'YYYY-MM-DD');
  v_month_end := (v_month_start + interval '1 month - 1 day')::date;

  -- Never award an incomplete/current/future month.
  if v_month_end >= current_date then
    return;
  end if;

  -- TOP EARNER — sum weekly earnings assigned to the month.
  select we.user_id, sum(we.amount_usd)
    into v_user_id, v_value
  from weekly_earnings we
  join profiles p on p.id = we.user_id
  where we.week_start >= v_month_start
    and we.week_start <= v_month_end
    and p.approved = true
  group by we.user_id
  order by sum(we.amount_usd) desc, we.user_id
  limit 1;

  if v_user_id is not null then
    insert into monthly_achievements (user_id, month_str, category, value, detail)
    values (v_user_id, p_month_str, 'top_earner', v_value, 'Highest finalized earnings for the month')
    on conflict (month_str, category) do nothing;
  end if;

  -- TOP SCOUT — contacted businesses during the calendar month.
  v_user_id := null; v_value := null;
  select sr.user_id, count(*)::numeric
    into v_user_id, v_value
  from scouting_records sr
  join profiles p on p.id = sr.user_id
  where sr.status = 'contacted'
    and sr.scouted_at >= v_month_start::timestamptz
    and sr.scouted_at < (v_month_start + interval '1 month')::timestamptz
    and p.approved = true
  group by sr.user_id
  order by count(*) desc, sr.user_id
  limit 1;

  if v_user_id is not null then
    insert into monthly_achievements (user_id, month_str, category, value, detail)
    values (v_user_id, p_month_str, 'top_scout', v_value, 'Most contacted businesses for the month')
    on conflict (month_str, category) do nothing;
  end if;

  -- CONSISTENCY CHAMPION — rank each earnings week/month contribution by the
  -- same 10-to-1 points logic used by the dashboard, then select the top score.
  v_user_id := null; v_value := null;
  with totals as (
    select we.user_id, sum(we.amount_usd) as total
    from weekly_earnings we
    join profiles p on p.id = we.user_id
    where we.week_start >= v_month_start
      and we.week_start <= v_month_end
      and p.approved = true
    group by we.user_id
  ), ranked as (
    select user_id, total,
      row_number() over (order by total desc, user_id) as rn
    from totals
  )
  select user_id, greatest(0, 11 - rn)::numeric
    into v_user_id, v_value
  from ranked
  order by greatest(0, 11 - rn) desc, total desc, user_id
  limit 1;

  if v_user_id is not null then
    insert into monthly_achievements (user_id, month_str, category, value, detail)
    values (v_user_id, p_month_str, 'consistent_earner', v_value, 'Highest finalized consistency score for the month')
    on conflict (month_str, category) do nothing;
  end if;

  -- PUNCTUALITY CHAMPION — best average minutes ahead of the day-session
  -- opening window. Friday opens 14:00; other weekdays open 11:00.
  v_user_id := null; v_value := null;
  with punctuality as (
    select
      a.user_id,
      avg(
        extract(epoch from (
          (a.date::timestamp + case
            when extract(dow from a.date) = 5 then time '14:00'
            else time '11:00'
          end) - a.sign_in_time::timestamp
        )) / 60.0
      ) as avg_minutes_early
    from attendance a
    join profiles p on p.id = a.user_id
    where a.date between v_month_start and v_month_end
      and a.sign_in_time is not null
      and coalesce(a.is_night_session, false) = false
      and p.approved = true
    group by a.user_id
  )
  select user_id, round(avg_minutes_early)::numeric
    into v_user_id, v_value
  from punctuality
  order by avg_minutes_early desc, user_id
  limit 1;

  if v_user_id is not null then
    insert into monthly_achievements (user_id, month_str, category, value, detail)
    values (v_user_id, p_month_str, 'punctuality', v_value, 'Best finalized average punctuality for the month')
    on conflict (month_str, category) do nothing;
  end if;

  -- ATTENDANCE CHAMPION — most day-session days present; punctuality breaks ties.
  v_user_id := null; v_value := null;
  with attendance_stats as (
    select
      a.user_id,
      count(*)::numeric as days,
      avg(
        extract(epoch from (
          (a.date::timestamp + case
            when extract(dow from a.date) = 5 then time '14:00'
            else time '11:00'
          end) - a.sign_in_time::timestamp
        )) / 60.0
      ) as avg_minutes_early
    from attendance a
    join profiles p on p.id = a.user_id
    where a.date between v_month_start and v_month_end
      and a.sign_in_time is not null
      and coalesce(a.is_night_session, false) = false
      and p.approved = true
    group by a.user_id
  )
  select user_id, days
    into v_user_id, v_value
  from attendance_stats
  order by days desc, avg_minutes_early desc nulls last, user_id
  limit 1;

  if v_user_id is not null then
    insert into monthly_achievements (user_id, month_str, category, value, detail)
    values (v_user_id, p_month_str, 'attendance', v_value, 'Most finalized attendance days for the month')
    on conflict (month_str, category) do nothing;
  end if;
end;
$$;

grant execute on function finalize_monthly_achievements(text) to authenticated;
