# Tasks -- Weather Icon Refinement
# Created: 2026-05-05
# Requires: design.md approved

## Task 1 -- Replace weather code mapping
Visible when done: Weather icon on Today tab matches exact Tomorrow.io code. No visual change for common codes (clear, rain, snow) but freezing/ice/thunderstorm codes now get correct icons.

- [ ] Replace `_weatherIconData()` function body in `lib/features/home/tabs/today_tab.dart`
- [ ] Change return type from `({IconData icon, Color tint})` to `({IconData icon, Color tint, String name})`
- [ ] Implement switch expression with all 23 Tomorrow.io codes + default case
- [ ] Update `_WeatherSummaryCard.build()` to destructure the new return type (`.name` can be unused until today_tab_polish)
- [ ] Run `flutter analyze` -- zero warnings
- [ ] Run `flutter test` -- all pass

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] Icon tints use only `OutAboutColors` semantic colors (sunny, cloudy, rainy, cold)
- [ ] No hardcoded colors introduced
- [ ] Default case returns clear/sunny for unknown codes
