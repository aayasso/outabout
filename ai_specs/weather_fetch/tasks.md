# Tasks — Weather Fetch
# Created: 2026-05-04
# Requires: design.md approved

## Task 1 — WeatherData model update + cache logic
Visible when done: `WeatherData` has `fetchedAt` field. Cache read/write
in `weatherDataProvider`. `flutter analyze` passes.

Files:
- `lib/data/models/weather_data.dart` (update)
- `lib/features/home/home_providers.dart` (update)

Subtasks:
- [ ] Add `DateTime? fetchedAt` field to `WeatherData` (optional, not in
      fromJson — set only when loading from cache)
- [ ] In `weatherDataProvider`: after successful fetch, cache
      `WeatherData` JSON + timestamp to SharedPreferences
- [ ] In `weatherDataProvider`: on fetch failure, try loading from cache.
      If cache exists, return cached `WeatherData` with `fetchedAt` set.
      If no cache, rethrow the exception.
- [ ] Update existing `WeatherData` tests to account for new field
- [ ] Run `flutter analyze` — must pass before Task 2

---

## Task 2 — AppLifecycleListener
Visible when done: Weather re-fetches when app returns to foreground.

Files:
- `lib/main.dart` (update)

Subtasks:
- [ ] Change `OutAboutApp` from `ConsumerWidget` to
      `ConsumerStatefulWidget` to support `AppLifecycleListener`
      (lifecycle callbacks require stateful widget)
- [ ] Add `AppLifecycleListener` in the new state class's `initState`
- [ ] On `resume`: call `ref.invalidate(weatherDataProvider)`
- [ ] Dispose the listener in `dispose()`
- [ ] Verify pull-to-refresh on TodayTab still works
- [ ] Run `flutter analyze` — must pass before Task 3

---

## Task 3 — Staleness indicator on weather card
Visible when done: When weather data is cached (stale), the weather
summary card shows "Updated X min ago" below the temperature.

Files:
- `lib/features/home/tabs/today_tab.dart` (update)

Subtasks:
- [ ] Pass `WeatherData.fetchedAt` to `_WeatherSummaryCard`
- [ ] If `fetchedAt` is non-null and older than 30 minutes:
      show "Updated X min ago" using `OutAboutTypography.bodySmall(colors)`
- [ ] Format duration as "X min ago" or "X hr ago"
- [ ] All colors from design tokens
- [ ] Run `flutter analyze` — must pass before Task 4

---

## Task 4 — Tests + polish
Visible when done: Tests pass, pre-flight clean.

Files:
- `test/data/models/weather_data_test.dart` (update)
- `test/features/home/tabs/today_tab_test.dart` (update)

Subtasks:
- [ ] Unit test: `WeatherData` with `fetchedAt` set
- [ ] Unit test: cache write + read round-trip via SharedPreferences
- [ ] Widget test: staleness text appears when `fetchedAt` is old
- [ ] Widget test: no staleness text when `fetchedAt` is null
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings
- [ ] Pre-flight checklist from CLAUDE.md

---

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
