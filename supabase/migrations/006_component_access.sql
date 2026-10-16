-- Membrane Watch v3: Component Defect Analysis permission model
--   Vendor x Component x Funnel, fully separate from public.vendor_access (which gates
--   the original Vontron Cohort/Geo/TDS/Rows tabs in index.html) and from Part 1's
--   debit-note gating (debit-note-ronch.html / debit-note-amber.html / ronch-data.js /
--   amber-data.js). None of those are touched by this migration or by component-analysis.html.
--
-- Run once in Supabase Dashboard -> SQL Editor, after 001_profiles.sql. Safe to re-run.

create table if not exists public.components (
  component_id   text primary key,              -- e.g. 'ro_membrane'
  component_name text not null,                  -- e.g. 'RO Membrane'
  spare_skus     text[] not null default '{}',   -- raw INVOICED_SKU_ARRAY item names mapped to this component
  created_at     timestamptz not null default now()
);

create table if not exists public.v3_vendors (
  vendor_id   text primary key,                  -- lowercase, matches profiles.vendor_name case-insensitively
  vendor_name text not null,                      -- display name, e.g. 'Vontron'
  created_at  timestamptz not null default now()
);

create table if not exists public.vendor_component_access (
  vendor_id    text not null references public.v3_vendors (vendor_id) on delete cascade,
  component_id text not null references public.components (component_id) on delete cascade,
  granted_by   uuid references auth.users (id) on delete set null,
  granted_at   timestamptz not null default now(),
  active       boolean not null default true,
  primary key (vendor_id, component_id)
);

create table if not exists public.vendor_funnel_access (
  vendor_id    text not null references public.v3_vendors (vendor_id) on delete cascade,
  component_id text not null references public.components (component_id) on delete cascade,
  funnel_code  text not null check (funnel_code in ('F_PRESSURE','F_TDS_IN','F_TDS_OUT','F_TDS_IO','F_WATER')),
  active       boolean not null default true,
  primary key (vendor_id, component_id, funnel_code)
);

create table if not exists public.component_audit_log (
  id           bigserial primary key,
  user_id      uuid references auth.users (id) on delete set null,
  action       text not null,                     -- e.g. 'grant_component', 'revoke_funnel'
  vendor_id    text,
  component_id text,
  funnel_code  text,
  detail       jsonb,
  created_at   timestamptz not null default now()
);

-- ---------- Row Level Security ----------
alter table public.components enable row level security;
alter table public.v3_vendors enable row level security;
alter table public.vendor_component_access enable row level security;
alter table public.vendor_funnel_access enable row level security;
alter table public.component_audit_log enable row level security;

-- Components/vendors: any authenticated user may read the catalog (names only, not data)
drop policy if exists "components: authenticated read" on public.components;
create policy "components: authenticated read" on public.components
  for select using (auth.uid() is not null);

drop policy if exists "v3_vendors: authenticated read" on public.v3_vendors;
create policy "v3_vendors: authenticated read" on public.v3_vendors
  for select using (auth.uid() is not null);

-- Access grants: admin/team_management see everything; a vendor sees only their own row
drop policy if exists "vendor_component_access: staff read all" on public.vendor_component_access;
create policy "vendor_component_access: staff read all" on public.vendor_component_access
  for select using (public.current_user_role() in ('admin', 'team_management'));

drop policy if exists "vendor_component_access: vendor read own" on public.vendor_component_access;
create policy "vendor_component_access: vendor read own" on public.vendor_component_access
  for select using (vendor_id = public.current_user_vendor());

drop policy if exists "vendor_component_access: admin write" on public.vendor_component_access;
create policy "vendor_component_access: admin write" on public.vendor_component_access
  for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists "vendor_funnel_access: staff read all" on public.vendor_funnel_access;
create policy "vendor_funnel_access: staff read all" on public.vendor_funnel_access
  for select using (public.current_user_role() in ('admin', 'team_management'));

drop policy if exists "vendor_funnel_access: vendor read own" on public.vendor_funnel_access;
create policy "vendor_funnel_access: vendor read own" on public.vendor_funnel_access
  for select using (vendor_id = public.current_user_vendor());

drop policy if exists "vendor_funnel_access: admin write" on public.vendor_funnel_access;
create policy "vendor_funnel_access: admin write" on public.vendor_funnel_access
  for all using (public.is_admin()) with check (public.is_admin());

-- Audit log: admin-only read, any authenticated write (the app inserts on every grant/revoke)
drop policy if exists "component_audit_log: admin read" on public.component_audit_log;
create policy "component_audit_log: admin read" on public.component_audit_log
  for select using (public.is_admin());

drop policy if exists "component_audit_log: admin insert" on public.component_audit_log;
create policy "component_audit_log: admin insert" on public.component_audit_log
  for insert with check (public.is_admin());

-- ---------- Seed: RO Membrane component + Vontron vendor + pilot access ----------
insert into public.components (component_id, component_name, spare_skus) values
  ('ro_membrane', 'RO Membrane', array[
    'NATIVE RO Membrane With FR 300','NATIVE RO Membrane','NATIVE RO Membrane With FR',
    'NATIVE M0 Concealed RO Membrane without Life Booster',
    'NATIVE M3 / M3 PRO Concealed Membrane Without Life Booster',
    'NATIVE Concealed RO Membrane with Life Booster'
  ])
on conflict (component_id) do nothing;

insert into public.v3_vendors (vendor_id, vendor_name) values ('vontron', 'Vontron')
on conflict (vendor_id) do nothing;

insert into public.vendor_component_access (vendor_id, component_id) values ('vontron', 'ro_membrane')
on conflict (vendor_id, component_id) do nothing;

insert into public.vendor_funnel_access (vendor_id, component_id, funnel_code) values
  ('vontron', 'ro_membrane', 'F_TDS_IN'),
  ('vontron', 'ro_membrane', 'F_TDS_OUT'),
  ('vontron', 'ro_membrane', 'F_TDS_IO'),
  ('vontron', 'ro_membrane', 'F_WATER')
on conflict (vendor_id, component_id, funnel_code) do nothing;

-- Check the result
select vca.vendor_id, vca.component_id, array_agg(vfa.funnel_code) as funnels
from public.vendor_component_access vca
left join public.vendor_funnel_access vfa using (vendor_id, component_id)
group by 1, 2;
