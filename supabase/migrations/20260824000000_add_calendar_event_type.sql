-- Add the event type logged when a user exports a matched day to their
-- device calendar:
--   calendar_event_added
--
-- The Flutter app logs this after the event is created, with the day's
-- conditions snapshot attached. Without it the CHECK constraint rejects the
-- insert (23514) and the event is dropped silently, exactly like the
-- onboarding event types were before 20260415000000.
--
-- DELIBERATELY NOT REMOVED, though the client no longer emits them:
--   partner_cta_clicked
--   notification_preference_changed
--
-- Both came out of the client allowlist in this same change — neither ever
-- had a call site, and the notification-preference feature behind the second
-- was deleted in 49760bf. They stay permitted here on purpose:
--
--   1. The client allowlist is the gate that actually stops writes. This
--      constraint is defence-in-depth, and a superset costs nothing.
--   2. ADD CONSTRAINT ... CHECK validates existing rows. If any historical
--      row carries either type, tightening would fail the migration.
--   3. Re-introducing either later would need yet another migration.
--
-- So this is an omission by decision, not by oversight.
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
    'calendar_event_added'::text
  ]));
