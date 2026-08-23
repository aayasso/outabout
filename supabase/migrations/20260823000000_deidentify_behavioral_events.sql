-- behavioral_events survives account deletion, de-identified.
--
-- These rows are the intelligence platform's dataset. Destroying them on
-- deletion shrinks the asset every time a user leaves, which is the opposite
-- of what monetization_events already does (see delete-account/index.ts).
-- The rows carry no value that depends on knowing *who* acted, only on what
-- the weather was and what happened next.
--
-- Three changes, all idempotent:
--   1. user_id becomes nullable, so a row can exist unattributed.
--   2. The FK to auth.users switches CASCADE -> SET NULL. This is the load
--      bearing change: the constraint was ON DELETE CASCADE, so deleting the
--      auth user destroyed every row regardless of what the edge function did
--      first. With SET NULL, de-identification is structural — it holds even
--      if some future code path deletes a user without going through
--      delete-account at all.
--   3. deidentify_behavioral_events() strips the re-identifying payload.
--
-- RLS needs no change: SELECT is already `false` for every role and the two
-- INSERT policies check `auth.uid() = user_id`, so a null-user_id row is
-- unreadable and unwritable by any client. service_role bypasses RLS.

alter table public.behavioral_events
  alter column user_id drop not null;

alter table public.behavioral_events
  drop constraint if exists behavioral_events_user_id_fkey;

alter table public.behavioral_events
  add constraint behavioral_events_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;

-- Strips every column and jsonb key that could re-identify the user.
--
-- Written as an RPC rather than a client-side .update() because the Supabase
-- JS client sends literal values — it cannot express the jsonb `-` operator.
-- One statement instead of fetch-transform-write over N rows, and atomic.
--
-- Key treatment:
--   user_id, activity_id        -> null (direct links)
--   session_context             -> drop activity_name, category (both free
--                                  text the user typed), activity_id,
--                                  category_id, notification_id.
--                                  Keeps platform, app_version, active_theme,
--                                  setting, new_value, theme, step,
--                                  permission_granted — all bounded vocab.
--   geographic_context          -> null the lat/lng buckets. At ~1 mile they
--                                  are effectively a home address once joined
--                                  to created_at. city/state/metro/country/
--                                  timezone stay: metro-level geo is the
--                                  analytic value and does not single anyone
--                                  out.
--   conditions_at_event,
--   temporal_context, created_at -> untouched, no personal linkage.
create or replace function public.deidentify_behavioral_events(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected integer;
begin
  update public.behavioral_events
     set user_id = null,
         activity_id = null,
         session_context = session_context
           - 'activity_name' - 'activity_id'
           - 'category'      - 'category_id'
           - 'notification_id',
         geographic_context = case
           when geographic_context ? 'lat_bucketed'
             or geographic_context ? 'lng_bucketed'
           then jsonb_set(
                  jsonb_set(geographic_context,
                            '{lat_bucketed}', 'null'::jsonb, false),
                            '{lng_bucketed}', 'null'::jsonb, false)
           else geographic_context
         end
   where user_id = p_user_id;

  get diagnostics affected = row_count;
  return affected;
end;
$$;

-- Only service_role may call this. Without the revoke, any authenticated user
-- could de-identify another user's rows by passing their id — the function is
-- security definer precisely so it can bypass the write-only RLS policies.
revoke all on function public.deidentify_behavioral_events(uuid)
  from public, anon, authenticated;
