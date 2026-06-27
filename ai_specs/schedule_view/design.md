# Schedule View — Design

> Spec created: 2026-06-27 | Revised: 2026-06-27 (overlap rule)
> Branch: feature/schedule-view
> Status: READY FOR IMPLEMENTATION

## Architecture Overview

```
Tomorrow.io /v4/forecast (1d)     Tomorrow.io /v4/weather/realtime
        |                                    |
  WeatherRepository                   WeatherRepository
  .fetchForecast()                    .fetchCurrent()
        |                                    |
  dailyForecastProvider              weatherDataProvider
        |                                    |
        +--- scheduleMatchProvider           +--- weatherThemeProvider
        |           |                             (theme still driven by
        |     ScheduleTab                          current conditions)
        |     (reads scheduleLayoutProvider
        |      to pick day-first or activity-first)
        |
  scheduleLayoutProvider (SharedPreferences)
```

### Data flow

1. `userLocationProvider` resolves user lat/lng (existing, unchanged).
2. `dailyForecastProvider` (NEW) calls `WeatherRepository.fetchForecast()`
   which hits `https://api.tomorrow.io/v4/forecast?timesteps=1d&fields=...`.
   Returns `List<DailyForecast>` (exactly 5 days).
3. `activitiesProvider` fetches user activities (existing, unchanged).
4. `scheduleMatchProvider` (NEW) combines daily forecasts + activities.
   For each forecast day, runs `evaluateDayMatch()` against every
   activity using the overlap rule on `temperatureMax`/`temperatureMin`
   and direct comparisons for `precipitationProbability` and
   `windSpeedMax`. No averaging. No adapter. Returns `List<ScheduleDay>`.
5. `scheduleLayoutProvider` (NEW) reads the user's layout preference
   from SharedPreferences. `ScheduleTab` watches this to decide which
   layout widget to render.
6. Both layouts consume the SAME `scheduleMatchProvider` data. Switching
   layouts does NOT refetch or recompute.
7. `weatherDataProvider` + `weatherThemeProvider` remain unchanged and
   continue driving the app theme from realtime conditions.

## New Data Models

### DailyForecast

```dart
class DailyForecast {
  final DateTime date;
  final double temperatureMax;   // Celsius (API returns metric)
  final double temperatureMin;   // Celsius
  final double precipitationProbability; // 0-100
  final double windSpeedMax;     // km/h
  final int weatherCode;         // Tomorrow.io code

  const DailyForecast({
    required this.date,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.precipitationProbability,
    required this.windSpeedMax,
    required this.weatherCode,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson(); // for cache serialization only
}
```

There is NO `toWeatherData()` adapter method. Daily forecast values are
used directly by `evaluateDayMatch()`.

JSON shape from Tomorrow.io daily timeline:
```json
{
  "time": "2026-06-27T06:00:00Z",
  "values": {
    "temperatureMax": 28.5,
    "temperatureMin": 18.2,
    "precipitationProbability": 10,
    "windSpeedMax": 22.0,
    "weatherCode": 1100
  }
}
```

Note: `uvIndex` is NOT requested or stored. The backend `conditionsMatch`
does not use it, and the app has no UV condition. This keeps the API
request minimal and avoids displaying data with no matching purpose.

### ScheduleDay

```dart
class ScheduleDay {
  final DailyForecast forecast;
  final List<Activity> matchedActivities;

  const ScheduleDay({
    required this.forecast,
    required this.matchedActivities,
  });
}
```

### ScheduleLayout enum

```dart
enum ScheduleLayout { dayFirst, activityFirst }
```

## New / Modified Providers

### evaluateDayMatch() (NEW — mirrors backend conditionsMatch, overlap rule)

