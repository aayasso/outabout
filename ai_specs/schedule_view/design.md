# Schedule View — Design

> Spec created: 2026-06-27 | Branch: feature/schedule-view
> Status: DRAFT — awaiting product sign-off before implementation

## Architecture Overview

```
Tomorrow.io /v4/forecast (1d)     Tomorrow.io /v4/weather/realtime
        |                                    |
  WeatherRepository                   WeatherRepository
  .fetchForecast()                    .fetchCurrent()
        |                                    |
  dailyForecastProvider              weatherDataProvider
        |                                    |
        +------- scheduleMatchProvider       +--- weatherThemeProvider
                        |                        (theme still driven by
                  ScheduleTab                     current conditions)
```

### Data flow

1. `userLocationProvider` resolves user lat/lng (existing, unchanged).
2. `dailyForecastProvider` (NEW) calls `WeatherRepository.fetchForecast()`
   which hits `https://api.tomorrow.io/v4/forecast?timesteps=1d&fields=...`.
   Returns `List<DailyForecast>`.
3. `activitiesProvider` fetches user activities (existing, unchanged).
4. `scheduleMatchProvider` (NEW) combines daily forecasts + activities.
   For each forecast day, runs `evaluateMatch()` against every activity
   using an adapted `WeatherData` built from the daily forecast values.
   Returns `List<ScheduleDay>`.
5. `ScheduleTab` watches `scheduleMatchProvider` and renders.
6. `weatherDataProvider` + `weatherThemeProvider` remain unchanged and
   continue driving the app theme from realtime conditions.

## New Data Models

### DailyForecast

```dart
class DailyForecast {
  final DateTime date;
  final double temperatureMax;   // Celsius
  final double temperatureMin;   // Celsius
  final double precipitationProbability; // 0-100
  final double windSpeedMax;     // km/h
  final int weatherCode;         // Tomorrow.io code
  final double uvIndex;

  const DailyForecast({ ... });

  factory DailyForecast.fromJson(Map<String, dynamic> json);

  /// Convert to WeatherData for evaluateMatch() compatibility.
  WeatherData toWeatherData() => WeatherData(
    weatherCode: weatherCode,
    temperature: (temperatureMax + temperatureMin) / 2,
    windSpeed: windSpeedMax,
    humidity: 0,  // not available in daily; unused by matcher
    precipitationIntensity:
        precipitationProbability > 0 ? 1.0 : 0.0,
    uvIndex: uvIndex,
  );
}
```

JSON shape from Tomorrow.io daily timeline:
```json
{
  "time": "2026-06-27T06:00:00Z",
  "values": {
    "temperatureMax": 28.5,
    "temperatureMin": 18.2,
    "precipitationProbability": 10,
    "windSpeedMax": 22.0,
    "weatherCode": 1100,
    "uvIndex": 7
  }
}
```

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

## New / Modified Providers

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
          final weather = day.toWeatherData();
          final matched = activities
              .where((a) => evaluateMatch(
                    a.conditionProfile,
                    weather,
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
    'weatherCode,uvIndex'
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

Uses the same endpoint and fields as the edge function
(`supabase/functions/check-weather/index.ts` line 14).

### WeatherRepository.fetchCurrent() — UNCHANGED

Still needed for theme provider. No modifications.

## Widget Structure

### ScheduleTab (replaces TodayTab)

```
ScheduleTab (ConsumerStatefulWidget)
  Scaffold(backgroundColor: colors.background)
    RefreshIndicator
      CustomScrollView
        SliverToBoxAdapter: _ScheduleHeader (greeting + location)
        SliverToBoxAdapter: _LocationPermissionBanner (if needed)
        SliverList: for each ScheduleDay =>
          _DaySection
            _DayHeader (date, weather icon, high/low temp)
            if matchedActivities.isNotEmpty:
              for each activity => _ScheduleActivityCard
            else:
              _DayEmptyState ("No activities match")
        SliverToBoxAdapter: _ScheduleFooter (forecast attribution)
```

### If no activities at all => _ScheduleEmptyState (CTA to add activity)

### _DayHeader

Displays per-day weather summary:
- Left: weather icon (mapped from weatherCode, reuse `_weatherIconData()`)
- Center: day label ("Today", "Tomorrow", "Monday, Jul 1")
- Right: high/low temperature (respects user's F/C preference)
- Subtitle: condition name (e.g. "Partly Cloudy")

Uses `OutAboutTypography.headingMedium(colors)` for day name,
`OutAboutTypography.bodyMedium(colors)` for temperatures.

### _ScheduleActivityCard

Similar to current `_MatchedActivityCard` but without the "Conditions met"
label (every card in the schedule is matched by definition).
- Activity name, category icon, condition summary.
- Green left border accent (same `OutAboutColors.success` treatment).
- Tap navigates to activity detail.
- Staggered entrance animation.

### _DayEmptyState

Quiet inline state within the day section:
- `OutAboutTypography.bodySmall(colors)` text
- No CTA, no icon — just a single line of text
- Example: "No activities match this day's forecast"

## Design System Usage

| Token | Usage |
|-------|-------|
| `weatherThemeColorsProvider` | ALL colors — background, text, card, surface |
| `OutAboutTypography.*` | ALL text styles, always with `(colors)` param |
| `OutAboutSpacing.md` | Padding between day sections |
| `OutAboutSpacing.sm` | Padding within day headers |
| `OutAboutSpacing.lg` | Top/bottom schedule padding |
| `OutAboutRadius.cards` | Activity card border radius |
| `OutAboutRadius.sm` | Day header badge radius |
| `OutAboutShadows.card` / `.cardDark` | Card elevation (by theme brightness) |
| `OutAboutAnimations.standardDuration` | Entrance animations |
| `OutAboutHaptics.onConditionMatch()` | Fires once if any day has matches |

## Animations

- Day sections fade-in + slide-up with staggered delay per section
  (`sectionIndex * 80ms`).
- Activity cards within a section have inner stagger (`cardIndex * 60ms`).
- Pull-to-refresh spinner uses default `RefreshIndicator` behavior.
- All animations use `flutter_animate` chains per CLAUDE.md rules.

## Refresh Behavior

```dart
Future<void> _onRefresh() async {
  ref.invalidate(dailyForecastProvider);
  ref.invalidate(weatherDataProvider); // theme refresh
  ref.invalidate(activitiesProvider);
  // Log behavioral event
  await ref.read(behavioralEventServiceProvider)
      .logEvent('weather_refreshed', ...);
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

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No location | `_LocationPermissionBanner` (existing pattern) |
| Forecast API fails | Fallback to cached forecast; if none, error banner |
| No activities | `_ScheduleEmptyState` with CTA |
| Activities but 0 matches on a day | `_DayEmptyState` text within section |
| Activities but 0 matches on ALL days | All day sections show empty state |
| User in flight / timezone change | Forecast dates are UTC; display in local tz |
