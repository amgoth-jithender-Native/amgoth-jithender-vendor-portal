-- Membrane Watch: Amber (Keshav) dashboard tables in vendor_access
-- Amber uses the same debit-note tables as Ronch (r_summary, r_components, r_cohort, r_sku, r_rows),
-- already allowed by 004_ronch_tabs.sql.
--
-- Run once in Supabase Dashboard -> SQL Editor, after 004_ronch_tabs.sql. Safe to re-run.

-- Amber's login (vendor_name 'Keshav' for now, or 'Amber') starts with every debit-note table
insert into public.vendor_access (vendor_name, tabs)
values ('keshav', array['r_summary', 'r_components', 'r_cohort', 'r_sku', 'r_rows']),
       ('amber',  array['r_summary', 'r_components', 'r_cohort', 'r_sku', 'r_rows'])
on conflict (vendor_name) do nothing;
