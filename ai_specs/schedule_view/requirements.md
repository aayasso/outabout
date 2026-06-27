# Schedule View — Requirements

> Spec created: 2026-06-27 | Revised: 2026-06-27
> Branch: feature/schedule-view
> Status: READY FOR IMPLEMENTATION

## Summary

Replace the current today-only first tab with a 5-day forecast-matched
schedule view. For each of the next 5 days (today + next 4), show that day's
actual weather values and which of the user's activities match that day's
conditions. "Today" becomes day 0 of the schedule — it is not a separate view.

Two switchable layouts display the SAME matched data — no refetch or
recompute on switch:

- **Day-first** (default): list the 5 days; each day shows its matching
  activities. Days with no matches still appear with a quiet empty state.
- **Activity-first** (toggle): list the user's activities; each shows
  which of the 5 days it matches. Activities matching no day still appear,
  with a quiet "no matching days" state.

The layout preference is a new Settings value, persisted to
SharedPreferences using the same pattern as the theme-override preference.

## User Stories

1. **As a user** I want to see which upcoming days are good for each of my
   activities so I can plan my week, not just react to today.
2. **As a user** I want to switch between a day-focused and an
   activity-focused view of the same data, from Settings.
3. **As a user** I want to tap an activity on any day to see its detail
   screen.
4. **As a user** I want to pull-to-refresh the schedule to get updated
   forecasts.
5. **As a user** I still want the app theme to reflect current local
   weather conditions (unchanged behavior).

## Locked Decisions

| Decision | Value | Rationale |
|----------|-------|-----------|
| Forecast days | 5 (today + next 4), rolling | Free Tomorrow.io tier returns 5 days |
| Default layout | Day-first | Most natural for planning |
| Layout toggle location | Settings tab | Consistent with other prefs |
| Layout persistence | SharedPreferences | Follows theme-override pattern |

## Functional Requirements

### FR-1: 5-day forecast display

- The schedule view shows a vertically scrollable view covering exactly
  5 days: today + next 4. Each fetch returns the current 5-day window.
- Each day displays its ACTUAL forecast values from Tomorrow.io:
  - `temperatureMax` and `temperatureMin` (displayed as high/low)
  - `precipitationProbability`
  - `windSpeedMax`
  - `weatherCode` (mapped to weather icon and condition name)
- Day 0 is labeled "Today"; day 1 is "Tomorrow"; subsequent days show
  the weekday name + date (e.g. "Monday, Jul 1").
- The app DISPLAYS these values — it does not average, derive, or
  transform them.

### FR-2: Day-first layout (default)

- A vertically scrollable list of 5 day sections.
- Each day section contains:
  - Day header: weekday name, date, high/low temperature, weather icon,
    condition name (e.g. "Partly Cloudy"), precipitation probability,
    wind speed.
  - Matched activities: cards for activities whose conditions are met for
    that day's forecast.
  - Days with zero matching activities show a quiet empty state
    (e.g. "No activities match this day's forecast").

### FR-3: Activity-first layout (toggle from Settings)

- A vertically scrollable list of the user's activities.
- Each activity section contains:
  - Activity header: name, category icon, condition summary.
  - Matching days: compact day badges/cards for the days where this
    activity's conditions are met.
  - Activities matching zero days show a quiet empty state
    (e.g. "No matching days this week").
- Switching layouts reads from the SAME `scheduleMatchProvider` data.
  No refetch, no recompute.

### FR-4: Layout preference in Settings

- New "Schedule layout" row in Settings tab (below temperature unit).
- Two options: "Day-first" and "Activity-first".
- Persisted to SharedPreferences under key `'schedule_layout'`.
- Uses a `StateNotifierProvider` following the exact pattern of
  `userThemeOverrideProvider` in `weather_theme_provider.dart`:
  - `ScheduleLayoutNotifier` extends `StateNotifier<ScheduleLayout>`
  - Reads initial value from SharedPreferences
  - `setLayout(ScheduleLayout layout)` persists and updates state
