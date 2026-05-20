# Requirements -- Test Coverage
# Created: 2026-05-19
# Status: draft

## Summary

Improve test coverage in areas that are currently thin. Focus on widget
tests for the Add Activity and Activity Detail save flows, unit tests
for models and filtering logic, and an integration test for the full
activity creation flow.

## User Stories

### Primary flow
- As a developer, I want widget tests covering the Add Activity save
  flow (success and error paths) so that regressions are caught early.
- As a developer, I want widget tests covering the Activity Detail save
  flow including notification preferences so that edits don't break.

### Secondary flows
- As a developer, I want unit tests for NotificationPreference model
  fromJson/toJson round trip so that serialization is reliable.
- As a developer, I want unit tests for category filtering logic so
  that filter behavior is verified.
- As a developer, I want unit tests for condition matching edge cases
  so that the matching algorithm is bulletproof.
- As a developer, I want an integration test for the full activity
  creation flow so that the end-to-end path works.

### Edge cases
- Tests must use mocktail for mocking Supabase and repository classes.
- Tests must provide Riverpod overrides for all providers used by the
  widgets under test.

## Acceptance Criteria

### Widget tests -- AddActivityScreen
- [ ] Test: entering a name enables the save button.
- [ ] Test: tapping save with a valid name calls repository
      `insertWithConditions` and pops the screen.
- [ ] Test: save failure shows error banner with message.
- [ ] Test: save button shows loading indicator while saving.
- [ ] Test: empty name keeps save button disabled.

### Widget tests -- ActivityDetailScreen
- [ ] Test: activity data populates form fields on load.
- [ ] Test: tapping save calls repository `updateWithConditions`
      and notification preference repository `upsert`.
- [ ] Test: save failure shows error banner.
- [ ] Test: archive confirmation dialog appears on archive tap.
- [ ] Test: notification preference toggles update local state.

### Unit tests -- NotificationPreference model
- [ ] Test: fromJson correctly parses all fields including
      `morning_time` as TimeOfDay.
- [ ] Test: toJson produces correct snake_case keys.
- [ ] Test: fromJson -> toJson round trip preserves all values.
- [ ] Test: fromJson handles null/missing optional fields with
      correct defaults.

### Unit tests -- Category filtering logic
- [ ] Test: empty selected categories returns all activities (All).
- [ ] Test: selecting one category returns only activities containing
      that category ID in `category_ids`.
- [ ] Test: selecting multiple categories returns activities matching
      any (OR logic).
- [ ] Test: activity with empty `category_ids` is excluded when a
      filter is active.
- [ ] Test: activity with multiple `category_ids` matches if any one
      is in the filter set.

### Unit tests -- Condition matching edge cases
- [ ] Test: `evaluateMatch` with null profile returns true (no
      conditions = always matches).
- [ ] Test: all conditions disabled returns true.
- [ ] Test: all conditions enabled, all met returns true.
- [ ] Test: all conditions enabled, one not met returns false.
- [ ] Test: temperature at exact boundary (min/max) returns true.
- [ ] Test: precipitation 'none' with precipitationIntensity > 0
      returns false.
- [ ] Test: precipitation 'light' with any precipitation returns true.
- [ ] Test: wind at exact max boundary returns true; over max returns
      false.
- [ ] Test: UV at exact min/max boundaries returns true.

### Integration test -- Activity creation flow
- [ ] Test: navigate to Add Activity, fill name, set temperature
      condition, save, verify activity appears in Activities tab list.

## Screens Involved

- AddActivityScreen -- widget tests
- ActivityDetailScreen -- widget tests
- ActivitiesTab -- indirectly tested via integration test
- No screen modifications -- tests only

## Data Requirements

- Supabase tables: mocked via mocktail
- New columns needed: none
- Tomorrow.io fields needed: none
- SharedPreferences keys: none

## Weather Theme Considerations

- Does this feature behave differently across themes? No -- tests use
  a fixed theme override for deterministic rendering.

## Dependencies

- Depends on Feature 2 (category_filtering): the category filtering
  unit tests exercise the filtering logic built in that spec.
- The condition matching and NotificationPreference model tests have
  no dependencies -- they test existing code.
- Widget tests for AddActivityScreen and ActivityDetailScreen test
  existing screens and can run without other features, but should be
  updated if Features 1 or 4 modify those screens first.

## Out of Scope

- Tests for onboarding flow (already has test coverage)
- Tests for settings tab interactions
- Performance/benchmark tests
- Snapshot/golden image tests
