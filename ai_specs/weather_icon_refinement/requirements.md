# Requirements -- Weather Icon Refinement
# Created: 2026-05-05
# Status: draft

## Summary
Replace the approximate range-based weather code checks in `_weatherIconData()` in today_tab.dart with exact Tomorrow.io weather code mappings. The current implementation uses broad ranges (e.g. 5000-5999) which could match undefined codes. The new implementation uses a switch expression with every documented Tomorrow.io weather code mapped to a specific icon, condition name, and semantic tint color.

## User Stories

### Primary flow
- As a user, I want the weather icon and condition name to accurately reflect the specific weather condition (e.g. distinguishing "Drizzle" from "Heavy Rain") so that the Today tab gives me precise information.

### Secondary flows
- As a developer, I want each weather code explicitly listed so that unmapped codes are impossible and the mapping is self-documenting.

### Edge cases
- What happens with an unknown/undocumented weather code? Fall back to sunny/clear icon and "Clear" label (same as current default behavior).

## Acceptance Criteria
- [ ] `_weatherIconData()` replaced with exact code mapping covering all 23 Tomorrow.io weather codes:
  - 1000 (Clear), 1100 (Mostly Clear), 1101 (Partly Cloudy), 1102 (Mostly Cloudy), 1001 (Cloudy)
  - 2000 (Fog), 2100 (Light Fog)
  - 4000 (Drizzle), 4001 (Rain), 4200 (Light Rain), 4201 (Heavy Rain)
  - 5000 (Snow), 5001 (Flurries), 5100 (Light Snow), 5101 (Heavy Snow)
  - 6000 (Freezing Drizzle), 6001 (Freezing Rain), 6200 (Light Freezing Rain), 6201 (Heavy Freezing Rain)
  - 7000 (Ice Pellets), 7101 (Heavy Ice Pellets), 7102 (Light Ice Pellets)
  - 8000 (Thunderstorm)
- [ ] Each code maps to: icon (IconData), tint (OutAboutColors semantic color), condition name (String)
- [ ] Icon tints use existing `OutAboutColors` semantic colors: sunny, cloudy, rainy, cold, windy
- [ ] Thunderstorm (8000) uses a distinct icon (e.g. `Icons.thunderstorm` or `Icons.flash_on`)
- [ ] Freezing conditions (6xxx) use `OutAboutColors.cold` tint
- [ ] Ice pellets (7xxx) use `OutAboutColors.cold` tint
- [ ] Unknown codes default to clear/sunny
- [ ] Function return type includes condition name string for use by today_tab_polish feature
- [ ] `flutter analyze` passes with zero warnings
- [ ] `flutter test` passes

## Screens Involved
- TodayTab (`lib/features/home/tabs/today_tab.dart`) -- modified (`_weatherIconData` function)

## Data Requirements
- Supabase tables: none
- New columns needed: none
- Tomorrow.io fields needed: `weatherCode` (already in WeatherData model)
- SharedPreferences keys: none

## Weather Theme Considerations
- Does this feature behave differently across themes? No -- the icon tints use fixed `OutAboutColors` semantic colors which are weather-independent by design. The surrounding card styling still comes from the active weather theme.

## Out of Scope
- Changing the weather theme mapping (WeatherTheme enum assignment from codes) -- that lives in `weather_theme_provider.dart`
- Adding custom weather icons or icon assets (using Material Icons only)
- Changing how the weather summary card is laid out

## Open Questions
- None
