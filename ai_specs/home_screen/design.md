# Home Screen — Technical Design
# ai_specs/home_screen/design.md
# Last updated: 2026-05-03

## Pre-build Cleanup Required

Before implementing any code from this design:

1. **`lib/models/activity.dart`** has a legacy `category` (text) field that
   must be removed and replaced with `category_ids` (uuid[]) to match the
   live `activities` table schema. The model also needs `notes`, `url`,
   `location`, `is_archived`, `updated_at`, and `geographic_context` fields
   added, plus a nested `ConditionProfile?` from the joined query.

2. **Confirm `locationServiceProvider`** exists at
   `lib/services/location_service.dart` before using it in
   `home_providers.dart`. This file exists in the onboarding worktree but
   may not yet be merged to `feature/home-screen`. If missing, copy it from
   the worktree before building.

---

## 1. Screens & Widgets

### HomeScreen (shell)
- **File:** `lib/features/home/home_screen.dart`
- **Type:** ConsumerStatefulWidget (needs StatefulNavigationShell state)
- **Providers watched:** `weatherThemeColorsProvider`, `weatherThemeProvider`
- **Props:** `StatefulNavigationShell navigationShell` (from go_router)
- **Role:** Scaffold with bottom `NavigationBar` wrapping 3 tab branches.
  Does not render tab content directly — go_router's `StatefulShellRoute`
  handles that via `navigationShell`.
- **Sub-widgets:** None. The shell is thin — just Scaffold + NavigationBar.

### TodayTab (Tab 0 — default landing)
- **File:** `lib/features/home/tabs/today_tab.dart`
- **Type:** ConsumerWidget
- **Providers watched:**
  - `weatherThemeColorsProvider` — colors
  - `weatherThemeProvider` — brightness for shadow selection
  - `weatherDataProvider` — current conditions from Tomorrow.io
  - `activitiesProvider` — user's non-archived activities
  - `conditionMatchProvider` — derived: which activities match current weather
  - `userLocationProvider` — city name for weather header
- **Sub-widgets:**
  - `_WeatherSummaryCard` — current temp, condition icon, location name
  - `_MatchedActivityCard` — activity card with green match indicator
  - `_ActivityCard` — activity card in neutral (non-matched) state
  - `_TodayEmptyState` — no activities exist yet, CTA to add
  - `_TodayShimmer` — shimmer skeleton for loading state
  - `_WeatherErrorBanner` — inline banner when weather fetch fails
  - `_LocationPermissionBanner` — inline banner when location denied

### ActivitiesTab (Tab 1)
- **File:** `lib/features/home/tabs/activities_tab.dart`
- **Type:** ConsumerWidget
- **Providers watched:**
  - `weatherThemeColorsProvider` — colors
  - `weatherThemeProvider` — brightness for shadow selection
  - `activitiesProvider` — all non-archived activities
- **Sub-widgets:**
  - `_ActivityListCard` — activity name + condition profile summary chips
  - `_ActivitiesEmptyState` — no activities, encourage adding first
  - `_ActivitiesShimmer` — shimmer skeleton for loading state

### SettingsTab (Tab 2)
- **File:** `lib/features/home/tabs/settings_tab.dart`
- **Type:** ConsumerWidget
- **Providers watched:**
  - `weatherThemeColorsProvider` — colors
  - `weatherThemeProvider` — current theme (for override selector)
  - `userThemeOverrideProvider` — current override value
  - `profileProvider` — user profile (display name, temp unit)
  - `userLocationProvider` — current location
  - `packageInfoProvider` — app version
- **Sub-widgets:**
  - `_SettingsSection` — grouped section with header
  - `_SettingsRow` — label + trailing widget (toggle, chevron, value)
  - `_ThemeOverrideSelector` — theme picker (adaptive + 5 manual options)
  - `_SignOutButton` — destructive action with confirmation

---

## 2. Provider Structure

All providers hand-written. No code-gen. Feature providers live in
`lib/features/home/home_providers.dart`.

