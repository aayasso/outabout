# Schedule View — Tasks

> Spec created: 2026-06-27 | Revised: 2026-06-27 (overlap rule)
> Branch: feature/schedule-view
> Status: READY FOR IMPLEMENTATION

## Task 1: DailyForecast data model

**File:** `lib/data/models/daily_forecast.dart` (NEW)

- [ ] Create `DailyForecast` class with fields: `date` (DateTime),
  `temperatureMax`, `temperatureMin`, `precipitationProbability`,
  `windSpeedMax` (all double), `weatherCode` (int).
- [ ] `factory DailyForecast.fromJson(Map<String, dynamic> json)` —
  parses a single entry from `timelines.daily[]`. `time` field
  parsed to DateTime, values extracted from nested `values` map.
- [ ] `Map<String, dynamic> toJson()` — for cache serialization only.
- [ ] NO `toWeatherData()` adapter. Daily forecast values are used
  directly by `evaluateDayMatch()`.
- [ ] NO `uvIndex` field — not used by matching or display.

**Test:** Unit test `fromJson` with sample Tomorrow.io response shape,
round-trip `toJson` -> `fromJson`.

## Task 2: ScheduleDay data model + ScheduleLayout enum

**File:** `lib/data/models/schedule_day.dart` (NEW)

- [ ] Create `ScheduleDay` class: `forecast` (DailyForecast),
  `matchedActivities` (List\<Activity\>). Const constructor.
- [ ] Create `ScheduleLayout` enum: `dayFirst`, `activityFirst`.

No tests needed — pure data holders.

## Task 3: WeatherRepository.fetchForecast()

**File:** `lib/data/repositories/weather_repository.dart` (MODIFY)

- [ ] Add `Future<List<DailyForecast>> fetchForecast(double lat, double lng)`.
- [ ] Endpoint: `https://api.tomorrow.io/v4/forecast?timesteps=1d&fields=
  temperatureMax,temperatureMin,precipitationProbability,windSpeedMax,
  weatherCode&units=metric&apikey=$_apiKey&location=$lat,$lng`.
- [ ] Parse `json['timelines']['daily']` list, map to
  `DailyForecast.fromJson`.
- [ ] Throw `WeatherFetchException` on non-200 status.

**Test:** Unit test with mocked HTTP client, verify correct URL
construction and parsing.

## Task 4: evaluateDayMatch + providers

**File:** `lib/features/home/home_providers.dart` (MODIFY)

- [ ] Add `evaluateDayMatch(ConditionProfile? profile, DailyForecast day)`
  function that mirrors the backend `conditionsMatch` exactly:
  - Temperature (overlap rule): `day.temperatureMax < tempMin` fails,
    `day.temperatureMin > tempMax` fails. No averaging.
  - Precipitation: `precipitationProbability > 20` fails for "none",
    `> 60` fails for "light_ok"
  - Wind: `windSpeedMax > windMax` fails
- [ ] Add `dailyForecastProvider` (FutureProvider\<List\<DailyForecast\>\>):
  watches `userLocationProvider`, calls `fetchForecast()`, caches result
  in SharedPreferences (same pattern as `weatherDataProvider`).
- [ ] Add `scheduleMatchProvider`
  (Provider\<AsyncValue\<List\<ScheduleDay\>\>\>): combines
  `dailyForecastProvider` + `activitiesProvider`, runs
  `evaluateDayMatch()` per (activity, day) pair — using the daily
  forecast values directly, NOT via any adapter.
- [ ] Remove `conditionMatchProvider` (replaced by schedule match).
- [ ] Keep `weatherDataProvider` unchanged (still needed for theme).
- [ ] `evaluateMatch()` becomes dead code — deleted in Task 9 with TodayTab.

**Test:**
- Unit test `evaluateDayMatch` with constructed `DailyForecast` values
  and `ConditionProfile` values, verifying:
  - Temperature overlap matches backend: profile min=15, max=25,
    day max=30, min=20 => day.max(30) >= 15 and day.min(20) <= 25 => passes.
  - Precip "none" with probability=15 => passes (not > 20).
  - Precip "none" with probability=25 => fails (> 20).
  - Precip "light_ok" with probability=55 => passes (not > 60).
  - Precip "light_ok" with probability=65 => fails (> 60).
  - Wind max=30, day windSpeedMax=25 => passes.
  - Wind max=30, day windSpeedMax=35 => fails.
- Unit test `scheduleMatchProvider` with mocked forecast + activities,
  verify correct match/no-match per day.

## Task 5: Schedule layout provider + Settings row

**File:** `lib/features/home/home_providers.dart` (MODIFY)
**File:** `lib/features/home/tabs/settings_tab.dart` (MODIFY)

- [ ] Add `scheduleLayoutProvider` (StateNotifierProvider) following
  the exact pattern of `userThemeOverrideProvider` in
  `lib/core/weather_theme_provider.dart`:
  - `ScheduleLayoutNotifier` extends `StateNotifier<ScheduleLayout>`
  - SharedPreferences key: `'schedule_layout'`
  - `_loadLayout()` reads stored value, defaults to `dayFirst`
  - `setLayout(ScheduleLayout)` persists and updates state
- [ ] Add `_ScheduleLayoutRow` widget in settings_tab.dart, following
  the exact pattern of `_TemperatureUnitRow` (lines 470-519):
  - Icon: `Icons.view_agenda_outlined`
  - Label: "Schedule layout"
  - Trailing: current layout name ("Day-first" / "Activity-first")
  - onTap: toggle between values
  - Haptics: `OutAboutHaptics.onConditionToggle()`
  - Behavioral event: `settings_changed` with
    `{'setting': 'schedule_layout', 'new_value': layout.name}`
