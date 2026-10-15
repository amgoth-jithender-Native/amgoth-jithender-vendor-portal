-- Membrane Watch: Ronch dashboard tables in vendor_access
--   r_summary (Debit Note), r_components (Components), r_cohort (Production Cohort),
--   r_sku (By Model), r_rows (Revisit Detail)
--
-- Run once in Supabase Dashboard -> SQL Editor, after 003_vendor_access.sql. Safe to re-run.

alter table public.vendor_access drop constraint if exists vendor_access_tabs_check;
alter table public.vendor_access add constraint vendor_access_tabs_check check (tabs <@ array[
  'cohort', 'geo', 'tds', 'rows',
  'r_summary', 'r_components', 'r_cohort', 'r_sku', 'r_rows'
]);

-- Ronch's login (vendor_name 'Ronch', or 'Siddharth' for now) starts with every Ronch table
insert into public.vendor_access (vendor_name, tabs)
values ('ronch',     array['r_summary', 'r_components', 'r_cohort', 'r_sku', 'r_rows']),
       ('siddharth', array['r_summary', 'r_components', 'r_cohort', 'r_sku', 'r_rows'])
on conflict (vendor_name) do nothing;
