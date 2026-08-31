-- Close four public tables that anyone holding the anon key could read and
-- write.
--
-- The anon key ships inside the app binary, so "anon has SELECT and INSERT"
-- means the open internet has SELECT and INSERT. Verified before this
-- migration: all four had rowsecurity = false, zero policies, and both
-- privileges granted to anon.
--
--   data_intelligence_vectors  24 rows  — the vector store
--   external_data_events        0 rows
--   food_access_scores          0 rows
--   intelligence_queries        0 rows  — the query log
--
-- Safe to close completely: grep over lib/ and both edge functions finds zero
-- references to any of them. Nothing in the app reads or writes these; they
-- belong to the intelligence platform, which connects as service_role.
--
-- No policies are created, and that is the intended end state rather than an
-- omission. service_role bypasses RLS entirely, so the backend keeps full
-- access while every client role has none. Adding a permissive policy here
-- would only re-open what this closes.
--
-- Grants are revoked as well as RLS enabled, because they are independent
-- gates: RLS filters rows for roles that already hold the privilege, and a
-- future ALTER DEFAULT PRIVILEGES or a policy added in haste should not be
-- able to hand access back on its own.
--
-- spatial_ref_sys is deliberately untouched. It also has RLS off, but it is
-- PostGIS's own reference table of coordinate systems, contains no user data,
-- and enabling RLS on it breaks PostGIS operations.

do $$
declare
  t text;
begin
  foreach t in array array[
    'data_intelligence_vectors',
    'external_data_events',
    'food_access_scores',
    'intelligence_queries'
  ]
  loop
    if to_regclass(format('public.%I', t)) is null then
      raise notice 'skipping %: not present', t;
      continue;
    end if;

    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke all on public.%I from authenticated', t);

    raise notice 'locked down %', t;
  end loop;
end $$;
