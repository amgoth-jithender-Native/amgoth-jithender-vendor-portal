-- Membrane Watch v3: input pressure (F_PRESSURE) now has data
-- (photo-read PSI from the installation pressure audit, pulled
-- 2026-10-27), so grant it wherever a vendor already has a
-- component. 006-008 deliberately left it out.
--
-- New grants made from the portal's Vendor access panel
-- include F_PRESSURE automatically.
--
-- Run once in Supabase SQL Editor, after 009_admin_vendors.sql.
-- Safe to re-run (idempotent).
--
-- Keep every line short: a prior migration got silently
-- truncated during copy-paste on long lines.

insert into public.vendor_funnel_access
  (vendor_id, component_id, funnel_code)
select vendor_id, component_id, 'F_PRESSURE'
from public.vendor_component_access
where active = true
on conflict (vendor_id, component_id, funnel_code)
  do update set active = true;

-- Check the result
select vendor_id, count(*) as components_with_pressure
from public.vendor_funnel_access
where funnel_code = 'F_PRESSURE' and active = true
group by vendor_id
order by vendor_id;
