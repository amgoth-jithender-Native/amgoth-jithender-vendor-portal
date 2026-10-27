-- Membrane Watch v3: real vendor -> component mapping for
-- Lexcru, IOTFY and Gadson (user-supplied 2026-10-27).
-- Each vendor sees ONLY the components listed below; any
-- other grant they hold is switched off (active = false).
--
-- Vontron is untouched (still the interim all-23 grant
-- from 007_all_components.sql).
--
-- Run once in Supabase SQL Editor, after 007_all_components.sql.
-- Safe to re-run (idempotent).
--
-- Keep every line short: a prior migration got silently
-- truncated during copy-paste on long lines.

-- 1. The vendors (vendor_id = profiles.vendor_name, lower-case)
insert into public.v3_vendors (vendor_id, vendor_name)
values
  ('lexcru', 'Lexcru'),
  ('iotfy', 'IOTFY'),
  ('gadson', 'Gadson')
on conflict (vendor_id) do nothing;

-- 2. The mapping
drop table if exists vc_map;
create temp table vc_map (
  vendor_id    text,
  component_id text
);

insert into vc_map (vendor_id, component_id)
values
  ('lexcru', 'sediment_filter'),
  ('lexcru', 'carbon_filter'),
  ('lexcru', 'uf_filter'),
  ('lexcru', 'ro_membrane'),
  ('lexcru', 'booster_pump'),
  ('lexcru', 'pek_prv'),
  ('lexcru', 'flow_restrictor'),
  ('lexcru', 'pressure_switch'),
  ('lexcru', 'connectors_fittings'),
  ('iotfy', 'pcb'),
  ('iotfy', 'battery'),
  ('iotfy', 'tds_sensor'),
  ('iotfy', 'flow_restrictor'),
  ('gadson', 'float_assembly'),
  ('gadson', 'solenoid_valve'),
  ('gadson', 'pressure_switch');

-- 3. Grant the mapped components (re-activate if revoked)
insert into public.vendor_component_access
  (vendor_id, component_id)
select vendor_id, component_id
from vc_map
on conflict (vendor_id, component_id)
  do update set active = true;

-- 4. Revoke anything else these vendors hold
update public.vendor_component_access a
set active = false
where a.vendor_id in ('lexcru', 'iotfy', 'gadson')
  and not exists (
    select 1 from vc_map m
    where m.vendor_id = a.vendor_id
      and m.component_id = a.component_id
  );

-- 5. Same 4 funnels as Vontron on each mapped component
-- (F_PRESSURE excluded everywhere -- no usable pressure data)
insert into public.vendor_funnel_access
  (vendor_id, component_id, funnel_code)
select m.vendor_id, m.component_id, f.funnel_code
from vc_map m
cross join (
  values
    ('F_TDS_IN'),
    ('F_TDS_OUT'),
    ('F_TDS_IO'),
    ('F_WATER')
) as f(funnel_code)
on conflict (vendor_id, component_id, funnel_code)
  do update set active = true;

update public.vendor_funnel_access a
set active = false
where a.vendor_id in ('lexcru', 'iotfy', 'gadson')
  and not exists (
    select 1 from vc_map m
    where m.vendor_id = a.vendor_id
      and m.component_id = a.component_id
  );

-- 6. Let them open the 4 dashboard tabs (003_vendor_access)
insert into public.vendor_access (vendor_name, tabs)
values
  ('lexcru', array['cohort', 'geo', 'tds', 'rows']),
  ('iotfy', array['cohort', 'geo', 'tds', 'rows']),
  ('gadson', array['cohort', 'geo', 'tds', 'rows'])
on conflict (vendor_name) do nothing;

-- Check the result
select vendor_id, array_agg(component_id order by component_id)
  as components
from public.vendor_component_access
where vendor_id in ('lexcru', 'iotfy', 'gadson')
  and active = true
group by vendor_id;
