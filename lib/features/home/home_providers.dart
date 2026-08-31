import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outcomes/outcome_providers.dart';
import 'outcome_prompt_provider.dart';
import '../../core/providers.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/behavioral_event.dart';
import '../../data/models/condition_profile.dart';
import '../../data/models/daily_forecast.dart';
import '../../data/models/profile.dart';
import '../../data/models/schedule_day.dart';
import '../../data/models/user_location.dart';
import '../../data/models/weather_data.dart';
import '../../data/models/category.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/weather_repository.dart';
import '../../data/models/activity.dart';
import '../../services/behavioral_event_service.dart';
import '../../services/location_service.dart';
import '../onboarding/onboarding_provider.dart';

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(supabaseClientProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseClientProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.fetchForUser(userId);
});

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(dotenv.env['TOMORROW_API_KEY']!);
});

// ---------------------------------------------------------------------------
// User location provider
// ---------------------------------------------------------------------------

final userLocationProvider = FutureProvider<UserLocation?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final deviceZone = ref.read(deviceTimezoneProvider).valueOrNull ?? '';

  final data = await client
      .from('user_locations')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  if (data != null) {
    final stored = UserLocation.fromJson(data);

    // Backfill the zone for a row written before user_locations had the
    // column. Without this the early return below means an existing user is
    // never revisited, so every nudge they receive for the life of the install
    // is scheduled off the longitude estimate — an hour or two out, and blind
    // to DST — even though the device has known the real answer all along.
    if ((stored.timezone ?? '').isEmpty && deviceZone.isNotEmpty) {
      try {
        await client
            .from('user_locations')
            .update({'timezone': deviceZone}).eq('user_id', userId);
      } catch (e) {
        debugPrint('userLocationProvider: could not backfill timezone — $e');
      }
      return UserLocation(
        id: stored.id,
        userId: stored.userId,
        city: stored.city,
        latitude: stored.latitude,
        longitude: stored.longitude,
        timezone: deviceZone,
        updatedAt: stored.updatedAt,
      );
    }
    return stored;
  }

  final locationService = ref.read(locationServiceProvider);

  final ({double lat, double lng}) pos;
  try {
    pos = await locationService.getCurrentPosition();
  } catch (e) {
    // Without coordinates there is nothing to forecast. Log the reason —
    // a bare `return null` here made every downstream failure look
    // identical and unattributable.
    debugPrint('userLocationProvider: position unavailable — $e');
    return null;
  }

  // The city name is cosmetic; the forecast only needs coordinates. Apple's
  // geocoder throttles repeated lookups, so a failure here must not cost the
  // user their weather.
  var city = '';
  try {
    final geo = await locationService.reverseGeocode(pos.lat, pos.lng);
    city = '${geo.city}, ${geo.state}';
  } catch (e) {
    debugPrint('userLocationProvider: reverse geocode failed — $e');
  }

  final resolved = UserLocation(
    userId: userId,
    latitude: pos.lat,
    longitude: pos.lng,
    city: city,
    timezone: deviceZone,
  );

  // Persisted, not merely returned. The check-weather edge function iterates
  // user_locations to decide who to notify, and nothing in this app ever wrote
  // a row — UserLocation.toJson had no call site at all — so the table was
  // empty for every user and no notification could ever be sent. This is the
  // write that makes the feature possible.
  //
  // Failure is non-fatal and swallowed: the resolved value still drives this
  // session's forecast, and a schedule the user opened the app to read must
  // not fail because a background write did.
  try {
    await client
        .from('user_locations')
        .upsert(resolved.toJson(), onConflict: 'user_id');
  } catch (e) {
    debugPrint('userLocationProvider: could not save location — $e');
  }

  return resolved;
});

// ---------------------------------------------------------------------------
// Weather data provider
// ---------------------------------------------------------------------------

class NoLocationException implements Exception {
  @override
  String toString() => 'NoLocationException: no location available';
}

