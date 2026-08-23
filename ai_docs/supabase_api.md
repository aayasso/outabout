# OutAbout — Supabase & API Reference
# ai_docs/supabase_api.md
# Living document. Update when schema or endpoints change.
# Last updated: 2026-05-03

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
        .eq('is_archived', false)
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

## Tables & Columns — App (Flutter read/write)

### activities
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `uuid_generate_v4()` | |
| `user_id` | uuid FK | NO | — | → profiles.id |
| `name` | text | NO | — | activity name |
| `notes` | text | YES | — | user notes |
| `url` | text | YES | — | related link |
| `location` | text | YES | — | freeform location text |
| `category_ids` | uuid[] | YES | `'{}'` | array of category UUIDs |
| `is_archived` | boolean | YES | `false` | soft delete |
| `created_at` | timestamptz | YES | `now()` | |
| `updated_at` | timestamptz | YES | `now()` | |
| `geographic_context` | jsonb | NO | `'{}'` | location context for intelligence |

> **Cleanup note:** The existing `lib/models/activity.dart` (in the onboarding
> worktree) still contains a legacy `category` (text) field. This needs to be
> removed and replaced with `category_ids` (uuid[]) to match the live schema.

### condition_profiles
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `uuid_generate_v4()` | |
| `activity_id` | uuid FK | NO | — | → activities.id |
| `temp_enabled` | boolean | YES | `false` | |
| `temp_min` | numeric | YES | — | |
| `temp_max` | numeric | YES | — | |
| `precip_enabled` | boolean | YES | `false` | |
| `precip_level` | text | YES | — | `'avoid_rain'` or `'rain_only'` (CHECK constrained) |
| `wind_enabled` | boolean | YES | `false` | |
| `wind_max` | numeric | YES | — | max wind speed |
| `uv_enabled` | boolean | YES | `false` | |
| `uv_min` | numeric | YES | — | |
| `uv_max` | numeric | YES | — | |
| `created_at` | timestamptz | YES | `now()` | |
| `updated_at` | timestamptz | YES | `now()` | |

### activity_day_outcomes
One row per activity per local calendar day. The user's own outcome history —
readable by its owner, unlike `behavioral_events`, and **hard deleted** with
the account rather than de-identified. Added in `20260825000000`.

| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `gen_random_uuid()` | |
| `user_id` | uuid FK | NO | — | → `auth.users.id`, **ON DELETE CASCADE** |
| `activity_id` | uuid FK | NO | — | → `activities.id`, **ON DELETE CASCADE** |
| `local_date` | date | NO | — | the *device's* local calendar day; the client is its sole author |
| `matched` | boolean | NO | `true` | the app claimed this day's weather suited the activity |
| `outcome` | text | YES | — | `'done'` \| `'skipped'`; null = unanswered |
| `reason` | text | YES | — | optional "why not" chip |
| `answered_at` | timestamptz | YES | — | CHECK: null exactly when `outcome` is null |
| `created_at` | timestamptz | NO | `now()` | |

Unique index on `(user_id, activity_id, local_date)` — also the `on_conflict`
target for both writes. RLS: full CRUD on `auth.uid() = user_id`.

> `local_date` is stored as a bare `date` and must never be re-parsed into a
> `DateTime` on the client. Tomorrow.io returns forecast days as UTC instants,
> and the device is the only place the user's real timezone is known, so
> normalisation happens there. See `localDateKeyOf` in
> `lib/features/outcomes/outcome_stats.dart`.

**Repository:** `ActivityDayOutcomeRepository`. `recordMatchedDays` upserts with
`ignoreDuplicates: true` so re-observing a day cannot overwrite an answer;
`answer` upserts *without* it, because that write must win.

### condition_profile_history
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `gen_random_uuid()` | |
| `activity_id` | uuid FK | NO | — | → activities.id |
| `user_id` | uuid | NO | — | |
| `previous_profile` | jsonb | NO | `'{}'` | snapshot of old condition_profiles row |
| `new_profile` | jsonb | NO | `'{}'` | snapshot of new condition_profiles row |
| `change_reason` | text | YES | — | |
| `changed_at` | timestamptz | NO | `now()` | |

### categories
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `uuid_generate_v4()` | |
| `user_id` | uuid FK | NO | — | → profiles.id |
| `name` | text | NO | — | |
| `color` | text | YES | — | hex color string |
| `icon` | text | YES | — | icon identifier |
| `created_at` | timestamptz | YES | `now()` | |

