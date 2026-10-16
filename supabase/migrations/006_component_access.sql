-- Membrane Watch v3: Component Defect Analysis permission model.
-- Vendor x Component x Funnel. Fully separate from public.vendor_access
-- (which gates the Vontron tabs and the debit-note dashboards) and from
-- Part 1 (debit notes). Nothing here touches those.
--
-- Run once in Supabase SQL Editor, after 001_profiles.sql. Safe to re-run.

create table if not exists public.components (
  component_id   text primary key,
  component_name text not null,
  spare_skus     text[] not null default '{}',
  created_at     timestamptz not null default now()
);

create table if not exists public.v3_vendors (
  vendor_id   text primary key,
  vendor_name text not null,
  created_at  timestamptz not null default now()
);

create table if not exists public.vendor_component_access (
  vendor_id    text not null
    references public.v3_vendors (vendor_id) on delete cascade,
  component_id text not null
    references public.components (component_id) on delete cascade,
  granted_by   uuid
    references auth.users (id) on delete set null,
  granted_at   timestamptz not null default now(),
  active       boolean not null default true,
  primary key (vendor_id, component_id)
);

create table if not exists public.vendor_funnel_access (
  vendor_id    text not null
    references public.v3_vendors (vendor_id) on delete cascade,
  component_id text not null
    references public.components (component_id) on delete cascade,
  funnel_code  text not null
    check (funnel_code in (
      'F_PRESSURE', 'F_TDS_IN', 'F_TDS_OUT', 'F_TDS_IO', 'F_WATER'
    )),
  active       boolean not null default true,
  primary key (vendor_id, component_id, funnel_code)
);

create table if not exists public.component_audit_log (
  id           bigserial primary key,
  user_id      uuid
    references auth.users (id) on delete set null,
  action       text not null,
  vendor_id    text,
  component_id text,
  funnel_code  text,
  detail       jsonb,
  created_at   timestamptz not null default now()
);

-- ---------- Row Level Security ----------

alter table public.components
  enable row level security;
alter table public.v3_vendors
  enable row level security;
alter table public.vendor_component_access
  enable row level security;
alter table public.vendor_funnel_access
  enable row level security;
alter table public.component_audit_log
  enable row level security;

drop policy if exists "comp_read"
  on public.components;
create policy "comp_read"
  on public.components
  for select
  using (auth.uid() is not null);

drop policy if exists "v3v_read"
  on public.v3_vendors;
create policy "v3v_read"
  on public.v3_vendors
  for select
  using (auth.uid() is not null);

drop policy if exists "vca_staff_read"
  on public.vendor_component_access;
create policy "vca_staff_read"
  on public.vendor_component_access
  for select
  using (public.current_user_role() in ('admin', 'team_management'));

drop policy if exists "vca_vendor_read"
  on public.vendor_component_access;
create policy "vca_vendor_read"
  on public.vendor_component_access
  for select
  using (vendor_id = public.current_user_vendor());

drop policy if exists "vca_admin_write"
  on public.vendor_component_access;
create policy "vca_admin_write"
  on public.vendor_component_access
  for all
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "vfa_staff_read"
  on public.vendor_funnel_access;
create policy "vfa_staff_read"
  on public.vendor_funnel_access
  for select
  using (public.current_user_role() in ('admin', 'team_management'));

drop policy if exists "vfa_vendor_read"
  on public.vendor_funnel_access;
create policy "vfa_vendor_read"
  on public.vendor_funnel_access
  for select
  using (vendor_id = public.current_user_vendor());

drop policy if exists "vfa_admin_write"
  on public.vendor_funnel_access;
create policy "vfa_admin_write"
  on public.vendor_funnel_access
  for all
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "cal_admin_read"
  on public.component_audit_log;
create policy "cal_admin_read"
  on public.component_audit_log
  for select
  using (public.is_admin());

drop policy if exists "cal_admin_insert"
  on public.component_audit_log;
create policy "cal_admin_insert"
  on public.component_audit_log
  for insert
  with check (public.is_admin());

-- ---------- Seed: RO Membrane + Vontron + pilot access ----------

insert into public.components (component_id, component_name, spare_skus)
values (
  'ro_membrane',
  'RO Membrane',
  array[
    'NATIVE RO Membrane With FR 300',
    'NATIVE RO Membrane',
    'NATIVE RO Membrane With FR',
    'NATIVE M0 Concealed RO Membrane without Life Booster',
    'NATIVE M3 / M3 PRO Concealed Membrane Without Life Booster',
    'NATIVE Concealed RO Membrane with Life Booster'
  ]
)
on conflict (component_id) do nothing;

insert into public.v3_vendors (vendor_id, vendor_name)
values ('vontron', 'Vontron')
on conflict (vendor_id) do nothing;

insert into public.vendor_component_access (vendor_id, component_id)
values ('vontron', 'ro_membrane')
on conflict (vendor_id, component_id) do nothing;

insert into public.vendor_funnel_access
  (vendor_id, component_id, funnel_code)
values
  ('vontron', 'ro_membrane', 'F_TDS_IN'),
  ('vontron', 'ro_membrane', 'F_TDS_OUT'),
  ('vontron', 'ro_membrane', 'F_TDS_IO'),
  ('vontron', 'ro_membrane', 'F_WATER')
on conflict (vendor_id, component_id, funnel_code) do nothing;

-- Check the result
select
  vca.vendor_id,
  vca.component_id,
  array_agg(vfa.funnel_code) as funnels
from public.vendor_component_access vca
left join public.vendor_funnel_access vfa
  using (vendor_id, component_id)
group by 1, 2;
