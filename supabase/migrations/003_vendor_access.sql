-- Membrane Watch: which dashboard tables each vendor may see
--   tabs  subset of cohort (Install Cohort), geo (Geography), tds (Water Quality),
--         rows (Row-Level Detail). Empty = the vendor can sign in to nothing.
-- A vendor with no row here sees no tables. Admins edit this from the portal's
-- "Vendor access" panel; vendor_name is matched case-insensitively to profiles.vendor_name.
--
-- Run once in Supabase Dashboard -> SQL Editor, after 001_profiles.sql. Safe to re-run.

create table if not exists public.vendor_access (
  vendor_name text primary key check (vendor_name = lower(trim(vendor_name)) and vendor_name <> ''),
  tabs        text[] not null default '{}' check (tabs <@ array['cohort', 'geo', 'tds', 'rows']),
  updated_by  uuid default auth.uid() references auth.users (id) on delete set null,
  updated_at  timestamptz not null default now()
);

drop trigger if exists vendor_access_touch_updated_at on public.vendor_access;
create trigger vendor_access_touch_updated_at
  before update on public.vendor_access
  for each row execute function public.touch_updated_at();

-- security definer so the policy can read the caller's vendor without recursing into RLS
create or replace function public.current_user_vendor()
returns text
language sql stable security definer set search_path = public
as $$ select lower(trim(vendor_name)) from public.profiles where id = auth.uid() $$;

-- ---------- Row Level Security ----------
alter table public.vendor_access enable row level security;

drop policy if exists "vendor_access: staff read all" on public.vendor_access;
create policy "vendor_access: staff read all" on public.vendor_access
  for select using (public.current_user_role() in ('admin', 'team_management'));

drop policy if exists "vendor_access: vendor read own" on public.vendor_access;
create policy "vendor_access: vendor read own" on public.vendor_access
  for select using (vendor_name = public.current_user_vendor());

drop policy if exists "vendor_access: admin write" on public.vendor_access;
create policy "vendor_access: admin write" on public.vendor_access
  for all using (public.is_admin()) with check (public.is_admin());

-- Vontron keeps every table it has today
insert into public.vendor_access (vendor_name, tabs)
values ('vontron', array['cohort', 'geo', 'tds', 'rows'])
on conflict (vendor_name) do nothing;