### notification_preferences
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `uuid_generate_v4()` | |
| `activity_id` | uuid FK | NO | — | → activities.id |
| `notify_days_before` | boolean | YES | `false` | |
| `days_before_count` | integer | YES | `2` | |
| `notify_sunday_digest` | boolean | YES | `false` | |
| `notify_night_before` | boolean | YES | `false` | |
| `notify_morning_of` | boolean | YES | `false` | |
| `morning_time` | time | YES | `'07:00:00'` | |
| `created_at` | timestamptz | YES | `now()` | |
| `updated_at` | timestamptz | YES | `now()` | |

### profiles
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | — | = auth.users.id |
| `display_name` | text | YES | — | |
| `avatar_url` | text | YES | — | |
| `is_premium` | boolean | YES | `false` | |
| `temperature_unit` | text | YES | `'F'` | 'F' or 'C' |
| `created_at` | timestamptz | YES | `now()` | |
| `updated_at` | timestamptz | YES | `now()` | |

### user_locations
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `uuid_generate_v4()` | |
| `user_id` | uuid FK | NO | — | → profiles.id |
| `city` | text | YES | — | |
| `latitude` | numeric | NO | — | |
| `longitude` | numeric | NO | — | |
| `updated_at` | timestamptz | YES | `now()` | |

### behavioral_events
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `gen_random_uuid()` | |
| `user_id` | uuid FK | YES | — | → auth.users.id, ON DELETE SET NULL; null = de-identified |
| `activity_id` | uuid FK | YES | — | → activities.id |
| `event_type` | text | NO | — | CHECK constraint, see approved types below |
| `conditions_at_event` | jsonb | NO | `'{}'` | see CLAUDE.md for schema |
| `geographic_context` | jsonb | NO | `'{}'` | see CLAUDE.md for schema |
| `temporal_context` | jsonb | NO | `'{}'` | see CLAUDE.md for schema |
| `session_context` | jsonb | NO | `'{}'` | see CLAUDE.md for schema |
| `monetization_event_id` | uuid FK | YES | — | → monetization_events.id |
| `created_at` | timestamptz | NO | `now()` | |

**Approved event_types** (enforced by CHECK constraint):
`condition_match_notified`, `notification_opened`, `app_opened_post_notification`,
`activity_confirmed`, `condition_match_ignored`, `activity_viewed`,
`wishlist_added`, `wishlist_removed`, `condition_profile_updated`,
`affiliate_link_clicked`, `partner_impression_viewed`, `partner_cta_clicked`,
`auth_completed`, `auth_skipped`, `onboarding_completed`,
`booking_integration_viewed`, `theme_override_set`

---

## Foreign Key Summary (App Tables)

| Table | Column | References |
|---|---|---|
| `activities` | `user_id` | `profiles.id` |
| `behavioral_events` | `user_id` | `auth.users.id` (ON DELETE SET NULL) |
| `behavioral_events` | `activity_id` | `activities.id` (ON DELETE SET NULL) |
| `behavioral_events` | `monetization_event_id` | `monetization_events.id` |
| `categories` | `user_id` | `profiles.id` |
| `condition_profile_history` | `activity_id` | `activities.id` |
| `condition_profiles` | `activity_id` | `activities.id` |
| `notification_preferences` | `activity_id` | `activities.id` |
| `user_locations` | `user_id` | `profiles.id` |

---

## Tables — Intelligence Platform Only

These tables are managed by the outabout-intelligence system.
The Flutter app does **not** read or write these directly (except
`behavioral_events` and `monetization_events` which are write-only from the app).

### monetization_events
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `gen_random_uuid()` | |
| `event_type` | text | NO | — | |
| `partner_id` | uuid FK | YES | — | → partners.id |
| `affiliate_link_id` | uuid FK | YES | — | → affiliate_links.id |
| `activity_category` | text | YES | — | |
| `activity_id` | uuid FK | YES | — | → activities.id |
| `weather_temp_c` | numeric | YES | — | |
| `weather_condition` | text | YES | — | |
| `weather_wind_kph` | numeric | YES | — | |
| `weather_uv_index` | numeric | YES | — | |
| `region` | text | YES | — | |
| `country` | text | YES | `'US'` | |
| `hour_of_day` | smallint | YES | — | |
| `day_of_week` | smallint | YES | — | |
| `month_of_year` | smallint | YES | — | |
| `user_id` | uuid | YES | — | |
| `created_at` | timestamptz | NO | `now()` | |
| `behavioral_event_id` | uuid FK | YES | — | → behavioral_events.id |

