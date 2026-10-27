-- Membrane Watch v3: let admins add component vendors from
-- the portal's Vendor access panel. Saving components for a
-- newly linked vendor first inserts it into v3_vendors,
-- which until now only had a read policy.
--
-- Run once in Supabase SQL Editor, after 008_vendor_components.sql.
-- Safe to re-run (idempotent).
--
-- Keep every line short: a prior migration got silently
-- truncated during copy-paste on long lines.

drop policy if exists "v3v_admin_write"
  on public.v3_vendors;
create policy "v3v_admin_write"
  on public.v3_vendors
  for all
  using (public.is_admin())
  with check (public.is_admin());

-- Check the result
select policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename = 'v3_vendors';
