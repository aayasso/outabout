# Requirements -- Behavioral Event Audit
# Created: 2026-05-19
# Status: draft

## Summary

Audit every meaningful user action across the app and ensure each logs a
behavioral event via `BehavioralEventService`. The `behavioral_events`
table is the data foundation for the intelligence platform. This feature
verifies existing events fire correctly and adds missing event types for
new interactions.

## User Stories

### Primary flow
- As the intelligence platform, I need every meaningful user action
  logged with context so that I can build activity and weather pattern
  models.

### Secondary flows
- As a product analyst, I want category and filter interactions tracked
  so that I can understand how users organize activities.
- As a product analyst, I want settings changes tracked so that I can
  see user preference trends.

### Edge cases
- What happens when event logging fails (network error)? Events are
  fire-and-forget. Log the error via `dart:developer` but never block
  the user's action.
- What happens when the user is not authenticated? Skip event logging
  (BehavioralEventService already handles this).

## Acceptance Criteria

### Verify existing events fire correctly
- [ ] `wishlist_added` (activity_created) fires on Add Activity save.
      Extra includes `activity_name`.
- [ ] `condition_profile_updated` (activity_updated) fires on Activity
      Detail save. Extra includes `activity_id`.
- [ ] `auth_completed` fires on successful sign-in/sign-up.
- [ ] `auth_skipped` fires on anonymous sign-in.
- [ ] `booking_integration_viewed` fires on booking integrations page
      view.
- [ ] `onboarding_completed` fires at each onboarding step with
      `step` in extra.
- [ ] `theme_override_set` fires when user changes theme override.
      Verify it exists -- if not, add it to `_ThemeOverrideSelector`
      in settings_tab.dart. Extra includes `theme` (name or "adaptive").
- [ ] `notification_opened` fires when user taps a notification.

### Add new event types
- [ ] `category_created` -- fires when user creates a custom category.
      Extra: `category_name`, `has_color`.
- [ ] `category_selected` -- fires when user selects a category chip on
      an activity. Extra: `category_id`, `activity_id` (or null if on
      Add Activity before save).
- [ ] `category_deselected` -- fires when user deselects a category chip.
      Extra: same as above.
- [ ] `filter_applied` -- fires when user selects a category filter chip
      on Activities tab. Extra: `category_id`, `active_filter_count`.
- [ ] `filter_cleared` -- fires when user taps "All" to clear filters.
      Extra: `previous_filter_count`.
- [ ] `weather_refreshed` -- fires on pull-to-refresh on Today tab.
      Extra: none (context is captured automatically by the service).
- [ ] `notification_preference_changed` -- fires when any notification
      toggle changes in Activity Detail. Extra: `activity_id`,
      `preference_type` (e.g. 'morning_of', 'night_before',
      'days_before', 'sunday_digest'), `new_value` (bool).
- [ ] `settings_changed` -- fires on temperature unit toggle and theme
      override change. Extra: `setting` (e.g. 'temperature_unit',
      'theme_override'), `new_value`.

### Supabase migration (hard requirement)
- [ ] A Supabase migration expands the `behavioral_events.event_type`
      CHECK constraint to include all new event types:
      `category_created`, `category_selected`, `category_deselected`,
      `filter_applied`, `filter_cleared`, `weather_refreshed`,
      `notification_preference_changed`, `settings_changed`.
      This preserves data integrity for the intelligence platform --
      new events must not be remapped to semantically incorrect types.

## Screens Involved

- AddActivityScreen -- verify `wishlist_added`, add category events.
- ActivityDetailScreen -- verify `condition_profile_updated`, add
  `notification_preference_changed`.
- ActivitiesTab -- add `filter_applied`, `filter_cleared`.
- TodayTab -- add `weather_refreshed`.
- SettingsTab -- add/verify `theme_override_set`, add `settings_changed`.
- Custom category dialog (new widget from activity_categories spec) --
  add `category_created`.

## Data Requirements

- Supabase tables: `behavioral_events` (existing)
- New columns needed: none
- New CHECK constraint values: `category_created`, `category_selected`,
  `category_deselected`, `filter_applied`, `filter_cleared`,
  `weather_refreshed`, `notification_preference_changed`,
  `settings_changed`
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations

- Does this feature behave differently across themes? No
- The active theme name is already captured in `session_context` by
  BehavioralEventService.

## Dependencies

- Depends on Feature 1 (activity_categories): `category_created`,
  `category_selected`, and `category_deselected` events fire from the
  category picker UI built in that spec.
- Depends on Feature 2 (category_filtering): `filter_applied` and
  `filter_cleared` events fire from the filter chip row built in that
  spec.

## Out of Scope

- Analytics dashboard or reporting
- Event batching or offline queue
- Retroactive event backfill
