# Tasks -- Test Coverage
# Created: 2026-05-19
# Requires: design.md approved

## Task 1 -- NotificationPreference Model Unit Tests
Visible when done: NotificationPreference fromJson/toJson has full
coverage including morning_time parsing and defaults.

- [ ] Create `test/data/models/notification_preference_test.dart`
- [ ] Test: `fromJson` parses all fields correctly
  - All boolean fields, `days_before_count`, `activity_id`, `id`
  - `morning_time` string "08:30:00" parsed to
    `TimeOfDay(hour: 8, minute: 30)`
  - `created_at` and `updated_at` parsed as DateTime
- [ ] Test: `toJson` produces correct snake_case keys
  - `morning_time` serialized as "HH:mm:00" format
  - Boolean fields use correct snake_case names
  - `created_at`/`updated_at` serialized as ISO 8601
- [ ] Test: `fromJson` -> `toJson` round trip preserves all values
  - Create a full JSON map, parse it, serialize it back, compare
  - `morning_time` survives round trip (string -> TimeOfDay -> string)
- [ ] Test: `fromJson` handles null/missing optional fields
  - Missing `notify_days_before` defaults to `false`
  - Missing `days_before_count` defaults to `2`
  - Missing `morning_time` defaults to `TimeOfDay(hour: 7, minute: 0)`
  - Missing `created_at`/`updated_at` default to `null`
- [ ] Run `flutter test test/data/models/notification_preference_test.dart`
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 -- Condition Matching Edge Case Tests
Visible when done: `evaluateMatch` has boundary and edge case coverage
beyond the existing 8 tests.

- [ ] Extend `test/features/home/condition_match_test.dart` with:
  - Test: temperature at exact min boundary returns true
    (temp=15.0, tempMin=15.0 — NOT < tempMin — true)
  - Test: temperature at exact max boundary returns true
    (temp=30.0, tempMax=30.0 — NOT > tempMax — true)
  - Test: precipitation 'light' with precipitationIntensity > 0
    returns true
    **Annotate with comment:** "Documents current behavior: 'light'
    and 'any' are functionally identical in evaluateMatch — only
    'none' checks precipitationIntensity. If a precipitation threshold
    is added for 'light', this test should be updated."
  - Test: wind at exact max boundary returns true
    (windSpeed=20.0, windMax=20.0 — NOT > windMax — true)
  - Test: wind just over max returns false
    (windSpeed=20.1, windMax=20.0 — > windMax — false)
  - Test: UV at exact min boundary returns true
    (uvIndex=3.0, uvMin=3.0 — NOT < uvMin — true)
  - Test: UV at exact max boundary returns true
    (uvIndex=8.0, uvMax=8.0 — NOT > uvMax — true)
  - Test: all four conditions enabled, three met, one not met
    returns false (e.g. temp OK, precip OK, wind OK, UV too high)
- [ ] Run `flutter test test/features/home/condition_match_test.dart`
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 -- Category Filtering Unit Tests
Visible when done: `filterActivitiesByCategories` has full coverage.

- [ ] Check if `test/features/home/category_filter_test.dart` exists
  (Feature 2 Task 1 creates it)
- [ ] If it exists with the required tests, verify and mark as done
- [ ] If it does not exist, create it with:
  - Test: empty selectedCategoryIds returns all activities
  - Test: one selected category returns only matching activities
  - Test: multiple selected categories uses OR logic
  - Test: activity with empty category_ids excluded when filter active
  - Test: activity with multiple category_ids matches if any is in set
  - Test: single activity matching multiple selected categories
    appears exactly once
- [ ] Run `flutter test test/features/home/category_filter_test.dart`
- [ ] Run `flutter analyze` — must pass before Task 4

## Task 4 -- AddActivityScreen Widget Tests
Visible when done: Save success, save error, loading indicator, and
wishlist_added event tests pass.

- [ ] Add `MockActivityRepository` mock class using mocktail
- [ ] Add mock for `supabaseClientProvider` that returns a fake user
  with a test ID
- [ ] Add `MockBehavioralEventService` mock (if not already present)
  with `when(() => mock.log(any(), extra: any(named: 'extra')))
  .thenAnswer((_) async {})`
- [ ] Test: entering a name enables the save button
  (may already exist — verify and skip if covered)
- [ ] Test: tapping save with valid name calls
  `insertWithConditions` on the mock repository
  - Mock returns a fake Activity
  - Enter name, tap Save, verify mock was called
  - Verify screen pops (check widget tree after pumpAndSettle)
- [ ] Test: save failure shows error banner
  - Mock `insertWithConditions` to throw an Exception
  - Enter name, tap Save, pump
  - Verify "Could not save activity" text appears
