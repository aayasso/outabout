# Tasks -- Today Tab Polish
# Created: 2026-05-05
# Requires: design.md approved
# Depends on: weather_icon_refinement must be completed first

## Task 1 -- Weather summary card enhancements
Visible when done: Weather card shows temperature with F/C suffix, condition name text (e.g. "Clear"), and wind speed with mph/km/h.

- [ ] Confirm weather_icon_refinement is complete (`_weatherIconData` returns `.name`)
- [ ] Add `temperatureUnit` parameter to `_WeatherSummaryCard`
- [ ] Read `profileProvider` in `_TodayTabState.build()` to get `temperatureUnit`
- [ ] Pass `temperatureUnit` to `_WeatherSummaryCard`
- [ ] Add `_celsiusToFahrenheit(double c)` and `_kmhToMph(double kmh)` helpers (file-private, same as activities_tab.dart)
- [ ] Update temperature display: show unit suffix (e.g. "72\u00B0F" or "22\u00B0C")
- [ ] Add condition name text below temperature using `_weatherIconData(weather.weatherCode).name`
- [ ] Add wind speed row with icon and converted value
- [ ] All typography uses `colors` argument
- [ ] All spacing uses `OutAboutSpacing` constants
- [ ] Run `flutter analyze` -- zero warnings

## Task 2 -- Match label update
Visible when done: Matched activity cards show "\u2713 Conditions met" in green.

- [ ] Update `_MatchedActivityCard` label from `'Conditions met'` to `'\u2713 Conditions met'`
- [ ] Verify label uses `OutAboutColors.success` color (already in place)
- [ ] Run `flutter analyze` -- zero warnings

## Task 3 -- No-matches empty state
Visible when done: When activities exist but none match, a "No matches right now" message appears between the weather card and the unmatched activity list.

- [ ] Create `_NoMatchesState` private widget class
  - Icon: `Icons.cloud_outlined`, size 48, color `colors.textSecondary`
  - Heading: "No matches right now" in `OutAboutTypography.headingMedium(colors)`
  - Body: "Your activities don't match current conditions. We'll notify you when they do." in `OutAboutTypography.bodyMedium(colors)` with `colors.textSecondary`
  - Centered, padded with `OutAboutSpacing.lg`
- [ ] Update `_buildContent` logic:
  - `matches.isEmpty` -> `_TodayEmptyState` (unchanged)
  - `matches.isNotEmpty && matched.isEmpty` -> weather card + `_NoMatchesState` + unmatched cards
  - `matches.isNotEmpty && matched.isNotEmpty` -> weather card + matched + unmatched (current)
- [ ] Add fade-in animation on `_NoMatchesState`
- [ ] All colors from `weatherThemeColorsProvider`
- [ ] Run `flutter analyze` -- zero warnings
- [ ] Run `flutter test` -- all pass

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] Temperature displays correctly in both F and C
- [ ] Wind speed displays correctly in both mph and km/h
- [ ] Condition name matches weatherCode accurately
- [ ] "\u2713 Conditions met" label visible on matched cards
- [ ] "No matches right now" state appears when activities exist but none match
- [ ] Existing empty state (zero activities) still works
- [ ] Verified across all 5 weather themes