/// Logs a weather-provider failure with enough detail to diagnose it.
///
/// Always routes through [redactApiKey] — a network-layer
/// `http.ClientException` embeds the request URI, which carries the API key.
void _logWeatherFailure(String provider, Object error) {
  if (error is WeatherFetchException) {
    debugPrint(
      '$provider: Tomorrow.io returned HTTP ${error.statusCode} — '
      '${redactApiKey(error.body)}',
    );
  } else if (error is NoLocationException) {
    debugPrint('$provider: no location available — skipping fetch.');
  } else {
    debugPrint('$provider: ${error.runtimeType} — ${redactApiKey(error)}');
  }
}

final weatherDataProvider = FutureProvider<WeatherData>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  if (location == null) {
    _logWeatherFailure('weatherDataProvider', NoLocationException());
    throw NoLocationException();
  }

  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(weatherRepositoryProvider);

  WeatherData data;
  try {
    data = await repo.fetchCurrent(location.latitude, location.longitude);

    // Cache the result
    await prefs.setString(cachedWeatherDataKey, jsonEncode(data.toJson()));
    await prefs.setString(
      cachedWeatherFetchedAtKey,
      DateTime.now().toIso8601String(),
    );
  } catch (e) {
    // On failure, try to load from cache
    final cachedJson = prefs.getString(cachedWeatherDataKey);
    final cachedAt = prefs.getString(cachedWeatherFetchedAtKey);
    // tryParse, like dailyForecastProvider below: DateTime.parse throws a
    // FormatException on a corrupt value, from inside the very catch block
    // that exists to serve the cache — so a bad timestamp turned an offline
    // fetch into a hard error instead of yesterday's weather.
    final parsedCachedAt = cachedAt == null ? null : DateTime.tryParse(cachedAt);
    if (cachedJson != null && parsedCachedAt != null) {
      data = WeatherData.fromCacheJson(
        jsonDecode(cachedJson) as Map<String, dynamic>,
        parsedCachedAt,
      );
    } else {
      _logWeatherFailure('weatherDataProvider', e);
      rethrow;
    }
  }

  return data;
});

// ---------------------------------------------------------------------------
// Weather-adaptive theme sync
// ---------------------------------------------------------------------------

/// Applies live conditions to [weatherThemeProvider].
///
/// This is what makes the theme weather-adaptive at all. The application used
/// to be a side effect inside [weatherDataProvider], which never ran because
/// nothing in the app watched that provider — invalidating a provider with no
/// listeners does not execute it, so the theme sat on its constructor default
/// forever. The root widget watches this provider to keep it alive for the
/// app's lifetime.
///
/// Watching the notifier as well as the data means the theme is re-applied
/// when the notifier is rebuilt — which happens when the user sets or clears
/// a manual override, so clearing one returns to live conditions instead of
/// stranding on the default.
/// The clock the night override reads.
///
/// Injected rather than called directly so the sync is testable: reading
/// `DateTime.now()` inline made the sync tests pass only between 06:00 and
/// 20:00 and fail every evening.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final weatherThemeSyncProvider = Provider<void>((ref) {
  final notifier = ref.watch(weatherThemeProvider.notifier);
  final now = ref.watch(nowProvider);
  final data = ref.watch(weatherDataProvider).valueOrNull;
  if (data == null) return;

  // Deferred: assigning to another provider's state during this build would
  // mutate a provider mid-build.
  Future.microtask(() {
    if (!notifier.mounted) return;
    notifier.setThemeFromConditions(data.weatherCode);
    notifier.setThemeFromTimeOfDay(now());
  });
});

// ---------------------------------------------------------------------------
// Conditions snapshot
// ---------------------------------------------------------------------------

/// Builds a snapshot for the day being acted on, using live conditions.
typedef ConditionsSnapshotBuilder =
    ConditionsAtEvent Function({
      DailyForecast? forecastDay,
      int forecastWindowHours,
    });

/// Supplies [buildConditionsSnapshot] with the live weather and active theme.
///
/// Exposed as a function rather than a `family` because the natural key would
/// be a [DailyForecast], which has no value equality — a family would allocate
/// a fresh provider per rebuild and never dispose them. The pure builder stays
/// in `data/models` so it is testable without a container.
final conditionsSnapshotProvider = Provider<ConditionsSnapshotBuilder>((ref) {
  final themeName = ref.watch(weatherThemeProvider.notifier).activeThemeName;
  final current = ref.watch(weatherDataProvider).valueOrNull;

  return ({DailyForecast? forecastDay, int forecastWindowHours = 0}) =>
      buildConditionsSnapshot(
        weatherTheme: themeName,
        current: current,
        forecastDay: forecastDay,
        forecastWindowHours: forecastWindowHours,
      );
});

