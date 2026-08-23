-- Precipitation becomes bidirectional: 'avoid_rain' | 'rain_only'.
--
-- The old vocabulary was inconsistent end to end. Both pickers wrote
-- 'none' | 'light' | 'any' while both matchers only recognised
-- 'none' | 'light_ok', so 'light' and 'any' applied no filtering at all and
-- 'light_ok' was unreachable from the UI. Expect zero 'light_ok' rows; it is
-- handled here only because nothing guarantees that.
--
-- Mapping:
--   none, light, light_ok  -> avoid_rain   (all avoid-leaning)
--   any                    -> precip disabled: 'any' meant "don't care", which
--                             the new model expresses with precip_enabled=false
--   null while enabled     -> avoid_rain   (the old default)

-- Drop any existing CHECK on precip_level by introspection. condition_profiles
-- was created out of band and its DDL is not tracked in this repo, so the
-- constraint's name — or whether one exists at all — is unknown here. Dropping
-- by name would silently no-op and let the UPDATEs below fail against a stale
-- constraint.
do $$
declare
  c record;
begin
  for c in
    select con.conname
      from pg_constraint con
      join pg_class rel on rel.oid = con.conrelid
      join pg_namespace ns on ns.oid = rel.relnamespace
     where ns.nspname = 'public'
       and rel.relname = 'condition_profiles'
       and con.contype = 'c'
       and pg_get_constraintdef(con.oid) ilike '%precip_level%'
  loop
    execute format(
      'alter table public.condition_profiles drop constraint %I', c.conname);
  end loop;
end $$;

-- Order matters: each statement sees the previous one's result.
update public.condition_profiles
   set precip_enabled = false,
       precip_level = null
 where precip_level = 'any';

update public.condition_profiles
   set precip_level = 'avoid_rain'
 where precip_level in ('none', 'light', 'light_ok');

update public.condition_profiles
   set precip_level = 'avoid_rain'
 where precip_enabled = true
   and precip_level is null;

alter table public.condition_profiles
  add constraint condition_profiles_precip_level_check
  check (precip_level is null or precip_level in ('avoid_rain', 'rain_only'));