- `ScheduleLayout` enum: `dayFirst`, `activityFirst`.

### FR-5: Subsumes the Today tab

- The existing `TodayTab` widget and its sub-widgets are replaced by the
  schedule view. There is no separate "Today" tab left over.
- The bottom navigation first tab label changes from "Today" to
  "Schedule".
- The current-conditions weather summary that was at the top of TodayTab
  is replaced by the day-0 section header in the schedule.

### FR-6: Condition matching per forecast day

The schedule view's per-day matching MUST replicate the backend
`conditionsMatch` logic in `supabase/functions/check-weather/index.ts`
(lines 21-41) so that the app and backend never disagree.

#### Backend conditionsMatch (authoritative reference)

```typescript
function conditionsMatch(forecast: any, profile: any): boolean {
  const day = forecast.values;
  if (profile.temp_enabled) {
    const avgTemp = (day.temperatureMax + day.temperatureMin) / 2;
    if (profile.temp_min !== null && avgTemp < profile.temp_min) return false;
    if (profile.temp_max !== null && avgTemp > profile.temp_max) return false;
  }
  if (profile.precip_enabled) {
    const precip = day.precipitationProbability;
    if (profile.precip_level === "none" && precip > 20) return false;
    if (profile.precip_level === "light_ok" && precip > 60) return false;
  }
  if (profile.wind_enabled) {
    if (profile.wind_max !== null && day.windSpeedMax > profile.wind_max)
      return false;
  }
  return true;
}
```

#### Current frontend evaluateMatch (today-only, uses WeatherData)

```dart
bool evaluateMatch(ConditionProfile? profile, WeatherData weather) {
  if (profile == null) return true;
  if (profile.tempEnabled) {
    if (profile.tempMin != null && weather.temperature < profile.tempMin!)
      return false;
    if (profile.tempMax != null && weather.temperature > profile.tempMax!)
      return false;
  }
  if (profile.precipEnabled) {
    if (profile.precipLevel == 'none' && weather.precipitationIntensity > 0)
      return false;
  }
  if (profile.windEnabled) {
    if (profile.windMax != null && weather.windSpeed > profile.windMax!)
      return false;
  }
  return true;
}
```

#### Discrepancies between frontend and backend

| Condition | Backend | Frontend (current) |
|-----------|---------|-------------------|
| Temperature | avg of max/min vs thresholds | single realtime temp vs thresholds |
| Precip "none" | precipitationProbability > 20 fails | precipitationIntensity > 0 fails |
| Precip "light_ok" | precipitationProbability > 60 fails | NOT IMPLEMENTED |
| Wind | windSpeedMax vs wind_max | windSpeed vs windMax |

#### Resolution: new day-level matcher

A new `evaluateDayMatch()` function MUST be added that mirrors the
backend `conditionsMatch` exactly, operating on `DailyForecast` fields
directly — NOT via a `toWeatherData()` adapter.

```dart
bool evaluateDayMatch(ConditionProfile? profile, DailyForecast day) {
  if (profile == null) return true;

  if (profile.tempEnabled) {
    final avgTemp = (day.temperatureMax + day.temperatureMin) / 2;
    if (profile.tempMin != null && avgTemp < profile.tempMin!) return false;
    if (profile.tempMax != null && avgTemp > profile.tempMax!) return false;
  }

  if (profile.precipEnabled) {
    final precip = day.precipitationProbability;
    if (profile.precipLevel == 'none' && precip > 20) return false;
    if (profile.precipLevel == 'light_ok' && precip > 60) return false;
  }

  if (profile.windEnabled) {
    if (profile.windMax != null && day.windSpeedMax > profile.windMax!)
      return false;
  }

  return true;
}
```

The existing `evaluateMatch()` remains for the realtime today-only path
(theme provider). `evaluateDayMatch()` is used by `scheduleMatchProvider`.

There is NO `toWeatherData()` adapter on `DailyForecast`. The daily
forecast values are compared directly.

### FR-7: Activity tap navigation

