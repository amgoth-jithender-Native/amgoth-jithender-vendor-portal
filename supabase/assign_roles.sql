-- Assign roles after the users exist (create them in Dashboard -> Authentication -> Users -> Add user).
-- Run in the SQL Editor; replace the emails with real ones.

update public.profiles set role = 'admin'
where email = 'amgothnaik@urbancompany.com';

update public.profiles set role = 'team_management', vendor_name = null
where email in ('teammate@urbancompany.com');

update public.profiles set role = 'vendor', vendor_name = 'Vontron'
where email in ('dheerajbathla@urbancompany.com');

-- Check the result
select email, role, vendor_name from public.profiles order by role, email;