```dart
/// Matches an activity's condition profile against a daily forecast.
/// Mirrors backend conditionsMatch in check-weather/index.ts exactly.
/// Uses overlap rule for temperature — no averaging.
bool evaluateDayMatch(
  ConditionProfile? profile,
  DailyForecast day,
) {
  if (profile == null) return true;

  if (profile.tempEnabled) {
    if (profile.tempMin != null &&
        day.temperatureMax < profile.tempMin!) {
      return false;
    }
    if (profile.tempMax != null &&
        day.temperatureMin > profile.tempMax!) {
      return false;
    }
  }

  if (profile.precipEnabled) {
    final precip = day.precipitationProbability;
    if (profile.precipLevel == 'none' && precip > 20) {
      return false;
    }
    if (profile.precipLevel == 'light_ok' && precip > 60) {
      return false;
    }
  }

  if (profile.windEnabled) {
    if (profile.windMax != null &&
        day.windSpeedMax > profile.windMax!) {
      return false;
    }
  }

  return true;
}
```

Temperature overlap rule: the day's [temperatureMin, temperatureMax]
must overlap the activity's [tempMin, tempMax]. If the day's max is
below the activity's min, or the day's min is above the activity's max,
there is no overlap and the day fails.

The existing `evaluateMatch()` is deleted along with TodayTab
(`conditionMatchProvider` is its only consumer; the theme system does
not depend on it).

### dailyForecastProvider (NEW)

```dart
final dailyForecastProvider =
    FutureProvider<List<DailyForecast>>((ref) async {
  final location =
      await ref.watch(userLocationProvider.future);
  if (location == null) throw NoLocationException();
  final repo = ref.watch(weatherRepositoryProvider);
  return repo.fetchForecast(
    location.latitude,
    location.longitude,
  );
});
```

Caching strategy: cache in SharedPreferences with a `_cacheForecastKey`
and `_cacheForecastFetchedAtKey`, same pattern as `weatherDataProvider`.
Fallback to cache on network failure.

### scheduleMatchProvider (NEW)

```dart
final scheduleMatchProvider =
    Provider<AsyncValue<List<ScheduleDay>>>((ref) {
  final forecastAsync = ref.watch(dailyForecastProvider);
  final activitiesAsync = ref.watch(activitiesProvider);

  return forecastAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (days) => activitiesAsync.when(
      loading: () => const AsyncLoading(),
      error: (e, st) => AsyncError(e, st),
      data: (activities) => AsyncData(
        days.map((day) {
          final matched = activities
              .where((a) => evaluateDayMatch(
                    a.conditionProfile,
                    day,
                  ))
              .toList();
          return ScheduleDay(
            forecast: day,
            matchedActivities: matched,
          );
        }).toList(),
      ),
    ),
  );
});
```

### scheduleLayoutProvider (NEW)

Follows the exact pattern of `userThemeOverrideProvider` in
`lib/core/weather_theme_provider.dart`:

```dart
const _scheduleLayoutKey = 'schedule_layout';

final scheduleLayoutProvider = StateNotifierProvider<
    ScheduleLayoutNotifier, ScheduleLayout>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ScheduleLayoutNotifier(prefs);
});

class ScheduleLayoutNotifier
    extends StateNotifier<ScheduleLayout> {
  final SharedPreferences _prefs;

  ScheduleLayoutNotifier(this._prefs)
      : super(_loadLayout(_prefs));

  static ScheduleLayout _loadLayout(SharedPreferences prefs) {
    final stored = prefs.getString(_scheduleLayoutKey);
    if (stored == 'activityFirst') {
      return ScheduleLayout.activityFirst;
    }
    return ScheduleLayout.dayFirst;
  }

  Future<void> setLayout(ScheduleLayout layout) async {
    state = layout;
    await _prefs.setString(
      _scheduleLayoutKey,
      layout.name,
    );
  }
}
```

### conditionMatchProvider — REMOVE

The today-only `conditionMatchProvider` is removed. Any code that watched
it should watch `scheduleMatchProvider` instead (day 0 for "today" data).

## Repository Changes

### WeatherRepository.fetchForecast() (NEW method)

