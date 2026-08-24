-- activity_day_outcomes.conditions — the weather a recorded day actually had.
--
-- The ledger records that a day matched and what the user answered, but not
-- what the conditions were. That is enough for a streak and useless for
-- learning: "you skip your windy matches" needs the wind speed of each skipped
-- day, and there is nowhere to get it.
--
-- Not from behavioral_events. Its conditions_at_event jsonb holds exactly this
-- data, but RLS SELECT is false there for every role — deliberately, see
-- 20260823000000 — so no client can read it. Nor can the server for long:
-- deidentify_behavioral_events() nulls user_id *and* activity_id, so the join
-- key back to an activity is destroyed the moment an account goes away. A
-- table whose rows are designed to become unattributable cannot be the source
-- of truth for a per-activity inference.
--
-- So the snapshot lives here, next to the outcome it explains, under the same
-- RLS that already lets the user read their own history back.
--
-- Shape: exactly what DailyForecast.toJson() writes —
--   {"time": "...", "values": {"temperatureMax": .., "temperatureMin": ..,
--    "precipitationProbability": .., "windSpeedMaxKmh": .., "weatherCode": ..}}
-- which is the same shape DailyForecast.fromJson already reads back out of the
-- local forecast cache. Storing anything else would mean a second parser for
-- the same five numbers. Wind is km/h, matching the model's own contract and
-- condition_profiles.wind_max; temperatures are Celsius, as everywhere the
-- client stores them.
--
-- jsonb rather than five typed columns. The rule math reads whatever
-- evaluateDayMatch reads, and that set has already changed once (uv_* exist in
-- condition_profiles and are matched by nobody). A jsonb column absorbs the
-- next field without a migration, and nothing here is ever filtered or indexed
-- on server-side — the client fetches an activity's rows and derives in Dart.
--
-- NULL is a real and permanent state, not a gap to be filled:
--
--   * every row written before this migration has no weather record anywhere
--     readable, so there is no backfill and there cannot be one. Those rows
--     stay null forever;
--   * the suggestion engine requires a snapshot per day it counts, so null
--     rows are skipped entirely rather than defaulted. A default would be an
--     invented observation, which is precisely the failure mode a feature that
--     edits the user's settings must not have;
--   * this costs nothing in practice: the cold-start floor already demands
--     several newly decided days before anything is suggested.
--
-- Deliberately a separate migration rather than an edit to
-- 20260825000000. That file's CREATE TABLE IF NOT EXISTS makes an in-place
-- edit a no-op against any database that already has the table — it says so
-- itself — so every later column arrives as its own ALTER.
--
-- ActivityDayOutcome.toJson omits this key when null, which is load bearing on
-- the write side. answer() upserts without ignoreDuplicates, and PostgREST
-- only SETs the columns present in the payload; a payload carrying
-- 'conditions': null would blank the snapshot every time the user answered the
-- day it belongs to. Same reasoning as the outcome/reason/answered_at
-- omissions already documented on that model.

alter table public.activity_day_outcomes
  add column if not exists conditions jsonb;

comment on column public.activity_day_outcomes.conditions is
  'The day''s forecast as DailyForecast.toJson(): '
  '{"time":..., "values":{"temperatureMax","temperatureMin",'
  '"precipitationProbability","windSpeedMaxKmh","weatherCode"}}. '
  'Celsius and km/h. Null on rows written before the column existed and on '
  'any row recorded without a forecast in hand; never backfilled.';