// ---------------------------------------------------------------------------
// Activities provider
// ---------------------------------------------------------------------------

final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(activityRepositoryProvider);
  return repo.fetchForUser(userId);
});

// ---------------------------------------------------------------------------
// Daily forecast provider
// ---------------------------------------------------------------------------

final dailyForecastProvider = FutureProvider<ForecastSnapshot>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  if (location == null) {
    _logWeatherFailure('dailyForecastProvider', NoLocationException());
    throw NoLocationException();
  }

  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(weatherRepositoryProvider);

  try {
    final forecasts = await repo.fetchForecast(
      location.latitude,
      location.longitude,
    );

    await prefs.setString(
      cachedForecastDataKey,
      jsonEncode(forecasts.map((f) => f.toJson()).toList()),
    );
    await prefs.setString(
      cachedForecastFetchedAtKey,
      DateTime.now().toIso8601String(),
    );
    return ForecastSnapshot(days: forecasts);
  } catch (e) {
    final cachedJson = prefs.getString(cachedForecastDataKey);
    if (cachedJson == null) {
      _logWeatherFailure('dailyForecastProvider', e);
      rethrow;
    }

    // The cache is worth serving offline, but the caller has to be told how
    // old it is. cachedForecastFetchedAtKey was written on every successful
    // fetch and never read, so a forecast from any number of days ago was
    // presented as the current one.
    final rawFetchedAt = prefs.getString(cachedForecastFetchedAtKey);
    DateTime? fetchedAt;
    if (rawFetchedAt != null) {
      // A corrupt timestamp must not take the cache down with it.
      fetchedAt = DateTime.tryParse(rawFetchedAt);
    }
    if (fetchedAt == null) {
      // Undatable cache is indistinguishable from a stale one, so the error
      // is the honest answer rather than silently vouching for it.
      _logWeatherFailure('dailyForecastProvider', e);
      rethrow;
    }

    _logWeatherFailure('dailyForecastProvider (serving cache)', e);
    final list = jsonDecode(cachedJson) as List<dynamic>;
    return ForecastSnapshot(
      days: list
          .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
      servedFromCacheAt: fetchedAt,
    );
  }
});

// ---------------------------------------------------------------------------
// Day-level condition matcher (mirrors backend conditionsMatch)
// ---------------------------------------------------------------------------

bool evaluateDayMatch(ConditionProfile? profile, DailyForecast day) {
  if (profile == null) return true;

  if (profile.tempEnabled) {
    if (profile.tempMin != null && day.temperatureMax < profile.tempMin!) {
      return false;
    }
    if (profile.tempMax != null && day.temperatureMin > profile.tempMax!) {
      return false;
    }
  }

  if (profile.precipEnabled) {
    final isDry = day.precipitationProbability <= PrecipLevel.dryThreshold;
    final wantsRain = profile.precipLevel == PrecipLevel.rainOnly;
    // Wanting rain on a dry day fails, and avoiding rain on a wet day fails.
    // Exhaustive by construction: anything that is not rain_only reads as
    // avoid_rain. The old code had a silent third path, which is how 'light'
    // came to mean "no filtering at all".
    if (wantsRain == isDry) {
      return false;
    }
  }

  if (profile.windEnabled) {
    if (profile.windMax != null && day.windSpeedMax > profile.windMax!) {
      return false;
    }
  }

  return true;
}

// ---------------------------------------------------------------------------
// Schedule match provider
// ---------------------------------------------------------------------------

final scheduleMatchProvider = Provider<AsyncValue<List<ScheduleDay>>>((ref) {
  final forecastAsync = ref.watch(dailyForecastProvider);
  final activitiesAsync = ref.watch(activitiesProvider);

  return forecastAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (snapshot) => activitiesAsync.when(
      loading: () => const AsyncLoading(),
      error: (e, st) => AsyncError(e, st),
      data: (activities) => AsyncData(
        snapshot.days.map((day) {
          final matched = activities
              .where((a) => evaluateDayMatch(a.conditionProfile, day))
              .toList();
          return ScheduleDay(forecast: day, matchedActivities: matched);
        }).toList(),
      ),
    ),
  );
});

