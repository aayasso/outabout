# Design -- Weather Icon Refinement
# Created: 2026-05-05
# Requires: requirements.md approved

## Screens & Widgets

### TodayTab
- **Route:** Home tab (no standalone route)
- **Type:** ConsumerStatefulWidget (unchanged)
- **Modified widgets:** `_WeatherSummaryCard` consumes updated return type
- **Colors source:** `ref.watch(weatherThemeColorsProvider)`

## Provider Structure

No new providers.

## Repository Methods

No new repository methods.

## Data Flow

`_weatherIconData(int weatherCode)` is a file-private helper in `today_tab.dart`. It currently returns a record `({IconData icon, Color tint})`. The return type is expanded to include `String name`:

```dart
({IconData icon, Color tint, String name}) _weatherIconData(int weatherCode) {
  return switch (weatherCode) {
    1000 => (icon: Icons.wb_sunny, tint: OutAboutColors.sunny, name: 'Clear'),
    1100 => (icon: Icons.wb_sunny, tint: OutAboutColors.sunny, name: 'Mostly Clear'),
    1101 => (icon: Icons.cloud_outlined, tint: OutAboutColors.cloudy, name: 'Partly Cloudy'),
    1102 => (icon: Icons.cloud_outlined, tint: OutAboutColors.cloudy, name: 'Mostly Cloudy'),
    1001 => (icon: Icons.cloud, tint: OutAboutColors.cloudy, name: 'Cloudy'),
    2000 => (icon: Icons.cloud, tint: OutAboutColors.cloudy, name: 'Fog'),
    2100 => (icon: Icons.cloud, tint: OutAboutColors.cloudy, name: 'Light Fog'),
    4000 => (icon: Icons.water_drop, tint: OutAboutColors.rainy, name: 'Drizzle'),
    4001 => (icon: Icons.water_drop, tint: OutAboutColors.rainy, name: 'Rain'),
    4200 => (icon: Icons.water_drop, tint: OutAboutColors.rainy, name: 'Light Rain'),
    4201 => (icon: Icons.water_drop, tint: OutAboutColors.rainy, name: 'Heavy Rain'),
    5000 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Snow'),
    5001 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Flurries'),
    5100 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Light Snow'),
    5101 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Heavy Snow'),
    6000 => (icon: Icons.water_drop, tint: OutAboutColors.cold, name: 'Freezing Drizzle'),
    6001 => (icon: Icons.water_drop, tint: OutAboutColors.cold, name: 'Freezing Rain'),
    6200 => (icon: Icons.water_drop, tint: OutAboutColors.cold, name: 'Light Freezing Rain'),
    6201 => (icon: Icons.water_drop, tint: OutAboutColors.cold, name: 'Heavy Freezing Rain'),
    7000 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Ice Pellets'),
    7101 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Heavy Ice Pellets'),
    7102 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Light Ice Pellets'),
    8000 => (icon: Icons.thunderstorm, tint: OutAboutColors.rainy, name: 'Thunderstorm'),
    _ => (icon: Icons.wb_sunny, tint: OutAboutColors.sunny, name: 'Clear'),
  };
}
```

### Icon mapping rationale
- **Clear/Mostly Clear (1000, 1100):** `Icons.wb_sunny` + sunny tint
- **Partly/Mostly Cloudy (1101, 1102):** `Icons.cloud_outlined` + cloudy tint
- **Cloudy (1001):** `Icons.cloud` + cloudy tint
- **Fog (2000, 2100):** `Icons.cloud` + cloudy tint (fog as low cloud)
- **Rain/Drizzle (4xxx):** `Icons.water_drop` + rainy tint
- **Snow/Flurries (5xxx):** `Icons.ac_unit` + cold tint
- **Freezing precip (6xxx):** `Icons.water_drop` + cold tint (rain that's freezing)
- **Ice pellets (7xxx):** `Icons.ac_unit` + cold tint
- **Thunderstorm (8000):** `Icons.thunderstorm` + rainy tint

### Callers to update
- `_WeatherSummaryCard.build()` -- already uses `iconData.icon` and `iconData.tint`. The new `.name` field is unused until the today_tab_polish feature adds condition name display.

## Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Unknown weather code (e.g. 0, 9999) | Default case returns clear/sunny |
| Code 0 from fallback WeatherData | Default case returns clear/sunny |

## Haptic Moments
- None

## Open Questions Resolved
- None
