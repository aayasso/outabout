# Schedule View — Tasks

> Spec created: 2026-06-27 | Branch: feature/schedule-view
> Status: DRAFT — awaiting product sign-off before implementation
>
> Blocked: Task 5 (widget count) depends on the open product decision
> about how many forecast days to show.

## Task 1: DailyForecast data model

**File:** `lib/data/models/daily_forecast.dart` (NEW)

- [ ] Create `DailyForecast` class with fields: `date` (DateTime),
  `temperatureMax`, `temperatureMin`, `precipitationProbability`,
  `windSpeedMax` (all double), `weatherCode` (int), `uvIndex` (double).
- [ ] `factory DailyForecast.fromJson(Map<String, dynamic> json)` —
  parses a single entry from `data.timelines.daily[]`. `time` field
  parsed to DateTime, values extracted from nested `values` map.
- [ ] `WeatherData toWeatherData()` — adapter method for matcher
  compatibility: temperature = avg(max, min), precipitationIntensity =
  probability > 0 ? 1.0 : 0.0, windSpeed = windSpeedMax.
- [ ] `List<DailyForecast> toJson()` for cache serialization.

**Test:** Unit test `fromJson` with sample Tomorrow.io response,
verify `toWeatherData()` adapter produces correct values.

## Task 2: ScheduleDay data model

**File:** `lib/data/models/schedule_day.dart` (NEW)

- [ ] Create `ScheduleDay` class: `forecast` (DailyForecast),
  `matchedActivities` (List\<Activity\>).
- [ ] const constructor.

No tests needed — pure data holder.

## Task 3: WeatherRepository.fetchForecast()

**File:** `lib/data/repositories/weather_repository.dart` (MODIFY)

- [ ] Add `Future<List<DailyForecast>> fetchForecast(double lat, double lng)`.
- [ ] Endpoint: `https://api.tomorrow.io/v4/forecast?timesteps=1d&fields=
  temperatureMax,temperatureMin,precipitationProbability,windSpeedMax,
  weatherCode,uvIndex&units=metric&apikey=$_apiKey&location=$lat,$lng`.
- [ ] Parse `json['timelines']['daily']` list, map to `DailyForecast.fromJson`.
- [ ] Throw `WeatherFetchException` on non-200 status.

**Test:** Unit test with mocked HTTP client, verify correct URL construction
and parsing.

## Task 4: dailyForecastProvider + scheduleMatchProvider

**File:** `lib/features/home/home_providers.dart` (MODIFY)

- [ ] Add `dailyForecastProvider` (FutureProvider\<List\<DailyForecast\>\>):
  watches `userLocationProvider`, calls `fetchForecast()`, caches result
  in SharedPreferences (same pattern as `weatherDataProvider`).
- [ ] Add `scheduleMatchProvider` (Provider\<AsyncValue\<List\<ScheduleDay\>\>\>):
  combines `dailyForecastProvider` + `activitiesProvider`, runs
  `evaluateMatch()` per (activity, day) pair via `day.toWeatherData()`.
- [ ] Remove `conditionMatchProvider` (replaced by schedule match).
- [ ] Keep `weatherDataProvider` unchanged (still needed for theme).
- [ ] Keep `evaluateMatch()` unchanged.

**Test:** Unit test `scheduleMatchProvider` with mocked forecast + activities,
verify correct match/no-match per day.

## Task 5: ScheduleTab widget

**File:** `lib/features/home/tabs/schedule_tab.dart` (NEW)

- [ ] `ScheduleTab` (ConsumerStatefulWidget) — watches
  `scheduleMatchProvider`, `weatherThemeColorsProvider`, `userLocationProvider`,
  `profileProvider`.
- [ ] Scaffold with `colors.background`, RefreshIndicator wrapping
  CustomScrollView.
- [ ] `_DaySection` — renders one forecast day: header + matched cards
  or empty state.
- [ ] `_DayHeader` — weather icon, day label, high/low temp. Day 0 =
  "Today", day 1 = "Tomorrow", day 2+ = weekday + date.
- [ ] `_ScheduleActivityCard` — activity name, category, tap to detail.
  Green left border. Staggered entrance animation.
- [ ] `_DayEmptyState` — single line "No activities match this day's
  forecast."
- [ ] `_ScheduleEmptyState` — full-screen empty state when no activities
  exist (reuse pattern from `_TodayEmptyState`).
- [ ] `_ScheduleShimmer` — loading skeleton: N day-shaped shimmer blocks.
- [ ] `_ScheduleErrorBanner` — forecast error with pull-to-refresh prompt.
- [ ] Pull-to-refresh invalidates `dailyForecastProvider`,
  `weatherDataProvider`, `activitiesProvider`. Logs `weather_refreshed`.
- [ ] Haptics: `onConditionMatch()` fires once if any day has matches.
- [ ] All entrance animations via `flutter_animate`.

**Depends on:** Tasks 1-4, product decision on day count.

## Task 6: Update HomeScreen + router

**File:** `lib/features/home/home_screen.dart` (MODIFY)
**File:** `lib/core/router.dart` (MODIFY)

- [ ] Change first NavigationDestination label from 'Today' to 'Schedule'
  (or 'Forecast' — confirm with product).
- [ ] Change icon from `Icons.wb_sunny_outlined` to
  `Icons.calendar_today_outlined` (or similar — confirm with product).
- [ ] Update router to use `ScheduleTab` instead of `TodayTab` for the
  first shell branch.

## Task 7: Delete TodayTab

**File:** `lib/features/home/tabs/today_tab.dart` (DELETE)

- [ ] Delete the file after ScheduleTab is verified working.
- [ ] Remove any orphaned imports referencing today_tab.dart.
- [ ] Verify `flutter analyze` passes with zero warnings.
- [ ] Verify `flutter test` passes.

## Task 8: Forecast caching

**File:** `lib/features/home/home_providers.dart` (MODIFY)

- [ ] In `dailyForecastProvider`, cache the forecast JSON in
  SharedPreferences under `_cacheForecastKey`.
- [ ] Store fetch timestamp under `_cacheForecastFetchedAtKey`.
- [ ] On network failure, attempt to load cached forecast.
- [ ] If cached forecast is older than 6 hours, still show it but
  mark as stale (optional staleness indicator in UI).

## Task 9: Behavioral event updates

**File:** `lib/features/home/tabs/schedule_tab.dart`

- [ ] `weather_refreshed` event on pull-to-refresh (existing pattern).
- [ ] `activity_card_tapped` event when tapping an activity card
  (if this event type exists; check behavioral_events constraint).
- [ ] Verify no TodayTab-specific events are orphaned.

## Task 10: Accessibility + polish pass

- [ ] All interactive elements have `tooltip` or `Semantics` label.
- [ ] Tap targets >= 48x48dp.
- [ ] Verify contrast across all 5 weather themes for day headers,
  activity cards, and empty states.
- [ ] Verify screen reader announces day sections and activity names.

## Execution Order

```
Task 1 (model) ──┐
Task 2 (model) ──┼── Task 3 (repo) ── Task 4 (providers) ── Task 5 (widget)
                 │                                             │
                 │                                    Task 6 (home/router)
                 │                                             │
                 │                                    Task 7 (delete today)
                 │
                 └── Task 8 (caching, can parallel with 5)
                     Task 9 (events, after 5)
                     Task 10 (a11y, after 5)
```

Tasks 1+2 can run in parallel. Task 3 depends on Task 1.
Task 4 depends on Tasks 1-3. Task 5 depends on Task 4 + product decision.
Tasks 6-7 depend on Task 5. Tasks 8-10 can follow Task 5.
