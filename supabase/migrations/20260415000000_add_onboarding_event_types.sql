-- Add 5 event types used by the onboarding flow that were missing from the
-- behavioral_events check constraint:
--   auth_completed, auth_skipped, onboarding_completed,
--   booking_integration_viewed, theme_override_set
--
-- The Flutter app has been logging these since the onboarding screens were
-- built, but inserts failed silently because the constraint only allowed the
-- original 12 values.

ALTER TABLE behavioral_events
  DROP CONSTRAINT behavioral_events_event_type_check;

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
    'theme_override_set'::text
  ]));
