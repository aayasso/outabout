# Design -- Today Tab Polish
# Created: 2026-05-05
# Requires: requirements.md approved
# Depends on: weather_icon_refinement (must be completed first)

## Screens & Widgets

### TodayTab
- **Route:** Home tab (no standalone route)
- **Type:** ConsumerStatefulWidget (unchanged)
- **Modified widgets:**
  - `_WeatherSummaryCard` -- add condition name, wind speed, temperature unit awareness
  - `_MatchedActivityCard` -- update label to "\u2713 Conditions met"
  - New `_NoMatchesState` -- shown when activities exist but none match
- **Colors source:** `ref.watch(weatherThemeColorsProvider)`

## Provider Structure

No new providers. Uses existing:
- `profileProvider` (in `home_providers.dart`) -- reads `temperatureUnit` from profiles table
- `weatherDataProvider` -- provides `WeatherData` with `temperature`, `windSpeed`, `weatherCode`
- `conditionMatchProvider` -- provides match results

## Repository Methods

No new repository methods.

## Data Flow

### Temperature unit flow
```
profileProvider -> Profile.temperatureUnit ('F' or 'C')
  -> TodayTab reads profileAsync.valueOrNull?.temperatureUnit ?? 'F'
  -> passes temperatureUnit to _WeatherSummaryCard
  -> Card converts: if 'F', convert Celsius to Fahrenheit; if 'C', display as-is
  -> Wind: if 'F', convert km/h to mph; if 'C', display km/h
```

### Condition name flow
```
WeatherData.weatherCode
  -> _weatherIconData(weatherCode) returns (.icon, .tint, .name)
  -> _WeatherSummaryCard displays .name as condition text
```
**Dependency:** The `.name` field on `_weatherIconData()` return type is added by the weather_icon_refinement feature. That feature must be completed first.

### No-matches state flow
```
conditionMatchProvider -> List<ConditionMatch>
  -> if matches.isNotEmpty but none have isMatch == true
    -> show weather card + _NoMatchesState message
  -> if matches.isEmpty (no activities)
    -> show existing _TodayEmptyState (unchanged)
```

## Widget Changes

### _WeatherSummaryCard -- modified
Add `temperatureUnit` parameter. Existing `weather` parameter provides all needed data.

```dart
// Temperature display
final tempDisplay = temperatureUnit == 'F'
    ? '${_celsiusToFahrenheit(weather.temperature)}\u00B0F'
    : '${weather.temperature.round()}\u00B0C';

// Wind display
final windDisplay = temperatureUnit == 'F'
    ? '${_kmhToMph(weather.windSpeed)} mph'
    : '${weather.windSpeed.round()} km/h';

// Condition name from _weatherIconData
final iconData = _weatherIconData(weather.weatherCode);
// Display iconData.name as text
```

Conversion helpers already exist in `activities_tab.dart`:
- `_celsiusToFahrenheit(double c)` -- duplicate as file-private in today_tab.dart (same pattern)
- `_kmhToMph(double kmh)` -- duplicate as file-private in today_tab.dart (same pattern)

### _MatchedActivityCard -- modified
Change label from `'Conditions met'` to `'\u2713 Conditions met'`.

### _NoMatchesState -- new private widget
Shown when `matches.isNotEmpty` but `matched.isEmpty` (all unmatched). Displays below the weather card. Does not replace the card list -- unmatched cards are still shown below.

```dart
class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState({required this.colors});
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    // Icon + "No matches right now" heading + supportive body text
    // Uses colors.textSecondary for muted appearance
    // Uses OutAboutTypography.headingMedium(colors) and bodyMedium(colors)
  }
}
```

### _buildContent changes
Current logic: if `matches.isEmpty` -> `_TodayEmptyState`. Otherwise show all sorted.

New logic:
```
if matches.isEmpty -> _TodayEmptyState (no activities at all -- unchanged)
else:
  matched = matches.where(isMatch)
  unmatched = matches.where(!isMatch)
  if matched.isEmpty -> show weather card + _NoMatchesState + unmatched cards
  else -> show weather card + matched cards + unmatched cards (current behavior)
```

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Profile not loaded yet | Default to 'F' (Fahrenheit) |
| All activities match | Normal matched card list, no "no matches" message |
| No activities at all | Existing `_TodayEmptyState` unchanged |
| Activities exist, none match | Weather card + `_NoMatchesState` + unmatched cards below |
| Weather data loading | Shimmer (unchanged) |
| Weather data error | Error banner (unchanged) |

## Haptic Moments
- None new. Existing `OutAboutHaptics.onConditionMatch()` on first match remains unchanged.

## Open Questions Resolved
- Checkmark format: "\u2713 Conditions met" with checkmark character prefix
- Dependency: weather_icon_refinement must be completed first for condition name string
