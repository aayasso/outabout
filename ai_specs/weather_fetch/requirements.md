# Requirements — Weather Fetch
# Created: 2026-05-04
# Status: draft

## Summary
Wire the Tomorrow.io weather fetch into the app lifecycle. On app foreground,
automatically fetch current weather for the user's location and update the
weather theme. Cache the last successful result so the app shows stale data
rather than a blank screen when offline. Display a staleness indicator if
data is older than 30 minutes. Pull-to-refresh on TodayTab is already wired
and continues to work.

## User Stories

### Primary flow
- As a user, I want the weather to refresh automatically when I open the app
  so I always see current conditions without manual action.
- As a user, I want the app theme to change based on current weather so I
  feel the weather at a glance.

### Secondary flows
- As a user, I want to see the last known weather when I'm offline so the
  app isn't blank.
- As a user, I want to know when weather data is stale so I understand the
  information may not be current.

### Edge cases
- What happens when the app returns to foreground but location permission
  was revoked?
  -> Skip weather fetch. Show location permission banner on TodayTab.
  Theme remains at last known state.
- What happens when Tomorrow.io returns an error?
  -> Keep cached data if available. Show staleness indicator if cache is
  older than 30 minutes. Show error banner if no cache exists.
- What happens when the device has no internet?
  -> Same as API error -- fall back to cached data + staleness indicator.
- What happens when the user has a theme override set?
  -> Weather still fetches (for condition matching) but theme doesn't change.
  `setThemeFromConditions` and `setThemeFromTimeOfDay` are no-ops when
  override is active (already handled by WeatherThemeNotifier).

## Acceptance Criteria
- [ ] Weather fetches automatically on app foreground via
      `AppLifecycleListener`
- [ ] `weatherDataProvider` is invalidated on resume, triggering a new fetch
- [ ] Last successful `WeatherData` is cached to SharedPreferences as JSON
- [ ] On fetch failure, cached data is returned with a `fetchedAt` timestamp
- [ ] Staleness indicator shown on `_WeatherSummaryCard` when data is
      older than 30 minutes (e.g. "Updated 45 min ago")
- [ ] `weatherThemeProvider.setThemeFromConditions()` called on every
      successful fetch (already in `weatherDataProvider`)
- [ ] `weatherThemeProvider.setThemeFromTimeOfDay()` called on every
      successful fetch (already in `weatherDataProvider`)
- [ ] TOMORROW_API_KEY read from dotenv -- never hardcoded
- [ ] No fetch attempted when location is null
- [ ] Pull-to-refresh on TodayTab continues to work (already wired)

## Screens Involved
- No new screens. Modifications to:
  - `lib/main.dart` -- add `AppLifecycleListener`
  - `lib/features/home/tabs/today_tab.dart` -- staleness indicator on
    weather card
  - `lib/features/home/home_providers.dart` -- caching logic in
    `weatherDataProvider`

## Data Requirements
- Supabase tables: none (weather is from Tomorrow.io)
- Tomorrow.io fields: `weatherCode`, `temperature`, `windSpeed`, `humidity`,
  `precipitationIntensity`, `uvIndex`
- SharedPreferences keys:
  - `cached_weather_data` -- JSON string of last successful WeatherData
  - `cached_weather_fetched_at` -- ISO 8601 timestamp of last fetch

## Weather Theme Considerations
- This feature IS the weather theme driver. Successful fetch triggers
  theme updates. The theme system is already built -- this feature wires
  the trigger into the app lifecycle.

## Out of Scope
- Background fetch / scheduled periodic fetch while app is backgrounded
- Weather forecast (multi-day) -- this is current conditions only
- Push notification triggers (that's the edge function's job)
- Location change detection (future enhancement)

## Open Questions
- None -- all decisions made.
