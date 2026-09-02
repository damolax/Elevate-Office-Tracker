-- Elevate Office App — focused database security hardening
-- Prepared 2026-09-02. Review before applying to production.
--
-- Goals:
-- 1) Make aggregate views obey the querying user's underlying RLS policies.
-- 2) Protect the member ID sequence table with RLS and remove direct API access.
-- 3) Keep member ID generation working only for service-role calls or verified admin-tier users.

begin;

alter view public.monthly_earnings set (security_invoker = true);
alter view public.attendance_leaderboard set (security_invoker = true);

alter table public.member_id_sequences enable row level security;
revoke all on table public.member_id_sequences from anon, authenticated;

create or replace function public.generate_member_id(p_color_code text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_num integer;
  v_id text;
  v_role text;
begin
  v_role := auth.role();

  if v_role is distinct from 'service_role' then
    if auth.uid() is null or not exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and (p.is_admin or p.is_director or p.is_co_admin)
    ) then
      raise exception 'Not authorized to generate member IDs'
        using errcode = '42501';
    end if;
  end if;

  if p_color_code is null or btrim(p_color_code) = '' then
    raise exception 'Color code is required'
      using errcode = '22023';
  end if;

  update public.member_id_sequences
  set next_number = next_number + 1
  where color_code = upper(btrim(p_color_code))
  returning next_number - 1 into v_num;

  if not found then
    insert into public.member_id_sequences (color_code, next_number)
    values (upper(btrim(p_color_code)), 2);
    v_num := 1;
  end if;

  v_id := upper(btrim(p_color_code)) || lpad(v_num::text, 3, '0');
  return v_id;
end;
$$;

revoke execute on function public.generate_member_id(text) from public, anon;
grant execute on function public.generate_member_id(text) to authenticated, service_role;

commit;