### New providers

```
userLocationProvider          FutureProvider<UserLocation?>
  |-- reads: supabaseClientProvider, locationServiceProvider
  '-- fetches from user_locations table, falls back to device GPS

weatherDataProvider           FutureProvider<WeatherData>
  |-- reads: userLocationProvider, weatherRepositoryProvider
  |-- fetches current conditions from Tomorrow.io
  '-- side-effect: calls weatherThemeProvider.notifier
       .setThemeFromConditions(weatherCode) on success

activitiesProvider            FutureProvider<List<Activity>>
  |-- reads: supabaseClientProvider, activityRepositoryProvider
  |-- fetches non-archived activities for current user
  '-- joins: condition_profiles via select('*, condition_profiles(*)')

conditionMatchProvider        Provider<AsyncValue<List<ConditionMatch>>>
  |-- reads: activitiesProvider, weatherDataProvider
  '-- for each activity, evaluates condition_profiles against current
       weather -> returns list of {activity, isMatch}

profileProvider               FutureProvider<Profile?>
  |-- reads: supabaseClientProvider
  '-- fetches profiles row for current user

weatherRepositoryProvider     Provider<WeatherRepository>
  '-- reads: dotenv TOMORROW_API_KEY

activityRepositoryProvider    Provider<ActivityRepository>
  '-- reads: supabaseClientProvider
```

### Provider signatures

```dart
// lib/features/home/home_providers.dart

final userLocationProvider = FutureProvider<UserLocation?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  // Fetch from user_locations table
  final data = await client
      .from('user_locations')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  if (data != null) return UserLocation.fromJson(data);
  // Fallback: get from device GPS via locationService
  final locationService = ref.read(locationServiceProvider);
  final pos = await locationService.getCurrentPosition();
  final geo = await locationService.reverseGeocode(pos.lat, pos.lng);
  return UserLocation(
    latitude: pos.lat,
    longitude: pos.lng,
    city: '${geo.city}, ${geo.state}',
  );
});

final weatherDataProvider = FutureProvider<WeatherData>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  if (location == null) throw NoLocationException();
  final repo = ref.watch(weatherRepositoryProvider);
  final data = await repo.fetchCurrent(location.latitude, location.longitude);
  // Side-effect: update weather theme
  ref.read(weatherThemeProvider.notifier)
      .setThemeFromConditions(data.weatherCode);
  ref.read(weatherThemeProvider.notifier)
      .setThemeFromTimeOfDay(DateTime.now());
  return data;
});

final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(activityRepositoryProvider);
  return repo.fetchForUser(userId);
});

final conditionMatchProvider =
    Provider<AsyncValue<List<ConditionMatch>>>((ref) {
  final activitiesAsync = ref.watch(activitiesProvider);
  final weatherAsync = ref.watch(weatherDataProvider);
  return activitiesAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (activities) => weatherAsync.when(
      loading: () => const AsyncLoading(),
      error: (e, st) => AsyncData(
        // Weather failed — return all activities as unmatched
        activities
            .map((a) => ConditionMatch(activity: a, isMatch: false))
            .toList(),
      ),
      data: (weather) => AsyncData(
        activities
            .map((a) => ConditionMatch(
                  activity: a,
                  isMatch: _evaluateMatch(a.conditionProfile, weather),
                ))
            .toList(),
      ),
    ),
  );
});

final profileProvider = FutureProvider<Profile?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  final data = await client
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
  return data != null ? Profile.fromJson(data) : null;
});
```

---

## 3. Repository Methods

### ActivityRepository
**File:** `lib/data/repositories/activity_repository.dart`

