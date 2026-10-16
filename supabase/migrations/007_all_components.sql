-- Membrane Watch v3: seed all 23 provisional components, and grant
-- Vontron access to all of them temporarily (user-confirmed 2026-10-16,
-- interim until the real vendor->component mapping arrives).
--
-- Does NOT edit 006_component_access.sql (already run) -- only adds rows.
-- Run once in Supabase SQL Editor, after 006_component_access.sql.
-- Safe to re-run (idempotent).
--
-- Keep every line short: a prior migration got silently truncated during
-- copy-paste on long lines, so this one is deliberately kept narrow.

insert into public.components (component_id, component_name)
values
  ('back_panel', 'Back Panel'),
  ('battery', 'Battery'),
  ('bezel', 'Bezel Assembly'),
  ('booster_pump', 'Booster / Dispensing Pump'),
  ('carbon_filter', 'Carbon / Health Booster Filter'),
  ('connectors_fittings', 'Connectors / Valves / Fittings'),
  ('float_assembly', 'Float Switch / Assembly'),
  ('flow_restrictor', 'Flow Restrictor / Flow Sensor'),
  ('membrane_housing', 'RO Membrane Housing'),
  ('pcb', 'PCB'),
  (
    'pek_prv',
    'Pressure Enhancing/Reducing Kit (PEK/PRV)'
  ),
  ('pressure_switch', 'Pressure Switch (HPS/LPS)'),
  ('sediment_filter', 'Sediment / Pre Filter'),
  ('smps', 'SMPS / Adapter'),
  ('solenoid_valve', 'Solenoid Valve'),
  ('tank_accessories', 'Tank / Accessories'),
  ('tap_assembly', 'Tap / Faucet Assembly'),
  ('tds_sensor', 'TDS Sensor / Controller'),
  ('uf_filter', 'UF Filter'),
  ('ups', 'UPS'),
  ('uv_led', 'UV / LED'),
  ('wire_harness', 'Wire Harness')
on conflict (component_id) do nothing;
-- (ro_membrane already seeded by 006)

-- Grant Vontron every component (interim, see note above)
insert into public.vendor_component_access
  (vendor_id, component_id)
select 'vontron', component_id
from public.components
on conflict (vendor_id, component_id) do nothing;

-- Grant Vontron the same 4 funnels on every component
-- (F_PRESSURE excluded everywhere -- no usable pressure data)
insert into public.vendor_funnel_access
  (vendor_id, component_id, funnel_code)
select 'vontron', c.component_id, f.funnel_code
from public.components c
cross join (
  values
    ('F_TDS_IN'),
    ('F_TDS_OUT'),
    ('F_TDS_IO'),
    ('F_WATER')
) as f(funnel_code)
on conflict (vendor_id, component_id, funnel_code)
  do nothing;

-- Check the result
select count(*) as vontron_components
from public.vendor_component_access
where vendor_id = 'vontron' and active = true;
