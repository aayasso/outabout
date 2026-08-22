-- Add the event type logged when a user requests account deletion:
--   account_deletion_requested
--
-- The Flutter app logs this immediately before calling the delete-account
-- edge function. Without it the CHECK constraint rejects the insert (23514)
-- and the event is dropped silently, exactly like the onboarding event types
-- were before 20260415000000.
--
-- The event row is itself deleted along with the rest of the user's data —
-- that is intended; it exists so the request is visible in any replica or
-- backup taken before the deletion completes.
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
    'account_deletion_requested'::text
  ]));