```dart
class ActivityRepository {
  ActivityRepository(this._client);
  final SupabaseClient _client;

  /// Fetches all non-archived activities for [userId], joined with
  /// their condition_profiles. Ordered by created_at descending.
  Future<List<Activity>> fetchForUser(String userId) async {
    final data = await _client
        .from('activities')
        .select('*, condition_profiles(*)')
        .eq('user_id', userId)
        .eq('is_archived', false)
        .order('created_at', ascending: false);
    return data.map(Activity.fromJson).toList();
  }

  /// Inserts a new activity. Returns the inserted row with
  /// server-generated id.
  Future<Activity> insert(Activity activity) async {
    final data = await _client
        .from('activities')
        .insert(activity.toJson())
        .select('*, condition_profiles(*)')
        .single();
    return Activity.fromJson(data);
  }

  /// Soft-deletes an activity by setting is_archived = true.
  Future<void> archive(String activityId) async {
    await _client
        .from('activities')
        .update({
          'is_archived': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', activityId);
  }
}
```

### WeatherRepository
**File:** `lib/data/repositories/weather_repository.dart`

```dart
class WeatherRepository {
  WeatherRepository(this._apiKey);
  final String _apiKey;

  /// Fetches current weather conditions for [lat], [lng] from
  /// Tomorrow.io. Throws [WeatherFetchException] on non-200 responses.
  Future<WeatherData> fetchCurrent(double lat, double lng) async {
    final uri = Uri.parse(
      'https://api.tomorrow.io/v4/weather/realtime'
      '?location=$lat,$lng'
      '&fields=weatherCode,temperature,windSpeed,humidity,'
      'precipitationIntensity,precipitationProbability,uvIndex'
      '&units=metric'
      '&apikey=$_apiKey',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw WeatherFetchException(response.statusCode, response.body);
    }
    return WeatherData.fromJson(jsonDecode(response.body));
  }
}
```

---

## 4. Data Flow

### TodayTab flow

```
App opens -> HomeScreen shell renders -> TodayTab is default tab
  |
  |-- userLocationProvider
  |    |-- Query user_locations table for saved location
  |    |-- Fallback: locationServiceProvider.getCurrentPosition()
  |    '-- Result: UserLocation(lat, lng, city)
  |
  |-- weatherDataProvider (depends on userLocationProvider)
  |    |-- WeatherRepository.fetchCurrent(lat, lng)
  |    |-- Side-effect: weatherThemeProvider.setThemeFromConditions(code)
  |    |-- Side-effect: weatherThemeProvider.setThemeFromTimeOfDay(now)
  |    '-- Result: WeatherData(weatherCode, tempC, windKph, uvIndex, ...)
  |
  |-- activitiesProvider (independent of weather)
  |    |-- ActivityRepository.fetchForUser(userId)
  |    |    select('*, condition_profiles(*)')
  |    '-- Result: List<Activity> (each with nested ConditionProfile)
  |
  '-- conditionMatchProvider (depends on both above)
       |-- For each activity, compare condition_profiles thresholds
       |    against current WeatherData values
       '-- Result: List<ConditionMatch> -> UI renders matched first,
            then unmatched
```

### ActivitiesTab flow

```
User taps Activities tab
  |
  '-- activitiesProvider (already cached from TodayTab if visited)
       |-- Same FutureProvider — Riverpod deduplicates
       '-- Result: List<Activity> -> rendered as full list with
            condition profile summary chips on each card
```

### Condition matching logic

```dart
bool _evaluateMatch(ConditionProfile? profile, WeatherData weather) {
  if (profile == null) return true; // no conditions = always matches

  if (profile.tempEnabled) {
    if (profile.tempMin != null && weather.tempC < profile.tempMin!) {
      return false;
    }
    if (profile.tempMax != null && weather.tempC > profile.tempMax!) {
      return false;
    }
  }

  if (profile.precipEnabled) {
    // precip_level: 'none' means no rain required
    if (profile.precipLevel == 'none' &&
        weather.precipitationIntensity > 0) {
      return false;
    }
  }

  if (profile.windEnabled) {
    if (profile.windMax != null && weather.windKph > profile.windMax!) {
      return false;
    }
  }

  if (profile.uvEnabled) {
    if (profile.uvMin != null && weather.uvIndex < profile.uvMin!) {
      return false;
    }
    if (profile.uvMax != null && weather.uvIndex > profile.uvMax!) {
      return false;
    }
  }

  return true;
}
```

