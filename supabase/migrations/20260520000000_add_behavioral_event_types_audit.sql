-- Add 8 event types for the behavioral event audit (Feature 5):
--   category_created, category_selected, category_deselected,
--   filter_applied, filter_cleared, weather_refreshed,
--   notification_preference_changed, settings_changed
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
    'settings_changed'::text
  ]));
