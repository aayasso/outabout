-- activity_day_outcomes — the readable half of the outcome loop.
--
-- Today an answer to "Did you go?" goes two places, neither of which the app
-- can read back:
--
--   1. behavioral_events, where RLS SELECT is false for every role. That is
--      deliberate and load bearing — those rows are the intelligence
--      platform's dataset, and 20260823000000 goes further and de-identifies
--      them rather than deleting them when an account goes away.
--   2. the outcome_prompt_handled SharedPreferences set, which records only
--      *that* a prompt was settled, never what the answer was, and prunes to a
--      two day window.
--
-- So OutAbout can ask the question and can report it upstream, but cannot show
-- the user a single thing about their own history.
--
-- Matched days are not persisted anywhere either: evaluateDayMatch recomputes
-- them from the live five day forecast, so a day ceases to exist the moment it
-- leaves the window. A streak needs the opposite — a durable record of every
-- day the app claimed conditions were right, including the days the user never
-- answered. Those unanswered days are the denominator; without them a
-- completion rate has nothing to divide by.
--
-- local_date is the *device's* local calendar date, stored as a bare `date`
-- with no timezone attached, and the client is its sole author. Deliberate:
-- "did you go today" is a question about the day the user lived in, and
-- Tomorrow.io hands the app UTC instants (a forecast day reads as
-- 2026-08-23T13:00:00Z). The device is the only place the user's real timezone
-- is known — user_locations does not store one, and the app only ever reports
-- an abbreviation like "PDT" — so normalisation happens there and Postgres
-- never re-interprets the value.
--
-- ON DELETE CASCADE on both foreign keys, the opposite of the decision taken
-- for behavioral_events in 20260823000000. Not an inconsistency:
--
--   * every row here already has a de-identified twin over there
--     (activity_confirmed / condition_match_ignored), so cascading destroys no
--     analytic value;
--   * this is the user's own history, shown back to them. It is user data, and
--     user data is hard deleted;
--   * the cascade also makes deletion *structural*. It holds even if some
--     future path deletes an auth user without going through the
--     delete-account edge function, which is the same argument 20260823000000
--     makes for its SET NULL.
--
-- The activity_id cascade is not merely tidy — it is required. delete-account
-- deletes the user's activities rows directly (step 9) before deleting the
-- auth user. With the default NO ACTION that DELETE would fail on a foreign
-- key violation and take in-app account deletion down with it, which is an App
-- Store 5.1.1(v) blocker.
--
-- RLS SELECT is true here, unlike behavioral_events. That is the entire point
-- of the table, and it is why user_id is NOT NULL: no de-identified row can
-- exist, so no permanently unreadable orphan can either.
--
-- Idempotent throughout. A unique *index* rather than a unique constraint
-- because ADD CONSTRAINT has no IF NOT EXISTS; PostgREST's on_conflict
-- resolves against a unique index just as well. Note that the CHECK
-- constraints ride inside CREATE TABLE IF NOT EXISTS, so a re-run against an
-- existing table skips them — the standard tradeoff for this idempotency
-- style, and the reason the table body must not be edited in place later.

create table if not exists public.activity_day_outcomes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null
                references auth.users(id) on delete cascade,
  activity_id uuid not null
                references public.activities(id) on delete cascade,
  local_date  date not null,
  matched     boolean not null default true,
  outcome     text,
  reason      text,
  answered_at timestamptz,
  created_at  timestamptz not null default now(),

  -- null means unanswered, which is a real state with real consequences: it
  -- stays answerable for a grace window and then counts against the user.
  constraint activity_day_outcomes_outcome_check
    check (outcome is null
           or outcome = any (array['done'::text, 'skipped'::text])),

  -- An answered row with no timestamp would make duplicate resolution
  -- ambiguous — the client breaks ties on answered_at. Revisit if a third,
  -- timestamped but outcomeless state is ever added.
  constraint activity_day_outcomes_answered_at_check
    check ((outcome is null) = (answered_at is null))
);

-- Both the upsert conflict target and the per-activity read path. The equality
-- prefix (user_id, activity_id) serves fetchForActivity, so no second index is
-- needed for it.
create unique index if not exists activity_day_outcomes_user_activity_day_key
  on public.activity_day_outcomes (user_id, activity_id, local_date);

alter table public.activity_day_outcomes enable row level security;

-- GRANT gates the table, RLS gates the rows, and both are required. A table
-- created by migration does not inherit the dashboard's default privileges, so
-- without this every policy below is unreachable and every request fails 42501
-- — which reads like an RLS misconfiguration and is easy to chase in the wrong
-- place.
grant select, insert, update, delete
  on public.activity_day_outcomes to authenticated;

drop policy if exists "Users read own day outcomes"
  on public.activity_day_outcomes;
create policy "Users read own day outcomes"
  on public.activity_day_outcomes for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users insert own day outcomes"
  on public.activity_day_outcomes;
create policy "Users insert own day outcomes"
  on public.activity_day_outcomes for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Both USING and WITH CHECK. Without WITH CHECK a user could update a row they
-- own and reassign user_id to someone else on the way out, writing history
-- into another account.
drop policy if exists "Users update own day outcomes"
  on public.activity_day_outcomes;
create policy "Users update own day outcomes"
  on public.activity_day_outcomes for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users delete own day outcomes"
  on public.activity_day_outcomes;
create policy "Users delete own day outcomes"
  on public.activity_day_outcomes for delete
  to authenticated
  using (auth.uid() = user_id);
