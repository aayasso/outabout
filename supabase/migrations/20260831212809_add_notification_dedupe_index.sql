-- Supports the notification suppression lookup in check-weather.
--
-- The function asks, once per user per run, "which of this user's activities
-- were notified in the last 36 hours". Without an index that is a sequential
-- scan of behavioral_events, the table every event in the app writes to.
--
-- Partial on event_type, because condition_match_notified is a rounding error
-- in that table. Indexing only the rows the query can match keeps this small
-- no matter how much the rest of the log grows.
--
-- Column order matches the query's shape: equality on user_id, then
-- activity_id read out of the result, then a range scan on created_at.

create index if not exists behavioral_events_match_notified_idx
  on public.behavioral_events (user_id, activity_id, created_at desc)
  where event_type = 'condition_match_notified';