- [ ] Test: save button shows loading indicator while saving
  - Mock `insertWithConditions` with a delayed Completer
  - Enter name, tap Save, pump once (don't settle)
  - Verify `CircularProgressIndicator` in widget tree
  - Complete the Completer, pumpAndSettle
- [ ] Test: successful save fires `wishlist_added` behavioral event
  - Mock repository to succeed
  - Enter name, tap Save, pumpAndSettle
  - `verify(() => mockEventService.log('wishlist_added',
    extra: any(named: 'extra'))).called(1)`
  - This pins the Feature 5 requirement that wishlist_added fires
    on every successful activity creation
- [ ] Test: empty name keeps save button disabled
  (may already exist — verify and skip if covered)
- [ ] Run `flutter test test/features/add_activity/`
- [ ] Run `flutter analyze` — must pass before Task 5

## Task 5 -- ActivityDetailScreen Widget Tests
Visible when done: Form population, save flow, archive dialog,
notification toggle, and orphaned category tests pass.

- [ ] Add `MockActivityRepository` and
  `MockNotificationPreferenceRepository` mock classes
- [ ] Create helper: test Activity with all fields populated
  (including ConditionProfile with some conditions enabled)
- [ ] Create helper: test NotificationPreference with some toggles on
- [ ] Test: activity data populates form fields on load
  - Override `activityDetailProvider` to return test Activity
  - Override `notificationPreferenceProvider` to return test prefs
  - Pump, verify name TextField contains activity.name
  - Verify notes TextField contains activity.notes
- [ ] Test: tapping save calls `updateWithConditions` and
  `notificationPreferenceRepository.upsert`
  - Mock both repos, override providers
  - Pump, tap Save
  - Verify `updateWithConditions` called
  - Verify `upsert` called
- [ ] Test: save failure shows error banner
  - Mock `updateWithConditions` to throw
  - Pump, tap Save
  - Verify "Failed to save" error text appears
- [ ] Test: archive confirmation dialog appears on archive tap
  - Pump, scroll to "Archive Activity", tap it
  - Verify dialog title "Archive Activity?" appears
  - Verify "Cancel" and "Archive" buttons in dialog
- [ ] Test: notification preference toggles update local state
  - Override providers with all notif prefs false
  - Pump, find "Morning of" section, tap its Switch
  - Pump, verify Switch value changed
- [ ] Test: orphaned category ID is handled gracefully
  - Create test Activity with `categoryIds: ['valid-id', 'orphaned-id']`
  - Override `categoriesProvider` to return only one category with
    id `'valid-id'`
  - Override `activityDetailProvider` to return the test Activity
  - Pump, verify exactly one category chip is rendered (not two)
  - The orphaned ID is silently skipped per Feature 1 design
    (logged via dart:developer, but the widget renders only valid chips)
- [ ] Run `flutter test test/features/activity_detail/`
- [ ] Run `flutter analyze` — must pass before Task 6

## Task 6 -- Integration Test (Activity Creation Flow)
Visible when done: Full flow from Add Activity form fill to activity
appearing in the Activities tab list.

- [ ] Create `test/integration/activity_creation_flow_test.dart`
- [ ] Set up with `IntegrationTestWidgetsFlutterBinding`
- [ ] Build minimal app shell with `ProviderScope` overrides:
  - Mock `activityRepositoryProvider` with in-memory list:
    `insertWithConditions` adds to list and returns Activity,
    `fetchForUser` returns the list
  - Mock `supabaseClientProvider` returning fake authenticated user
  - Fixed sunny theme overrides
  - `categoriesProvider` with empty list or test data
  - `weatherDataProvider` with test WeatherData
  - `behavioralEventServiceProvider` with no-op mock
- [ ] Test flow:
  - App starts on home (Activities tab)
  - Tap FAB (tooltip: "Add activity")
  - Enter "Morning Run" in name field
  - Enable temperature condition, adjust range
  - Tap Save
  - Verify screen returns to Activities tab
  - Verify "Morning Run" text appears in activity list
- [ ] Run integration test on simulator
- [ ] Run `flutter analyze` — must pass before Task 7

## Task 7 -- Final Verification
Visible when done: All tests pass. No production code modified.

- [ ] Run `flutter test` — ALL tests pass (not just new ones)
- [ ] Run `flutter analyze` — zero warnings
- [ ] Verify no files in `lib/` were modified (tests only)
- [ ] If any test revealed a bug in production code:
  - Document the bug
  - Fix in a separate commit
  - Re-run all tests after the fix

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] All new tests use `mocktail` for mocking
- [ ] All widget tests use `ProviderScope` with overrides
- [ ] All widget tests use fixed `WeatherTheme.sunny`
- [ ] Test file naming: `test/<mirror_of_lib_path>/<file>_test.dart`
- [ ] No production code changes
- [ ] `ai_docs/` does not need updating
