-- Membrane Watch: user profiles with three roles
--   admin            full access, manages users and roles
--   team_management  internal Native/UC team, sees every vendor's data
--   vendor           sees only their own vendor's data (profiles.vendor_name)
--
-- Run once in Supabase Dashboard -> SQL Editor. Safe to re-run.

-- ---------- Role type ----------
do $$ begin
  create type public.user_role as enum ('admin', 'team_management', 'vendor');
exception when duplicate_object then null;
end $$;

-- ---------- Profiles ----------
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null,
  full_name   text,
  role        public.user_role not null default 'vendor',
  vendor_name text,  -- e.g. 'Vontron'; a vendor with no vendor_name sees no data
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists profiles_vendor_name_idx on public.profiles (vendor_name);

-- ---------- Role helpers ----------
-- security definer so policies can read the caller's role without recursing into RLS
create or replace function public.current_user_role()
returns public.user_role
language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path = public
as $$ select coalesce(public.current_user_role() = 'admin', false) $$;

-- ---------- New user -> profile ----------
-- Every new auth user starts as a vendor with no vendor_name (no data access)
-- until an admin assigns a role. The role is never taken from signup metadata,
-- so nobody can sign themselves up as admin.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for users created before this migration
insert into public.profiles (id, email, full_name)
select id, email, raw_user_meta_data ->> 'full_name' from auth.users
on conflict (id) do nothing;

-- ---------- Keep updated_at fresh ----------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------- Block self-promotion ----------
-- Only admins may change role or vendor_name, even on their own row.
-- auth.uid() is null for SQL Editor / service-role sessions, which are allowed.
create or replace function public.guard_role_change()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if (new.role is distinct from old.role or new.vendor_name is distinct from old.vendor_name)
     and auth.uid() is not null and not public.is_admin() then
    raise exception 'Only an admin can change role or vendor_name';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_role_change on public.profiles;
create trigger profiles_guard_role_change
  before update on public.profiles
  for each row execute function public.guard_role_change();

-- ---------- Row Level Security ----------
alter table public.profiles enable row level security;

drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
  for select using (id = auth.uid());

drop policy if exists "profiles: staff read all" on public.profiles;
create policy "profiles: staff read all" on public.profiles
  for select using (public.current_user_role() in ('admin', 'team_management'));

drop policy if exists "profiles: update own name" on public.profiles;
create policy "profiles: update own name" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "profiles: admin write" on public.profiles;
create policy "profiles: admin write" on public.profiles
  for all using (public.is_admin()) with check (public.is_admin());
