# Schedule View — Requirements

> Spec created: 2026-06-27 | Branch: feature/schedule-view
> Status: DRAFT — awaiting product sign-off before implementation

## Summary

Replace the current today-only first tab with a multi-day forecast-matched
schedule view. For each of the next N forecast days, show that day's weather
summary and which of the user's activities match that day's conditions.
"Today" becomes day 0 of the schedule — it is not a separate view.

## User Stories

1. **As a user** I want to see which upcoming days are good for each of my
   activities so I can plan my week, not just react to today.
2. **As a user** I want to tap an activity on any day to see its detail screen.
3. **As a user** I want to pull-to-refresh the schedule to get updated
   forecasts.
4. **As a user** I still want the app theme to reflect current local weather
   conditions (unchanged behavior).

## Functional Requirements

### FR-1: Multi-day forecast display
- The schedule view shows a vertically scrollable list of forecast days.
- Each day section contains:
  - Day header: weekday name, date, high/low temperature, weather icon,
    condition name (e.g. "Partly Cloudy").
  - Matched activities: cards for activities whose conditions are met for
    that day's forecast. Show green accent / "Conditions met" indicator.
  - Unmatched activities are NOT shown per day (only matched ones appear).
  - Days with zero matching activities still appear with a quiet empty state
    (e.g. "No activities match this day's forecast").
- Day 0 is labeled "Today"; day 1 is "Tomorrow"; subsequent days show the
  weekday name + date (e.g. "Monday, Jul 1").

### FR-2: Subsumes the Today tab
- The existing `TodayTab` widget and its sub-widgets are replaced by the
  schedule view. There is no separate "Today" tab left over.
- The bottom navigation first tab label changes from "Today" to "Schedule"
  (or "Forecast" — TBD at implementation, follow product direction).
- The "Today" weather summary card currently at the top of TodayTab is
  replaced by the day-0 section header in the schedule. Current-conditions
  detail (exact temperature, wind, humidity) can live in the day-0 header
  since that is "today."

### FR-3: Condition matching per forecast day
- Reuse the existing `evaluateMatch()` function from `home_providers.dart`.
- The matcher currently takes `WeatherData` (realtime snapshot). The new
  forecast data model provides daily values (`temperatureMax`,
  `temperatureMin`, `precipitationProbability`, `windSpeedMax`,
  `weatherCode`). A thin adapter is needed to convert a daily forecast day
  into the fields `evaluateMatch` expects:
  - `temperature` = average of `temperatureMax` and `temperatureMin`
    (same formula used in the edge function `conditionsMatch`).
  - `precipitationIntensity` = derive from `precipitationProbability`
    (if probability > 0, treat as non-zero intensity; if 0, treat as 0).
  - `windSpeed` = `windSpeedMax`.
  - `weatherCode`, `humidity`, `uvIndex` passed through directly.
- Run the matcher for every (activity, forecast-day) pair.

### FR-4: Activity tap navigation
- Tapping a matched activity card navigates to the existing activity detail
  screen via `AppRoutes.activityDetail` / `context.go('/activity/$id')`.
- No changes to the detail screen.

### FR-5: Refresh behavior
- Pull-to-refresh invalidates the forecast provider and re-fetches.
- Refresh-on-foreground (existing `AppLifecycleListener` pattern) triggers
  the same invalidation.
- Log `weather_refreshed` behavioral event on refresh (existing pattern).

### FR-6: Weather theme unchanged
- The app's theme still reacts to **current local conditions** (realtime
  endpoint), not the forecast. The schedule view merely displays forecast
  data — it does not drive the theme.
- `weatherThemeColorsProvider` continues to be the source of all colors.

### FR-7: Empty states
- **No activities at all:** Same CTA as current TodayEmptyState —
  "Add your first outdoor activity" with button to add-activity screen.
- **No matches on a given day:** Quiet label within the day section, e.g.
  "No activities match this day's forecast." No CTA needed.
- **Forecast unavailable / error:** Error banner with "Couldn't load
  forecast. Pull to refresh." Same pattern as current `_WeatherErrorBanner`.

## Non-Functional Requirements

- All design-system tokens used (OutAboutSpacing, Typography, Radius,
  Shadows, Animations, Haptics). Nothing hardcoded.
- Accessibility: all interactive elements have tooltip/Semantics, tap
  targets >= 48x48dp, contrast verified across all 5 weather themes.
- Staggered entrance animations per day section using flutter_animate.
- Performance: forecast fetch is a single HTTP call returning all days.
  Matching runs synchronously in the provider — no extra network calls.

## Open Product Decision (requires sign-off)

**How many forecast days to show?**

Tomorrow.io's `/v4/forecast` endpoint with `timesteps=1d` returns **5 days
by default** (free tier). Paid tiers can request up to 14 days. Options:

| Option | Days | Tradeoff |
|--------|------|----------|
| A | 5 | Free-tier safe, covers work week |
| B | 7 | Full week, may require paid tier |
| C | Configurable | User picks in Settings; adds UI complexity |

**This decision is deferred to the product owner. Do not assume a value
during implementation — it will be provided before coding starts.**

## What Happens to Existing Code

| File | Disposition |
|------|-------------|
| `lib/features/home/tabs/today_tab.dart` | **Replaced** by `schedule_tab.dart`. Delete after schedule view is complete and verified. |
| `lib/features/home/home_providers.dart` | **Modified**: keep `evaluateMatch()`, `activitiesProvider`, `userLocationProvider`. Add `dailyForecastProvider` and `scheduleMatchProvider`. Remove `conditionMatchProvider` (today-only). Keep `weatherDataProvider` for theme. |
| `lib/features/home/home_screen.dart` | **Modified**: first tab label changes from "Today" to "Schedule", icon changes. |
| `lib/data/repositories/weather_repository.dart` | **Modified**: add `fetchForecast(lat, lng)` method calling `/v4/forecast?timesteps=1d`. |
| `lib/data/models/weather_data.dart` | **New model added**: `DailyForecast` with `date`, `temperatureMax`, `temperatureMin`, `precipitationProbability`, `windSpeedMax`, `weatherCode`, `uvIndex`. |
| `lib/core/router.dart` | No change — route is still `/home`, tab 0. |

## Stale Specs (do NOT build from these)

The following ai_specs/ were written for the today-only architecture and are
now stale with respect to the first tab:

- `ai_specs/home_screen/` (design.md, requirements.md, tasks.md)
- `ai_specs/today_tab_fab/` (requirements.md, design.md, tasks.md)
- `ai_specs/today_tab_polish/` (requirements.md, design.md, tasks.md)
- `ai_specs/empty_state_polish/` (requirements.md, design.md — TodayTab refs)
- `ai_specs/weather_fetch/` (requirements.md, design.md, tasks.md — TodayTab refs)
- `ai_specs/behavioral_event_audit/` (design.md, tasks.md, requirements.md — TodayTab refs)

These specs remain valid for historical reference but should not guide the
schedule view implementation.