// ---------------------------------------------------------------------------
// Schedule layout provider
// ---------------------------------------------------------------------------

const _scheduleLayoutKey = 'schedule_layout';

final scheduleLayoutProvider =
    StateNotifierProvider<ScheduleLayoutNotifier, ScheduleLayout>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ScheduleLayoutNotifier(prefs);
    });

class ScheduleLayoutNotifier extends StateNotifier<ScheduleLayout> {
  ScheduleLayoutNotifier(this._prefs) : super(_loadLayout(_prefs));
  final SharedPreferences _prefs;

  static ScheduleLayout _loadLayout(SharedPreferences prefs) {
    final stored = prefs.getString(_scheduleLayoutKey);
    if (stored == 'activityFirst') {
      return ScheduleLayout.activityFirst;
    }
    return ScheduleLayout.dayFirst;
  }

  Future<void> setLayout(ScheduleLayout layout) async {
    state = layout;
    await _prefs.setString(_scheduleLayoutKey, layout.name);
  }
}

// ---------------------------------------------------------------------------
// Activity detail provider
// ---------------------------------------------------------------------------

final activityDetailProvider = FutureProvider.family<Activity?, String>((
  ref,
  activityId,
) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  final repo = ref.watch(activityRepositoryProvider);
  return repo.fetchById(activityId, userId);
});

// ---------------------------------------------------------------------------
// Profile provider
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// User-scoped state teardown
// ---------------------------------------------------------------------------

/// Drops every cached trace of the signed-in user.
///
/// Driven by the auth stream rather than by a screen: a sign-out redirects
/// immediately, disposing whichever widget triggered it, so a widget-scoped
/// `ref` is already dead by the time this would run. Taking the container's
/// [Ref] also means deletion and sign-out share one path automatically —
/// both end in a `signedOut` event.
///
/// Safe to call when already signed out, and safe to call twice — clearing a
/// missing key and invalidating a provider are both no-ops.
Future<void> clearUserScopedState(Ref ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  for (final key in userScopedPrefsKeys) {
    await prefs.remove(key);
  }
  invalidateUserScopedProviders(ref);

  // Sign-out only: the cursor survives otherwise, pinned at the last page
  // where next() is a no-op, so "Get Started" did nothing and the user could
  // never re-onboard. Must NOT run on sign-in — the anonymous sign-in happens
  // at step 5, and resetting there would bounce the user back to step 1.
  ref.invalidate(onboardingStepProvider);
}

/// Forces every user-scoped provider to refetch.
///
/// Needed on sign-*in* as well as sign-out: these are FutureProviders, so a
/// value resolved while signed out — `userLocationProvider` returning null,
/// for instance — is cached and never recomputed just because a widget
/// rebuilt. Without this the second session of an app run gets the first
/// session's empty results. Deliberately does *not* touch preferences, which
/// would wipe `onboarding_complete` mid-flow.
void invalidateUserScopedProviders(Ref ref) {
  ref.invalidate(activitiesProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(userLocationProvider);
  ref.invalidate(weatherDataProvider);
  ref.invalidate(dailyForecastProvider);
  // Invalidating the family drops every per-activity entry.
  ref.invalidate(activityDetailProvider);
  // The notifier loads its handled set once, in its constructor, and
  // sharedPreferencesProvider never changes identity — so without this the
  // previous user's answered prompts stayed in memory and the next
  // markHandled wrote them straight back into the pref key
  // clearUserScopedState had just removed.
  ref.invalidate(outcomePromptProvider);
  // Same failure mode one layer down: OpportunityRecorder captures the signed
  // in user's id and keeps an in-memory set of days it has already written, so
  // without this the next user's matches are attributed to the previous one
  // and suppressed as already-recorded.
  ref.invalidate(opportunityRecorderProvider);
  ref.invalidate(matchedDayRecorderProvider);
  ref.invalidate(activityOutcomesProvider);
  // scheduleMatchProvider is derived from the above and recomputes itself.
}