### partners
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `gen_random_uuid()` | |
| `name` | text | NO | — | |
| `description` | text | YES | — | |
| `website_url` | text | YES | — | |
| `booking_url` | text | YES | — | |
| `logo_url` | text | YES | — | |
| `contact_email` | text | YES | — | |
| `status` | text | NO | `'active'` | |
| `partner_type` | text | NO | `'local_business'` | |
| `monthly_fee_usd` | numeric | YES | — | |
| `notes` | text | YES | — | |
| `created_at` | timestamptz | NO | `now()` | |
| `updated_at` | timestamptz | NO | `now()` | |

### affiliate_links
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `gen_random_uuid()` | |
| `category_id` | uuid FK | YES | — | |
| `activity_id` | uuid FK | YES | — | |
| `label` | text | NO | — | |
| `url` | text | NO | — | |
| `provider` | text | YES | — | |
| `commission_type` | text | YES | — | |
| `is_active` | boolean | NO | `true` | |
| `priority` | integer | NO | `0` | |
| `created_at` | timestamptz | NO | `now()` | |
| `updated_at` | timestamptz | NO | `now()` | |

### partner_categories
Join table: `id` (uuid PK), `partner_id` (uuid FK → partners.id),
`category_id` (uuid FK), `created_at` (timestamptz).

### partner_locations
| Column | Type | Nullable | Default | Notes |
|---|---|---|---|---|
| `id` | uuid PK | NO | `gen_random_uuid()` | |
| `partner_id` | uuid FK | NO | — | → partners.id |
| `city` | text | YES | — | |
| `region` | text | YES | — | |
| `country` | text | NO | `'US'` | |
| `latitude` | numeric | NO | — | |
| `longitude` | numeric | NO | — | |
| `radius_km` | numeric | NO | `25` | |
| `created_at` | timestamptz | NO | `now()` | |

### aggregate_insights
Precomputed rollup table for intelligence queries. Key columns:
`period_start`, `period_end`, `granularity`, `activity_category`,
`region`, `country`, temporal dimensions (`month_of_year`, `day_of_week`),
weather averages (`avg_temp_c`, `dominant_condition`, `avg_wind_kph`, `avg_uv_index`),
counts (`activity_match_count`, `unique_user_count`, `partner_impression_count`,
`partner_click_count`, `affiliate_click_count`), `computed_at`, `data_sources` (jsonb),
`confidence_score`.

### data_intelligence_vectors
pgvector table for RAG embeddings: `id` (bigint), `text` (varchar),
`metadata_` (jsonb), `node_id` (varchar), `embedding` (vector).

### external_data_events
Ingested third-party data: `id` (uuid), `source`, `event_type`,
`geographic_key` (jsonb), `temporal_key` (jsonb), `activity_category`,
`payload` (jsonb), `confidence_score`, `ingested_at`.

### food_access_scores
USDA food access data by zipcode: `id` (serial), `zipcode`, `metro`,
access metrics (`low_access_raw`, `low_access_normalized`),
grocery density, health outcomes, `composite_score`, `letter_grade`,
`interpretation`, `created_at`, `updated_at`.

### intelligence_queries
Query log for the intelligence platform: `id` (uuid), `queried_by`,
`buyer_segment`, `raw_query`, `parsed_intent` (jsonb),
`agents_invoked` (text[]), `data_sources_used` (text[]),
`response_text`, `response_payload` (jsonb), `confidence_score`,
feedback fields (`feedback_rating`, `feedback_note`, `feedback_at`,
`output_acted_on`), `follow_up_query_id`, `low_confidence_dimensions` (jsonb),
`created_at`.

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
5000-5999 → WeatherTheme.snowy
4000-4999 → WeatherTheme.rainy
2000-2999 → WeatherTheme.rainy   // fog maps to rainy mood
1100-1999 → WeatherTheme.overcast
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
    .select('*, condition_profiles(*)')
    .eq('user_id', userId)
    .order('created_at', ascending: false);

// Upsert
await _client.from('profiles').upsert(profile.toJson());

// Update specific field
await _client
    .from('profiles')
    .update({'temperature_unit': 'C'})
    .eq('id', userId);

// Realtime subscription
_client
    .from('activities')
    .stream(primaryKey: ['id'])
    .eq('user_id', userId)
    .listen((data) { /* handle */ });
```
