-- The cadence ceiling, and the three things the database was missing before it
-- could hold one.
--
-- Before this migration check-weather had no memory. It looped every user by
-- every activity and pushed on every match, every run, with nothing recording
-- what the previous run had already said. The cadence a user actually
-- experienced was (matching activities x cron frequency) — unbounded, and
-- worst on exactly the beautiful Saturday when the app most wanted to be
-- trusted. Nothing errored, so nothing surfaced.
--
-- Three parts, in dependency order:
--   1. user_locations.timezone   — so "07:00" can mean the user's 07:00
--   2. notification_sends        — the operational ledger the cap reads
--   3. notification_preferences  — column defaults that match the runtime ones
--
-- Idempotent throughout: safe to run more than once.


-- ---------------------------------------------------------------------------
-- 1. user_locations.timezone
-- ---------------------------------------------------------------------------
--
-- The server could not schedule anything in local time because it did not know
-- the user's zone. user_locations carries (id, user_id, city, latitude,
-- longitude, updated_at) and nothing else, so check-weather's only options
-- were UTC — which puts a 07:00 nudge at 02:00 for every user in the Americas
-- — or a guess from longitude, which is blind to both political boundaries and
-- DST.
--
-- The app has known the answer the whole time: BehavioralEventService already
-- resolves the device's IANA identifier via flutter_timezone and writes it
-- into geographic_context.timezone on every client-side event. It simply never
-- reached a table the server reads. LocationService now writes it here too.
--
-- Nullable on purpose. Rows written before this column existed keep a NULL,
-- and resolveZone() in scheduling.ts falls back to the longitude estimate for
-- them rather than refusing to notify — a coarse zone is a scheduling
-- inaccuracy, an absent one would be silence.
alter table public.user_locations
  add column if not exists timezone text;

comment on column public.user_locations.timezone is
  'IANA identifier (e.g. America/New_York) from the device, written by '
  'LocationService. NULL for rows predating the column; check-weather then '
  'estimates the zone from longitude.';


-- ---------------------------------------------------------------------------
-- 2. notification_sends
-- ---------------------------------------------------------------------------
--
-- The ledger the cap reads: one row per push actually handed to OneSignal.
--
-- A separate table rather than a query over behavioral_events, for three
-- reasons, in ascending order of how much they matter:
--
--   a. Cost. behavioral_events is the intelligence platform's dataset and is
--      designed to grow without bound. The cap needs "what did this user get
--      in the last 24 hours", which is a small, hot, prunable question, and
--      asking it of an ever-growing analytics table means a jsonb expression
--      index and a scan that gets slower every week the app succeeds.
--
--   b. Shape. The dedupe key is (activity, forecast day), and the forecast day
--      lives inside conditions_at_event's jsonb rather than in a column.
--
--   c. Correctness, which is the real reason. BehavioralEventService.log and
--      its server twin both swallow their errors by design — a logging failure
--      must never cost a user their notification. That is right, and it makes
--      behavioral_events unusable as an operational record: a dropped insert
--      would erase the memory of a push that really was delivered, and the
--      next cron run would send it again. Operational state and the analytics
--      stream want opposite failure modes, so they get separate tables.
--
-- behavioral_events still receives condition_match_notified exactly as before.
-- This table does not replace it; the two answer different questions.
create table if not exists public.notification_sends (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  activity_id uuid not null references public.activities (id) on delete cascade,

  -- The day the conditions are good, in the user's local calendar. A bare
  -- `date`, matching activity_day_outcomes.local_date and for the same reason:
  -- "Saturday" is a wall-clock fact about where the user is, not an instant.
  forecast_date date not null,

  -- 'morning_of' | 'night_before' | 'days_before'. Text rather than an enum so
  -- a new nudge kind is a code change, not a migration with a lock on it.
  nudge_kind text not null,

  -- OneSignal's id, when it gave one. Null when the send failed after the
  -- ledger row was written, which is deliberate: a push we are unsure about is
  -- recorded as sent. Over-counting costs the user a nudge they might have
  -- liked; under-counting costs them a duplicate, and duplicates are what this
  -- whole migration exists to stop.
  onesignal_id text,

  sent_at timestamptz not null default now()
);

-- The dedupe key: never twice about the same day for the same activity. A
-- unique index rather than application logic, so two overlapping cron runs
-- cannot both pass the check and both send.
create unique index if not exists notification_sends_activity_day_key
  on public.notification_sends (activity_id, forecast_date);

-- The cap query: "how many has this user had since <local midnight>".
create index if not exists notification_sends_user_sent_at_idx
  on public.notification_sends (user_id, sent_at desc);

alter table public.notification_sends enable row level security;

-- Readable by its owner so the app can show "we told you about this" without
-- a round trip through the edge function. Writable only by the service role,
-- which is the only thing that can send a push in the first place — a client
-- that could insert here could silence its own notifications, and a client
-- that could delete could make the app spam its user.
drop policy if exists "notification_sends readable by owner"
  on public.notification_sends;
create policy "notification_sends readable by owner"
  on public.notification_sends for select
  using (auth.uid() = user_id);

comment on table public.notification_sends is
  'Operational ledger of pushes actually sent. Enforces the per-activity-per-'
  'day dedupe and the per-user daily cap in scheduling.ts. Distinct from '
  'behavioral_events, whose inserts are allowed to fail silently.';


-- ---------------------------------------------------------------------------
-- 3. notification_preferences defaults
-- ---------------------------------------------------------------------------
--
-- Every notify_* column defaulted to false, which meant a row created by the
-- app switched the activity off. Combined with a scheduler that read those
-- defaults as intent, the result would have been an app that asks for
-- notification permission during onboarding and then never sends one — the
-- same silence as the embed bug, arrived at from the opposite direction.
--
-- morning_of becomes the default because it is the promise the onboarding
-- screen makes: conditions are right today, here is your nudge. The other two
-- stay off; they are refinements a user opts into, and defaulting them on
-- would spend the daily cap before the user has asked for anything.
--
-- Only the DEFAULT changes. Existing rows are left exactly as they are: a row
-- already in this table was written by a user or by the app on their behalf,
-- and rewriting it here would override a preference somebody set.
alter table public.notification_preferences
  alter column notify_morning_of set default true;

comment on column public.notification_preferences.notify_morning_of is
  'Defaults true — the nudge onboarding promises. An activity with no row at '
  'all is treated the same way by effectiveNotifyPrefs(); a row with every '
  'flag false is a deliberate opt-out and is obeyed.';
