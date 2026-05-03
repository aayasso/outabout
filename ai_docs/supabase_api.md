# OutAbout — Supabase & API Reference
# ai_docs/supabase_api.md
# Living document. Update when schema or endpoints change.
# Last updated: 2026-04-28

## Supabase

- **URL:** `dotenv.env['SUPABASE_URL']!`
- **Anon key:** `dotenv.env['SUPABASE_ANON_KEY']!`
- **Client provider:** `supabaseClientProvider` in `lib/core/providers.dart`
- **Auth:** Email/password + (future) social OAuth

Never call Supabase from a widget. Always via repository → provider.

---

## Repository Pattern

```dart
// Standard repository
class ActivityRepository {
  ActivityRepository(this._client);
  final SupabaseClient _client;

  Future<List<Activity>> fetchForUser(String userId) async {
    final data = await _client
        .from('activities')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return data.map(Activity.fromJson).toList();
  }

  Future<Activity> insert(Activity activity) async {
    final data = await _client
        .from('activities')
        .insert(activity.toJson())
        .select()
        .single();
    return Activity.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _client.from('activities').delete().eq('id', id);
  }
}

// Provider for the repository
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(supabaseClientProvider));
});
```

---

## Tables & Columns

### activities
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | auto-generated |
| `user_id` | uuid FK | → auth.users.id, CASCADE DELETE |
| `name` | text | activity name |
| `description` | text nullable | |
| `icon` | text nullable | icon identifier string |
| `is_active` | bool | default true |
| `created_at` | timestamptz | auto-set |
| `updated_at` | timestamptz | auto-set |

### activity_conditions
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | auto-generated |
| `activity_id` | uuid FK | → activities.id, CASCADE DELETE |
| `condition_type` | text | 'temp_min','temp_max','wind_max','no_rain', etc. |
| `condition_value` | float nullable | threshold value |
| `created_at` | timestamptz | auto-set |

### reminders
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | auto-generated |
| `user_id` | uuid FK | → auth.users.id |
| `activity_id` | uuid FK | → activities.id |
| `triggered_at` | timestamptz | when reminder fired |
| `weather_snapshot` | jsonb | Tomorrow.io response at trigger time |
| `active_theme` | text | WeatherTheme.name at trigger time |
| `was_dismissed` | bool | default false |

### user_profiles
| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | = auth.users.id |
| `display_name` | text nullable | |
| `location_lat` | float nullable | |
| `location_lng` | float nullable | |
| `location_name` | text nullable | geocoded place name |
| `notifications_enabled` | bool | default false |
| `onboarding_completed_at` | timestamptz nullable | |
| `created_at` | timestamptz | auto-set |

---

## Auth Patterns

```dart
// Sign up
await _client.auth.signUp(email: email, password: password);

// Sign in
await _client.auth.signInWithPassword(email: email, password: password);

// Sign out
await _client.auth.signOut();

// Current user (null = unauthenticated)
final user = _client.auth.currentUser;
final userId = _client.auth.currentUser?.id;

// Auth state stream
_client.auth.onAuthStateChange // Stream<AuthState>
```

---

## Tomorrow.io API

API key: `dotenv.env['TOMORROW_API_KEY']!`
Base URL: `https://api.tomorrow.io/v4`
HTTP package: `http` (add to pubspec when implementing)

### Current conditions endpoint
```
GET https://api.tomorrow.io/v4/weather/realtime
  ?location={lat},{lng}
  &fields=weatherCode,temperature,windSpeed,humidity,precipitationIntensity,uvIndex
  &apikey={TOMORROW_API_KEY}
```

### Response (relevant fields)
```json
{
  "data": {
    "values": {
      "weatherCode": 1000,
      "temperature": 22.5,
      "windSpeed": 12.3,
      "humidity": 45,
      "precipitationIntensity": 0,
      "uvIndex": 6
    }
  }
}
```

### Weather code → WeatherTheme mapping
```dart
// In WeatherThemeNotifier.setThemeFromConditions(int code)
5000–5999 → WeatherTheme.snowy
4000–4999 → WeatherTheme.rainy
2000–2999 → WeatherTheme.rainy   // fog maps to rainy mood
1100–1999 → WeatherTheme.overcast
1001      → WeatherTheme.overcast
default   → WeatherTheme.sunny
```

### Fetch trigger points
- App comes to foreground
- User location changes significantly
- User manually refreshes
- Timer: every 30 minutes while app is active

### Repository pattern for weather
```dart
class WeatherRepository {
  WeatherRepository(this._apiKey);
  final String _apiKey;
  final _client = http.Client();

  Future<WeatherData> fetchCurrent(double lat, double lng) async {
    final uri = Uri.parse(
      'https://api.tomorrow.io/v4/weather/realtime'
      '?location=$lat,$lng'
      '&fields=weatherCode,temperature,windSpeed,humidity,uvIndex'
      '&apikey=$_apiKey',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw WeatherFetchException(response.statusCode);
    }
    return WeatherData.fromJson(jsonDecode(response.body));
  }
}
```

---

## Location Pattern

```dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Check + request permission
Future<bool> requestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  return permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;
}

// Get current position
final position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.medium,
);

// Reverse geocode to place name
final placemarks = await placemarkFromCoordinates(
  position.latitude,
  position.longitude,
);
final place = placemarks.first;
final locationName = '${place.locality}, ${place.administrativeArea}';
```

---

## Common Query Patterns

```dart
// Fetch with related records
final data = await _client
    .from('activities')
    .select('*, activity_conditions(*)')
    .eq('user_id', userId)
    .order('created_at', ascending: false);

// Upsert
await _client.from('user_profiles').upsert(profile.toJson());

// Update specific field
await _client
    .from('user_profiles')
    .update({'notifications_enabled': true})
    .eq('id', userId);

// Realtime subscription
_client
    .from('reminders')
    .stream(primaryKey: ['id'])
    .eq('user_id', userId)
    .listen((data) { /* handle */ });
```