- Tapping a matched activity card navigates to the existing activity
  detail screen via `AppRoutes.activity` /
  `context.go('/activity/$id')`.
- No changes to the detail screen.

### FR-8: Refresh behavior

- Pull-to-refresh invalidates the forecast provider and re-fetches.
- Refresh-on-foreground (existing `AppLifecycleListener` pattern)
  triggers the same invalidation.
- Log `weather_refreshed` behavioral event on refresh (existing pattern).

### FR-9: Weather theme unchanged

- The app's theme still reacts to current local conditions (realtime
  endpoint), not the forecast. The schedule view merely displays forecast
  data — it does not drive the theme.
- `weatherThemeColorsProvider` continues to be the source of all colors.

### FR-10: Empty states

- **No activities at all:** Same CTA as current TodayEmptyState —
  "Add your first outdoor activity" with button to add-activity screen.
- **No matches on a given day (day-first):** Quiet label within the day
  section: "No activities match this day's forecast."
- **No matching days for an activity (activity-first):** Quiet label:
  "No matching days this week."
- **Forecast unavailable / error:** Error banner with "Couldn't load
  forecast. Pull to refresh." Same pattern as current
  `_WeatherErrorBanner`.

## Non-Functional Requirements

- All design-system tokens used (OutAboutSpacing, Typography, Radius,
  Shadows, Animations, Haptics). Nothing hardcoded.
- Accessibility: all interactive elements have tooltip/Semantics, tap
  targets >= 48x48dp, contrast verified across all 5 weather themes.
- Staggered entrance animations per section using flutter_animate.
- Performance: forecast fetch is a single HTTP call returning all 5 days.
  Matching runs synchronously in the provider — no extra network calls.
- Layout switch is instant (same data, different widget tree).

## Out of Scope

- Notification logic of any kind (no reminders, no scheduled or
  per-activity notifications). This spec covers the screen + layout
  toggle only.
- Anything that writes or transforms forecast data.
- Any changes to the backend edge function.

## What Happens to Existing Code

| File | Disposition |
|------|-------------|
| `lib/features/home/tabs/today_tab.dart` | **Replaced** by `schedule_tab.dart`. Delete after schedule view is complete and verified. |
| `lib/features/home/home_providers.dart` | **Modified**: keep `evaluateMatch()`, `activitiesProvider`, `userLocationProvider`, `weatherDataProvider`. Add `dailyForecastProvider`, `scheduleMatchProvider`, `evaluateDayMatch()`, `scheduleLayoutProvider`. Remove `conditionMatchProvider`. |
| `lib/features/home/home_screen.dart` | **Modified**: first tab label changes from "Today" to "Schedule", icon changes. |
| `lib/data/repositories/weather_repository.dart` | **Modified**: add `fetchForecast(lat, lng)` method calling `/v4/forecast?timesteps=1d`. |
| `lib/data/models/daily_forecast.dart` | **New**: `DailyForecast` with `date`, `temperatureMax`, `temperatureMin`, `precipitationProbability`, `windSpeedMax`, `weatherCode`. No `toWeatherData()` adapter. |
| `lib/data/models/schedule_day.dart` | **New**: `ScheduleDay` with `forecast` and `matchedActivities`. |
| `lib/features/home/tabs/settings_tab.dart` | **Modified**: add "Schedule layout" row. |
| `lib/core/router.dart` | No change — route is still `/home`, tab 0. |

## Stale Specs (do NOT build from these)

The following ai_specs/ were written for the today-only architecture and
are now stale with respect to the first tab:

- `ai_specs/home_screen/` (design.md, requirements.md, tasks.md)
- `ai_specs/today_tab_fab/` (requirements.md, design.md, tasks.md)
- `ai_specs/today_tab_polish/` (requirements.md, design.md, tasks.md)
- `ai_specs/empty_state_polish/` (requirements.md, design.md)
- `ai_specs/weather_fetch/` (requirements.md, design.md, tasks.md)
- `ai_specs/behavioral_event_audit/` (design.md, tasks.md, requirements.md)
