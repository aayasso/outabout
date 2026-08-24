-- Add the event type logged when the app is opened from the home-screen
-- widget:
--   app_opened_from_widget
--
-- One type, and it is the entire funnel this feature can have. A WidgetKit
-- extension gets no callback when its view is rendered and none when it is
-- tapped — the tap is handled by the system, which opens the widget's URL. So
-- unlike every other surface in the app there is no impression to count and no
-- denominator to divide by: `app_opened_from_widget / sessions` is the closest
-- thing to a rate, and it is a different question from click-through.
--
-- Worth saying plainly because the absence will look like an oversight later:
-- we are not choosing to skip the impression event, we are unable to write one.
--
-- The event carries no `extra` payload. The widget offers exactly one
-- destination, so a `destination` key would be a constant, and the URL that
-- carried the user here is already implied by the type. session_context still
-- gets platform, app_version and active_theme like every other row, which is
-- what makes "does the widget bring people back" answerable by cohort.
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
    'condition_suggestion_declined'::text,
    -- Added for the home-screen widget
    'app_opened_from_widget'::text
  ]));
