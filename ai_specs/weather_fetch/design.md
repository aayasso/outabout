# Design — Weather Fetch
# Created: 2026-05-04
# Requires: requirements.md approved

## 1. Screens & Widgets

No new screens. Modifications only:

### main.dart
- Add `AppLifecycleListener` in `_MyAppState` (already ConsumerStatefulWidget)
- On `resume`: invalidate `weatherDataProvider`

### TodayTab `_WeatherSummaryCard`
- Add optional `fetchedAt` display
- Show "Updated X min ago" when data is older than 30 minutes

---

## 2. Provider Structure

### Modified providers

```
weatherDataProvider           FutureProvider<WeatherData>  (modified)
  |-- On success: cache result + timestamp to SharedPreferences
  |-- On failure: attempt to load from cache
  '-- Returns WeatherData with fetchedAt field

cachedWeatherProvider         Provider<(WeatherData?, DateTime?)>
  |-- reads: sharedPreferencesProvider
  '-- returns cached weather + fetchedAt from SharedPreferences
```

### WeatherData model change
Add `fetchedAt` field to `WeatherData` (optional, null for fresh data
from API -- set explicitly when loading from cache):

```dart
class WeatherData {
  // ... existing fields ...
  final DateTime? fetchedAt; // null = fresh, non-null = cached timestamp
}
```

---

## 3. Data Flow

### App foreground flow
```
AppLifecycleListener.onResume
  |
  '-- ref.invalidate(weatherDataProvider)
       |
       '-- weatherDataProvider re-executes:
            |-- Get location from userLocationProvider
            |-- Call WeatherRepository.fetchCurrent(lat, lng)
            |
            |-- SUCCESS:
            |    |-- Cache to SharedPreferences (JSON + timestamp)
            |    |-- setThemeFromConditions(weatherCode)
            |    |-- setThemeFromTimeOfDay(now)
            |    '-- Return WeatherData(fetchedAt: null) -- fresh
            |
            '-- FAILURE:
                 |-- Read cached data from SharedPreferences
                 |-- If cache exists: return WeatherData(fetchedAt: cachedTime)
                 '-- If no cache: rethrow exception
```

### Staleness display
```
_WeatherSummaryCard receives WeatherData
  |-- If fetchedAt == null -> fresh data, no indicator
  |-- If fetchedAt != null:
       |-- Duration since = now - fetchedAt
       |-- If > 30 min: show "Updated X min ago" in bodySmall
       '-- If <= 30 min: no indicator (still reasonably fresh)
```

---

## 4. Cache Format (SharedPreferences)

```dart
// Write cache
prefs.setString('cached_weather_data', jsonEncode({
  'weatherCode': data.weatherCode,
  'temperature': data.temperature,
  'windSpeed': data.windSpeed,
  'humidity': data.humidity,
  'precipitationIntensity': data.precipitationIntensity,
  'uvIndex': data.uvIndex,
}));
prefs.setString('cached_weather_fetched_at', DateTime.now().toIso8601String());

// Read cache
final jsonStr = prefs.getString('cached_weather_data');
final fetchedAtStr = prefs.getString('cached_weather_fetched_at');
if (jsonStr != null && fetchedAtStr != null) {
  final values = jsonDecode(jsonStr) as Map<String, dynamic>;
  return WeatherData(
    weatherCode: values['weatherCode'],
    temperature: (values['temperature'] as num).toDouble(),
    // ... etc
    fetchedAt: DateTime.parse(fetchedAtStr),
  );
}
```

---

## 5. Edge Cases & Error States

| Scenario | Behavior |
|---|---|
| Fresh fetch succeeds | Cache updated, no staleness indicator |
| Fresh fetch fails + cache exists | Cached data shown + "Updated X min ago" |
| Fresh fetch fails + no cache | Error banner on TodayTab (existing behavior) |
| Location null | No fetch attempted (existing behavior) |
| Theme override active | Fetch still runs (for condition matching), theme not changed |
| App backgrounded < 1 minute then resumed | Re-fetches (simple, no debounce) |

---

## 6. Haptic Moments

No new haptic moments for this feature.
