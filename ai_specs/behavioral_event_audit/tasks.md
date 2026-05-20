# Tasks -- Behavioral Event Audit
# Created: 2026-05-19
# Requires: design.md approved

## Task 1 -- Supabase Migration
Visible when done: CHECK constraint on `behavioral_events.event_type`
accepts all new event types.

- [ ] Create migration file:
  `supabase/migrations/YYYYMMDDHHMMSS_add_behavioral_event_types.sql`
- [ ] SQL: DROP old constraint (IF EXISTS), ADD new constraint with
  all existing types plus 8 new types:
  `category_created`, `category_selected`, `category_deselected`,
  `filter_applied`, `filter_cleared`, `weather_refreshed`,
  `notification_preference_changed`, `settings_changed`
- [ ] Run migration locally via `supabase db push` or equivalent
- [ ] Verify: insert a test row with each new type succeeds
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 -- Update approvedEventTypes
Visible when done: Client-side validation accepts all new event types.

- [ ] In `lib/services/behavioral_event_service.dart`, add to
  `approvedEventTypes` list:
  - `'category_created'`
  - `'category_selected'`
  - `'category_deselected'`
  - `'filter_applied'`
  - `'filter_cleared'`
  - `'weather_refreshed'`
  - `'notification_preference_changed'`
  - `'settings_changed'`
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 -- Fix Missing theme_override_set + Add settings_changed (SettingsTab)
Visible when done: Changing theme override fires `theme_override_set`
and `settings_changed`. Changing temperature unit fires
`settings_changed`.

- [ ] Import `behavioralEventServiceProvider` in settings_tab.dart
- [ ] In `_ThemeOverrideSelector`, inside the `onTap` handler
  (after `setOverride` call):
  - Fire `theme_override_set` with extra `{'theme': option.theme?.name ?? 'adaptive'}`
  - Fire `settings_changed` with extra
    `{'setting': 'theme_override', 'new_value': option.theme?.name ?? 'adaptive'}`
  - These two events are deliberate: `theme_override_set` for
    theme-specific analytics, `settings_changed` for generic
    settings-engagement analytics. Related, not duplicates.
- [ ] In `_TemperatureUnitRow`, inside the `onTap` handler
  (after the Supabase update call):
  - Fire `settings_changed` with extra
    `{'setting': 'temperature_unit', 'new_value': newUnit}`
- [ ] Run `flutter analyze` — must pass before Task 4

## Task 4 -- Fix Missing wishlist_removed (ActivityDetailScreen + ActivitiesTab)
Visible when done: Archiving an activity (via button or swipe) fires
`wishlist_removed` event.

- [ ] In `activity_detail_screen.dart`, inside `_onArchive`, after
  `repo.archive(activity.id!)` succeeds (before `ref.invalidate`):
  - Fire `wishlist_removed` with extra
    `{'activity_id': activity.id, 'method': 'archive_button'}`
- [ ] In `activities_tab.dart`, inside `Dismissible.onDismissed`
  callback, after `repo.archive(activity.id!)`:
  - Import `behavioralEventServiceProvider` (may already be present
    after Feature 2/5 work)
  - Fire `wishlist_removed` with extra
    `{'activity_id': activity.id, 'method': 'swipe_dismiss'}`
- [ ] Run `flutter analyze` — must pass before Task 5

## Task 5 -- Add weather_refreshed (TodayTab)
Visible when done: Pull-to-refresh on Today tab fires
`weather_refreshed` event.

- [ ] Import `behavioralEventServiceProvider` in today_tab.dart
- [ ] In the `RefreshIndicator.onRefresh` callback (line 87), at the
  start of the async function (before invalidating providers):
  - Fire `weather_refreshed` with no extra
- [ ] Run `flutter analyze` — must pass before Task 6

## Task 6 -- Add notification_preference_changed (ActivityDetailScreen)
Visible when done: Toggling any notification preference fires
`notification_preference_changed` with the correct preference type.

- [ ] In `_buildNotificationSection`, update each `onToggled` callback
  to fire the event after the `setState`:
  - Morning of toggle: preference_type `'morning_of'`
  - Night before toggle: preference_type `'night_before'`
  - Days before toggle: preference_type `'days_before'`
  - Sunday digest toggle: preference_type `'sunday_digest'`
  - All include `activity_id: widget.activityId` and `new_value: v`
- [ ] `behavioralEventServiceProvider` is already imported in
  activity_detail_screen.dart — verify
- [ ] Run `flutter analyze` — must pass before Task 7

## Task 7 -- Add Category Events (CategoryChipPicker + CreateCategoryDialog)
Visible when done: Selecting/deselecting category chips and creating
custom categories fire behavioral events.

- [ ] In the `onToggle` callback wiring sites (AddActivityScreen and
  ActivityDetailScreen), after the `setState` that toggles the chip:
  - Determine `isNowSelected` from the updated set
  - Fire `category_selected` or `category_deselected` with extra
    `category_id` and `activity_id` (null on AddActivityScreen)
- [ ] In the `CreateCategoryDialog` wiring site (after successful
  `CategoryRepository.insert`):
  - Fire `category_created` with extra `category_name` and `has_color`
    (boolean, whether color was selected)
- [ ] Run `flutter analyze` — must pass before Task 8

## Task 8 -- Add Filter Events (ActivitiesTab)
Visible when done: Toggling filter chips and tapping "All" fire
behavioral events.

- [ ] Import `behavioralEventServiceProvider` in activities_tab.dart
  (may already be present from Task 4)
- [ ] In the `onToggle` handler (where Feature 2 noted
  "// Feature 5 hook: filter_applied fires here"):
  - Fire `filter_applied` with extra `category_id` and
    `active_filter_count`
- [ ] In the `onClearAll` handler (where Feature 2 noted
  "// Feature 5 hook: filter_cleared fires here"):
  - Capture `previousCount = _selectedCategoryIds.length` BEFORE
    clearing the set
  - Then `setState(() => _selectedCategoryIds = {})`
  - Then fire `filter_cleared` with extra
    `{'previous_filter_count': previousCount}`
  - Order matters: capture count, clear set, log event
- [ ] Run `flutter analyze` — must pass before Task 9

## Task 9 -- Verify Existing Events + Final Check
Visible when done: All existing events verified. All new events
verified. Feature complete.

- [ ] Verify existing events (code review, no changes expected):
  - `wishlist_added` in add_activity_screen.dart:98 — fires with
    `activity_name`
  - `condition_profile_updated` in activity_detail_screen.dart:175 —
    fires with `activity_id`
  - `auth_completed` in auth_page.dart:74
  - `auth_skipped` in auth_page.dart:96
  - `booking_integration_viewed` in booking_integrations_page.dart:26
  - `onboarding_completed` in multiple onboarding pages with `step`
  - `notification_opened` in notification_service.dart:55
- [ ] Verify `theme_override_set` now fires (fixed in Task 3)
- [ ] Verify `wishlist_removed` now fires (fixed in Task 4)
- [ ] Write unit test: verify `approvedEventTypes` contains all 8 new
  types (simple list membership test in
  `test/services/behavioral_event_service_test.dart`)
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] All new events use fire-and-forget pattern (never block user action)
- [ ] All new events include meaningful `extra` context per requirements
- [ ] `approvedEventTypes` list matches Supabase CHECK constraint exactly
- [ ] Migration file exists in `supabase/migrations/`
- [ ] No hardcoded colors or UI changes (this feature is logging only)
- [ ] `ai_docs/supabase_api.md` updated: add new event types to the
  "Approved event_types" list under the behavioral_events table section
