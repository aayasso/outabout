# Design -- Test Coverage
# Created: 2026-05-19
# Requires: requirements.md approved

## Existing Test Inventory

### What exists

| Test file | What it covers | Gaps |
|---|---|---|
| `test/features/add_activity/add_activity_screen_test.dart` | Renders name field + save button; save button disabled when empty | Missing: save success flow, save error flow, loading indicator, wishlist_added event |
| `test/features/activity_detail/activity_detail_screen_test.dart` | Mock setup with BehavioralEventService | Missing: form population, save flow, archive flow, notification prefs, orphaned category handling |
| `test/features/home/condition_match_test.dart` | 8 cases: null profile, all disabled, temp too low/high, precip none+rain, wind too high, UV too low/high, all met | Missing: exact boundaries, precipitation 'light', all enabled one fails |
| `test/data/models/activity_test.dart` | Activity fromJson/toJson | — |
| `test/data/models/condition_profile_test.dart` | ConditionProfile fromJson/toJson | — |
| `test/data/models/weather_data_test.dart` | WeatherData fromJson/toJson | — |
| `test/data/models/profile_test.dart` | Profile fromJson/toJson | — |
| `test/services/behavioral_event_service_test.dart` | Event service payload + validation | — |

### What's missing (this spec adds)

| Test | Type | File |
|---|---|---|
| AddActivityScreen save success | Widget | `add_activity_screen_test.dart` (extend) |
| AddActivityScreen save error | Widget | `add_activity_screen_test.dart` (extend) |
| AddActivityScreen save loading | Widget | `add_activity_screen_test.dart` (extend) |
| AddActivityScreen wishlist_added event | Widget | `add_activity_screen_test.dart` (extend) |
| ActivityDetailScreen form population | Widget | `activity_detail_screen_test.dart` (extend) |
| ActivityDetailScreen save + notif prefs | Widget | `activity_detail_screen_test.dart` (extend) |
| ActivityDetailScreen save error | Widget | `activity_detail_screen_test.dart` (extend) |
| ActivityDetailScreen archive dialog | Widget | `activity_detail_screen_test.dart` (extend) |
| ActivityDetailScreen notif toggles | Widget | `activity_detail_screen_test.dart` (extend) |
| ActivityDetailScreen orphaned category | Widget | `activity_detail_screen_test.dart` (extend) |
| NotificationPreference fromJson/toJson | Unit | `notification_preference_test.dart` (new) |
| Category filtering logic | Unit | `category_filter_test.dart` (new or verify Feature 2) |
| Condition matching edge cases | Unit | `condition_match_test.dart` (extend) |
| Activity creation integration | Integration | `activity_creation_flow_test.dart` (new) |

## Test Architecture

### Widget test pattern (existing, follow it)

Both existing test files use the same pattern:
```dart
Widget buildTestWidget({List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      weatherThemeProvider.overrideWith(
        (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
      ),
      weatherThemeColorsProvider.overrideWithValue(
        WeatherThemeColors.sunny,
      ),
      // additional provider overrides
      ...overrides,
    ],
    child: const MaterialApp(home: ScreenUnderTest()),
  );
}
```

All widget tests use `WeatherTheme.sunny` as a fixed theme for
deterministic rendering. Provider overrides mock all async data.

### Mock pattern (existing, follow it)

```dart
class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

class MockActivityRepository extends Mock
    implements ActivityRepository {}

class MockNotificationPreferenceRepository extends Mock
    implements NotificationPreferenceRepository {}
```

Use `mocktail` for all mocks. Use `when(...).thenAnswer(...)` for
async methods. Use `verify(...)` to confirm expected calls.

### Provider overrides needed for each screen

**AddActivityScreen** requires:
- `weatherThemeProvider` + `weatherThemeColorsProvider` (theme)
- `activitiesProvider` (for invalidation after save)
- `activityRepositoryProvider` (mock — verify insert calls)
- `supabaseClientProvider` (mock — for auth.currentUser.id)
- `behavioralEventServiceProvider` (mock — verify wishlist_added)
- `profileProvider` (for temperatureUnit — after Feature 4)
- `categoriesProvider` (for category chips — after Feature 1)

**ActivityDetailScreen** requires all of the above plus:
- `activityDetailProvider(activityId)` (returns Activity with data)
- `notificationPreferenceProvider(activityId)` (returns prefs)
- `notificationPreferenceRepositoryProvider` (mock — verify upsert)

### Integration test approach

The integration test uses `package:integration_test` and runs on a
real device or simulator. It uses a `ProviderScope` with overrides
that return fake data, simulating the full flow without network calls.
An in-memory list in the mock ActivityRepository simulates persistence.

Test uses synthesized IDs and mocks the persistence layer entirely.
End-to-end verification against a real Supabase instance is out of
scope and remains a manual verification step in the simulator.

## Condition Matching — Gaps to Fill

Existing tests cover the failure cases well. Missing edge cases:

| Test case | Expected result | Why it matters |
|---|---|---|
| Temperature at exact min boundary | true | Boundary: `>=` vs `>` |
| Temperature at exact max boundary | true | Boundary: `<=` vs `<` |
| Precipitation 'light' with rain | true | Documents current behavior (see note below) |
| Wind at exact max boundary | true | Boundary check |
| Wind just over max | false | Confirms strict comparison |
| UV at exact min boundary | true | Boundary check |
| UV at exact max boundary | true | Boundary check |
| All enabled, one not met | false | Confirms AND logic across conditions |

### Precipitation 'light' behavior note

The `evaluateMatch` function (home_providers.dart:192-197) only checks
precipitation for the `'none'` level — it rejects if
`precipLevel == 'none' && precipitationIntensity > 0`. For `'light'`
and `'any'`, no check runs, so both accept any precipitation level.

This means `'light'` and `'any'` are functionally identical in the
current code. The UI presents three levels (None / Light / Any) with a
clear semantic gradient, but the matching logic doesn't distinguish
between 'light' and 'any'. This appears to be an incomplete
implementation — `'light'` likely should check against a threshold
(e.g., reject heavy precipitation) but no threshold constant exists
and Tomorrow.io's `precipitationIntensity` scale isn't documented in
the app's docs.

The test documents current behavior, not intended behavior. It is
annotated in the test with a comment: "Documents current behavior:
'light' and 'any' are functionally identical. If a precipitation
threshold is added for 'light', this test should be updated."

## Category Filtering — Test Status

Feature 2 Task 1 specifies creating
`test/features/home/category_filter_test.dart` with these test cases.
If Feature 2 ships first, the tests already exist — this spec verifies
they're present. If this spec runs first, it creates the tests.

## Files Created/Modified

| File | Action |
|---|---|
| `test/features/add_activity/add_activity_screen_test.dart` | Extend with 4 new test cases |
| `test/features/activity_detail/activity_detail_screen_test.dart` | Extend with 6 new test cases |
| `test/data/models/notification_preference_test.dart` | Create (4 test cases) |
| `test/features/home/condition_match_test.dart` | Extend with 8 new edge case tests |
| `test/features/home/category_filter_test.dart` | Verify exists (Feature 2) or create |
| `test/integration/activity_creation_flow_test.dart` | Create (1 integration test) |

## No Production Code Changes

This feature creates and extends test files only. No modifications to
`lib/` code. If any test reveals a bug, the bug fix is documented and
handled as a separate commit, not lumped into the test task.