---

## 5. Edge Cases & Error States

### No location permission
- `userLocationProvider` catches `PermissionDeniedException`
- TodayTab shows `_LocationPermissionBanner` at top:
  "Enable location to see weather for your area" + Settings button
- Activities still load and display (without match indicators)
- Weather card shows placeholder: "Location unavailable"

### Tomorrow.io fetch failure
- `weatherDataProvider` throws `WeatherFetchException`
- `conditionMatchProvider` handles this gracefully: returns all activities
  as `isMatch: false` (no crash, no blank screen)
- TodayTab shows `_WeatherErrorBanner`:
  "Couldn't load weather. Pull to refresh."
- `ref.invalidate(weatherDataProvider)` on pull-to-refresh retry

### Empty activities list
- Both TodayTab and ActivitiesTab show contextual empty states
- TodayTab `_TodayEmptyState`: "Add your first outdoor activity" +
  CTA button that navigates to `/activity/add`
- ActivitiesTab `_ActivitiesEmptyState`: "Your wishlist is empty" + CTA

### Loading states (shimmer — never spinners)
- `_TodayShimmer`: weather card skeleton (1 rect) + 3 activity card
  skeletons
- `_ActivitiesShimmer`: 4 activity card skeletons
- Uses `Shimmer.fromColors(baseColor: colors.surface,
  highlightColor: colors.divider)`
- Skeleton shapes match final card dimensions with `OutAboutRadius.cards`

### Network error with retry
- Both weather and activities use
  `ref.watch(provider).when(loading:, error:, data:)`
- Error state shows icon + message + "Try again" TextButton
- "Try again" calls `ref.invalidate(failedProvider)`
- Pull-to-refresh on TodayTab invalidates both `weatherDataProvider`
  and `activitiesProvider` simultaneously

### Auth session expired mid-use
- Router redirect already handles this: if session is null, resets
  `onboarding_complete` flag and redirects to `/onboarding`
- No special handling needed in home screen providers

---

## 6. Haptic Moments

| Interaction | Haptic | Method |
|---|---|---|
| Tap activity card to view detail | None (navigation) | -- |
| Pull-to-refresh completes successfully | Light | `OutAboutHaptics.onConditionToggle()` |
| Activity condition match detected on load | Success vibrate | `OutAboutHaptics.onConditionMatch()` |
| Archive activity (swipe or long-press) | Medium | `OutAboutHaptics.onActivitySave()` |
| Add new activity (after save succeeds) | Medium | `OutAboutHaptics.onActivitySave()` |
| Toggle theme override in Settings | Light | `OutAboutHaptics.onConditionToggle()` |
| Toggle temperature unit in Settings | Light | `OutAboutHaptics.onConditionToggle()` |
| Sign out tap (after confirmation) | None (destructive) | -- |

Condition match haptic fires once per session when
`conditionMatchProvider` first resolves with at least one
`isMatch: true`. Use `ref.listen` on `conditionMatchProvider` in
TodayTab to trigger — not on every rebuild.

---

## 7. Weather Theme Note

Themes are set **automatically** based on real local weather via
Tomorrow.io `weatherCode` ->
`WeatherThemeNotifier.setThemeFromConditions()`. Night theme overrides
weather after sunset (hour >= 20 or < 6) via `setThemeFromTimeOfDay()`.

**There is no manual theme switcher on the TodayTab or ActivitiesTab.**

Manual override lives exclusively in SettingsTab via
`_ThemeOverrideSelector`. When user sets an override,
`userThemeOverrideProvider` persists it to SharedPreferences and
`weatherThemeProvider` ignores all API/time signals until the override
is cleared.

The theme update side-effect happens inside `weatherDataProvider`:
after a successful Tomorrow.io fetch, it calls
`setThemeFromConditions()` and `setThemeFromTimeOfDay()`. This means
the theme updates every time weather data refreshes (app foreground,
pull-to-refresh, location change).
