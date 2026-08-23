-- Add the event type logged when an activity's completion count crosses a
-- streak milestone:
--   activity_milestone_reached
--
-- One event type carrying the threshold in session_context — {"milestone": 5}
-- — rather than four separate types (first/5/10/25). Two reasons:
--
--   1. A future milestone (50, 100) then needs no migration at all, and this
--      constraint has already been rewritten four times for single additions.
--   2. The value is bounded vocabulary, so it survives
--      deidentify_behavioral_events intact. That function strips the free-text
--      and identifying keys from session_context by name; an integer drawn
--      from a fixed set is exactly the kind of key it deliberately keeps,
--      alongside step and permission_granted.
--
-- Without this the CHECK rejects the insert (23514) and the event is dropped
-- silently — BehavioralEventService.log swallows its errors by design, so
-- nothing surfaces. Apply before shipping a build that logs it.
--
-- The two types deliberately retained but no longer emitted by the client are
-- still listed, for the reasons set out in 20260824000000: the client
-- allowlist is the gate that actually stops writes, ADD CONSTRAINT validates
-- existing rows so tightening could fail on history, and re-introducing either
-- would need yet another migration.
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
    'activity_milestone_reached'::text
  ]));