```dart
Future<List<DailyForecast>> fetchForecast(
  double lat,
  double lng,
) async {
  final uri = Uri.parse(
    'https://api.tomorrow.io/v4/forecast'
    '?location=$lat,$lng'
    '&timesteps=1d'
    '&fields=temperatureMax,temperatureMin,'
    'precipitationProbability,windSpeedMax,'
    'weatherCode'
    '&units=metric'
    '&apikey=$_apiKey',
  );
  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw WeatherFetchException(
      response.statusCode,
      response.body,
    );
  }
  final json =
      jsonDecode(response.body) as Map<String, dynamic>;
  final daily = (json['timelines'] as Map<String, dynamic>)
      ['daily'] as List<dynamic>;
  return daily
      .map((d) => DailyForecast.fromJson(
          d as Map<String, dynamic>))
      .toList();
}
```

Matches the same endpoint and field set as the edge function
(`supabase/functions/check-weather/index.ts` line 14), minus `uvIndex`
which the backend fetches but does not use in `conditionsMatch`.

### WeatherRepository.fetchCurrent() — UNCHANGED

Still needed for theme provider. No modifications.

## Widget Structure

### ScheduleTab (replaces TodayTab)

```
ScheduleTab (ConsumerStatefulWidget)
  watches: scheduleMatchProvider, scheduleLayoutProvider,
           weatherThemeColorsProvider, profileProvider
  Scaffold(backgroundColor: colors.background)
    RefreshIndicator
      if layout == dayFirst:
        _DayFirstLayout
      else:
        _ActivityFirstLayout
```

### _DayFirstLayout

```
CustomScrollView
  SliverToBoxAdapter: _ScheduleHeader (greeting + location)
  SliverToBoxAdapter: _LocationPermissionBanner (if needed)
  SliverList: for each ScheduleDay =>
    _DaySection
      _DayHeader (date, weather icon, high/low temp,
                  precip %, wind speed)
      if matchedActivities.isNotEmpty:
        for each activity => _ScheduleActivityCard
      else:
        _DayEmptyState ("No activities match")
  SliverToBoxAdapter: _ScheduleFooter (forecast attribution)
```

### _ActivityFirstLayout

```
CustomScrollView
  SliverToBoxAdapter: _ScheduleHeader (greeting + location)
  SliverToBoxAdapter: _LocationPermissionBanner (if needed)
  SliverList: for each activity =>
    _ActivitySection
      _ActivityHeader (name, category icon, condition summary)
      if matchingDays.isNotEmpty:
        Wrap of _MatchingDayBadge (compact day + temp)
      else:
        _ActivityEmptyState ("No matching days this week")
  SliverToBoxAdapter: _ScheduleFooter (forecast attribution)
```

Both layouts derive their data from the same `List<ScheduleDay>`.
The activity-first layout inverts the data in the widget layer:

```dart
// Invert: for each activity, find which days match it
final activityDays = <Activity, List<DailyForecast>>{};
for (final activity in allActivities) {
  activityDays[activity] = scheduleDays
      .where((sd) =>
          sd.matchedActivities.contains(activity))
      .map((sd) => sd.forecast)
      .toList();
}
```

### If no activities at all => _ScheduleEmptyState (CTA to add activity)

### _DayHeader

