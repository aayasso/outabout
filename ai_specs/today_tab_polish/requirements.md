# Requirements -- Today Tab Polish
# Created: 2026-05-05
# Status: draft

## Summary
Three targeted improvements to the Today tab to surface more useful weather information and clearer activity match status. The weather summary card gains temperature unit awareness, a condition name label, and wind speed. Matched activities show explicit text instead of just a green indicator. A new "no matches right now" empty state distinguishes between "you have no activities" and "none of your activities match current conditions."

## User Stories

### Primary flow
- As a user, I want to see the temperature in my preferred unit (F or C) so that the reading is immediately meaningful to me.
- As a user, I want to see the current condition name (e.g. "Clear", "Rainy") and wind speed on the weather summary card so I can quickly assess conditions.
- As a user, I want to see a checkmark prefix followed by "Conditions met" in green when my activity matches, so the status is unambiguous.

### Secondary flows
- As a user, when I have activities but none match current conditions, I want to see a distinct "No matches right now" message so I know OutAbout is working but conditions aren't right yet.

### Edge cases
- What happens when profile hasn't loaded yet? Default to Fahrenheit (matches Profile model default).
- What happens when weather data is loading? Shimmer skeleton (existing behavior, unchanged).
- What happens when all activities match? No "no matches" message shown -- just the matched cards.
- What happens when user has zero activities? Existing "Add your first outdoor activity" empty state (unchanged).

## Acceptance Criteria
- [ ] Weather summary card shows temperature with unit suffix matching `profileProvider.temperatureUnit` ('F' shows Fahrenheit, 'C' shows Celsius)
- [ ] Tomorrow.io returns Celsius -- when user prefers F, convert with `(c * 9/5 + 32).round()`
- [ ] Weather summary card shows condition name text (e.g. "Clear", "Partly Cloudy", "Rain") derived from `weatherCode`
- [ ] Weather summary card shows wind speed with unit matching temperature preference (F -> mph, C -> km/h)
- [ ] Condition icon on weather card uses `OutAboutColors` semantic tints (sunny, cloudy, rainy, cold)
- [ ] Matched activity cards show "\u2713 Conditions met" (checkmark prefix) text in `OutAboutColors.success`
- [ ] When activities exist but zero match, show "No matches right now" state with weather card still visible above
- [ ] All colors from `weatherThemeColorsProvider` -- no hardcoded colors
- [ ] All typography passes `colors` argument
- [ ] All spacing uses `OutAboutSpacing` constants
- [ ] `flutter analyze` passes with zero warnings
- [ ] `flutter test` passes

## Screens Involved
- TodayTab (`lib/features/home/tabs/today_tab.dart`) -- modified

## Data Requirements
- Supabase tables: `profiles` (read `temperature_unit` via existing `profileProvider`)
- New columns needed: none
- Tomorrow.io fields needed: `weatherCode`, `temperature`, `windSpeed` (already in WeatherData)
- SharedPreferences keys: none

## Weather Theme Considerations
- Does this feature behave differently across themes? Yes -- all colors come from the active theme via `weatherThemeColorsProvider`. Condition icon tints use fixed `OutAboutColors` semantic colors (weather-independent by design).

## Out of Scope
- Adding humidity, UV index, or other weather fields to the summary card
- Changing the weather summary card layout/size significantly
- Adding a temperature unit toggle (already exists in settings)
- Modifying the matched/unmatched card visual design beyond the label text

## Open Questions
- None