- [ ] Place the row below the temperature-unit row in settings.

## Task 6: ScheduleTab widget — day-first layout

**File:** `lib/features/home/tabs/schedule_tab.dart` (NEW)

- [ ] `ScheduleTab` (ConsumerStatefulWidget) — watches
  `scheduleMatchProvider`, `scheduleLayoutProvider`,
  `weatherThemeColorsProvider`, `profileProvider`.
- [ ] Scaffold with `colors.background`, RefreshIndicator wrapping
  content. Delegates to `_DayFirstLayout` or `_ActivityFirstLayout`
  based on `scheduleLayoutProvider`.
- [ ] `_DayFirstLayout` — CustomScrollView with SliverList of day
  sections.
- [ ] `_DaySection` — renders one forecast day: header + matched cards
  or empty state.
- [ ] `_DayHeader` — weather icon, day label, high/low temp (respects
  F/C preference), precipitation %, wind speed. Day 0 = "Today",
  day 1 = "Tomorrow", day 2+ = weekday + date.
- [ ] `_ScheduleActivityCard` — activity name, category, tap to detail.
  Green left border. Staggered entrance animation.
- [ ] `_DayEmptyState` — single line "No activities match this day's
  forecast."
- [ ] `_ScheduleEmptyState` — full-screen empty state when no activities
  exist (reuse pattern from `_TodayEmptyState`).
- [ ] `_ScheduleShimmer` — loading skeleton: 5 day-shaped shimmer blocks.
- [ ] `_ScheduleErrorBanner` — forecast error with pull-to-refresh
  prompt.
- [ ] Pull-to-refresh invalidates `dailyForecastProvider`,
  `weatherDataProvider`, `activitiesProvider`. Logs `weather_refreshed`.
- [ ] Haptics: `onConditionMatch()` fires once if any day has matches.
- [ ] All entrance animations via `flutter_animate`.

**Depends on:** Tasks 1-5.

## Task 7: ScheduleTab widget — activity-first layout

**File:** `lib/features/home/tabs/schedule_tab.dart` (MODIFY)

- [ ] `_ActivityFirstLayout` — CustomScrollView with SliverList of
  activity sections.
- [ ] Inverts `List<ScheduleDay>` into per-activity matching days in
  the widget layer (no new provider, no recompute).
- [ ] `_ActivitySection` — renders one activity: header + matching day
  badges or empty state.
- [ ] `_ActivityHeader` — activity name, category icon, condition
  summary.
- [ ] `_MatchingDayBadge` — compact badge: day label, high/low temp,
  small weather icon.
- [ ] `_ActivityEmptyState` — "No matching days this week."
- [ ] Staggered entrance animations per activity section.

**Depends on:** Task 6 (shared scaffold, refresh, empty states).

## Task 8: Update HomeScreen + router

**File:** `lib/features/home/home_screen.dart` (MODIFY)
**File:** `lib/core/router.dart` (MODIFY)

- [ ] Change first NavigationDestination label from 'Today' to
  'Schedule'.
- [ ] Change icon from `Icons.wb_sunny_outlined` to
  `Icons.calendar_today_outlined`.
- [ ] Update router to use `ScheduleTab` instead of `TodayTab` for the
  first shell branch.

## Task 9: Delete TodayTab

**File:** `lib/features/home/tabs/today_tab.dart` (DELETE)

- [ ] Delete the file after ScheduleTab is verified working.
- [ ] Remove any orphaned imports referencing today_tab.dart.
- [ ] Verify `flutter analyze` passes with zero warnings.
- [ ] Verify `flutter test` passes.

## Task 10: Forecast caching

**File:** `lib/features/home/home_providers.dart` (MODIFY)

- [ ] In `dailyForecastProvider`, cache the forecast JSON in
  SharedPreferences under `_cacheForecastKey`.
- [ ] Store fetch timestamp under `_cacheForecastFetchedAtKey`.
- [ ] On network failure, attempt to load cached forecast.
- [ ] If cached forecast is older than 6 hours, still show it but
  mark as stale (optional staleness indicator in UI).

## Task 11: Behavioral event updates

**File:** `lib/features/home/tabs/schedule_tab.dart`

- [ ] `weather_refreshed` event on pull-to-refresh (existing pattern).
- [ ] `activity_card_tapped` event when tapping an activity card
  (if this event type exists; check behavioral_events constraint).
- [ ] Verify no TodayTab-specific events are orphaned.

## Task 12: Accessibility + polish pass

- [ ] All interactive elements have `tooltip` or `Semantics` label.
- [ ] Tap targets >= 48x48dp.
- [ ] Verify contrast across all 5 weather themes for day headers,
  activity cards, empty states, and matching day badges.
- [ ] Verify screen reader announces day sections and activity names.
- [ ] Verify both layouts are accessible.

## Execution Order

```
Task 1 (model) ──┐
Task 2 (model) ──┼── Task 3 (repo) ── Task 4 (providers/matcher)
                 │                            │
                 │                    Task 5 (layout pref + settings)
                 │                            │
                 │                    Task 6 (day-first widget)
                 │                            │
                 │                    Task 7 (activity-first widget)
                 │                            │
                 │                    Task 8 (home/router)
                 │                            │
                 │                    Task 9 (delete today)
                 │
                 └── Task 10 (caching, can parallel with 6)
                     Task 11 (events, after 6)
                     Task 12 (a11y, after 7)
```

Tasks 1+2 can run in parallel. Task 3 depends on Task 1.
Task 4 depends on Tasks 1-3. Task 5 depends on Task 2 (enum).
Task 6 depends on Tasks 4+5. Task 7 depends on Task 6.
Tasks 8-9 depend on Task 7. Tasks 10-12 can follow Task 6/7.