Displays per-day weather summary:
- Left: weather icon (mapped from weatherCode, reuse `_weatherIconData()`)
- Center: day label ("Today", "Tomorrow", "Monday, Jul 1")
- Right: high/low temperature (respects user's F/C preference)
- Subtitle: condition name + precipitation % + wind speed

Uses `OutAboutTypography.headingMedium(colors)` for day name,
`OutAboutTypography.bodyMedium(colors)` for temperatures and details.

### _ScheduleActivityCard

Similar to current `_MatchedActivityCard` but without the "Conditions
met" label (every card in the schedule is matched by definition).
- Activity name, category icon, condition summary.
- Green left border accent (same `OutAboutColors.success` treatment).
- Tap navigates to activity detail.
- Staggered entrance animation.

### _MatchingDayBadge (activity-first layout)

Compact badge showing a matching day:
- Day label ("Today", "Mon")
- High/low temp
- Weather icon (small)
- Tap scrolls/highlights that day (stretch — not required for v1)

### _DayEmptyState

Quiet inline state within the day section:
- `OutAboutTypography.bodySmall(colors)` text
- No CTA, no icon — just a single line of text
- "No activities match this day's forecast"

### _ActivityEmptyState

Quiet inline state within the activity section:
- `OutAboutTypography.bodySmall(colors)` text
- "No matching days this week"

## Settings Tab Addition

New row in Settings, below the temperature-unit row:

```
_ScheduleLayoutRow
  icon: Icons.view_agenda_outlined
  label: "Schedule layout"
  trailing: current layout name ("Day-first" / "Activity-first")
  onTap: toggle between the two values
```

Follows the exact pattern of `_TemperatureUnitRow` in
`lib/features/home/tabs/settings_tab.dart` (lines 470-519):
- Reads from `scheduleLayoutProvider`
- On tap, calls `ref.read(scheduleLayoutProvider.notifier).setLayout(...)`
- Fires `OutAboutHaptics.onConditionToggle()`
- Logs `settings_changed` behavioral event with
  `{'setting': 'schedule_layout', 'new_value': layout.name}`

## Design System Usage

| Token | Usage |
|-------|-------|
| `weatherThemeColorsProvider` | ALL colors — background, text, card, surface |
| `OutAboutTypography.*` | ALL text styles, always with `(colors)` param |
| `OutAboutSpacing.md` | Padding between day/activity sections |
| `OutAboutSpacing.sm` | Padding within headers |
| `OutAboutSpacing.lg` | Top/bottom schedule padding |
| `OutAboutRadius.cards` | Activity card border radius |
| `OutAboutRadius.sm` | Day header badge radius |
| `OutAboutShadows.card` / `.cardDark` | Card elevation (by theme brightness) |
| `OutAboutAnimations.standardDuration` | Entrance animations |
| `OutAboutHaptics.onConditionMatch()` | Fires once if any day has matches |

## Animations

- Day/activity sections fade-in + slide-up with staggered delay per
  section (`sectionIndex * 80ms`).
- Activity cards within a section have inner stagger (`cardIndex * 60ms`).
- Pull-to-refresh spinner uses default `RefreshIndicator` behavior.
- All animations use `flutter_animate` chains per CLAUDE.md rules.
- Layout switch: no animation between layouts — instant swap.

## Refresh Behavior

```dart
Future<void> _onRefresh() async {
  ref.invalidate(dailyForecastProvider);
  ref.invalidate(weatherDataProvider); // theme refresh
  ref.invalidate(activitiesProvider);
  await ref.read(behavioralEventServiceProvider)
      .log('weather_refreshed', ...);
}
```

On `AppLifecycleState.resumed`: invalidate `dailyForecastProvider` (same
pattern as current `weatherDataProvider` invalidation).

## Temperature Display

- `DailyForecast` stores Celsius (API returns metric).
- Display respects `profileProvider.temperatureUnit`:
  - 'F' => convert with `_celsiusToFahrenheit()` (existing helper).
  - 'C' => display as-is.
- Show as "H: 28 / L: 18" or similar compact format.
- Note: condition matching always uses Celsius internally (matching the
  backend which stores thresholds in Celsius).

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No location | `_LocationPermissionBanner` (existing pattern) |
| Forecast API fails | Fallback to cached forecast; if none, error banner |
| No activities | `_ScheduleEmptyState` with CTA |
| Activities but 0 matches on a day | `_DayEmptyState` text within section |
| Activities but 0 matches on ALL days | All day sections show empty state |
| Activity matches 0 days (activity-first) | `_ActivityEmptyState` text |
| User in flight / timezone change | Forecast dates are UTC; display in local tz |
| Layout switch | Instant — same data, different widget tree |
