-- Add the three event types for adaptive condition suggestions:
--   condition_suggestion_shown
--   condition_suggestion_accepted
--   condition_suggestion_declined
--
-- Three types rather than one carrying an outcome, which is the opposite of
-- the call 20260825000100 made for milestones. The reason is the denominator.
-- Shown/accepted/declined is a funnel, and a funnel is queried by counting
-- rows per stage; folding the stage into session_context would put it inside
-- the jsonb the de-identification function rewrites and make the most
-- important dimension of this dataset the hardest one to group by. Milestones
-- had no funnel — one event, one payload value.
--
-- What these rows are worth: a suggestion is the only place OutAbout puts a
-- *stated* preference and a *revealed* one side by side. The user typed
-- wind_max = 25 and then skipped every match above 18. session_context carries
-- both numbers plus the evidence behind the claim:
--
--   {"activity_id": ..., "dimension": "wind_max", "current_value": 25,
--    "suggested_value": 20, "qualifying_skips": 3, "eligible_days": 9}
--
-- An accept says the inference was right. A decline says the stated threshold
-- was right and the behaviour has another explanation — which is the more
-- interesting row of the two, and the one a naive analysis would never collect
-- because nothing else in the app records a rejected hypothesis.
--
-- Survives deidentify_behavioral_events as intended: activity_id is on that
-- function's key-drop list, and everything else is either bounded vocabulary
-- (dimension is one of three literals) or a bare number. The same property
-- 20260825000100 relied on.
--
-- Without this the CHECK rejects the insert (23514) and the event is dropped
-- silently — BehavioralEventService.log swallows its errors by design, so
-- nothing surfaces. Apply before shipping a build that logs it.
--
-- The two types deliberately retained but no longer emitted by the client are
-- still listed, for the reasons set out in 20260824000000.
--
-- Drops and recreates the CHECK constraint with all existing + new values.
-- Idempotent: safe to run multiple times.

ALTER TABLE behavioral_events
  DROP CONSTRAINT IF EXISTS behavioral_events_event_type_check;

ALTER TABLE behavioral_events
  ADD CONSTRAINT behavioral_events_event_type_check
  CHECK (event_type = ANY (ARRAY[
    -- Original 12
    'condition_match_notified'::text,
    'notification_opened'::text,
    'app_opened_post_notification'::text,
    'activity_confirmed'::text,
    'condition_match_ignored'::text,
    'activity_viewed'::text,
    'wishlist_added'::text,
    'wishlist_removed'::text,
    'condition_profile_updated'::text,
    'affiliate_link_clicked'::text,
    'partner_impression_viewed'::text,
    'partner_cta_clicked'::text,
    -- Added for onboarding flow
    'auth_completed'::text,
    'auth_skipped'::text,
    'onboarding_completed'::text,
    'booking_integration_viewed'::text,
    'theme_override_set'::text,
    -- Added for behavioral event audit
    'category_created'::text,
    'category_selected'::text,
    'category_deselected'::text,
    'filter_applied'::text,
    'filter_cleared'::text,
    'weather_refreshed'::text,
    'notification_preference_changed'::text,
    'settings_changed'::text,
    -- Added for account deletion
    'account_deletion_requested'::text,
    -- Added for one-shot calendar export
    'calendar_event_added'::text,
    -- Added for the outcome loop's streak milestones
    'activity_milestone_reached'::text,
    -- Added for adaptive condition suggestions
    'condition_suggestion_shown'::text,
    'condition_suggestion_accepted'::text,
    'condition_suggestion_declined'::text
  ]));
