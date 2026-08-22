import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/weather_theme_provider.dart';
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
import '../../services/location_service.dart';

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

  final data = await client
      .from('user_locations')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  if (data != null) return UserLocation.fromJson(data);

  try {
    final locationService = ref.read(locationServiceProvider);
    final pos = await locationService.getCurrentPosition();
    final geo = await locationService.reverseGeocode(pos.lat, pos.lng);
    return UserLocation(
      userId: userId,
      latitude: pos.lat,
      longitude: pos.lng,
      city: '${geo.city}, ${geo.state}',
    );
  } catch (_) {
    return null;
  }
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
    debugPrint(
      '$provider: ${error.runtimeType} — ${redactApiKey(error)}',
    );
  }
}

const _cacheDataKey = 'cached_weather_data';
const _cacheFetchedAtKey = 'cached_weather_fetched_at';

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
    await prefs.setString(_cacheDataKey, jsonEncode(data.toJson()));
    await prefs.setString(_cacheFetchedAtKey, DateTime.now().toIso8601String());
  } catch (e) {
    // On failure, try to load from cache
    final cachedJson = prefs.getString(_cacheDataKey);
    final cachedAt = prefs.getString(_cacheFetchedAtKey);
    if (cachedJson != null && cachedAt != null) {
      data = WeatherData.fromCacheJson(
        jsonDecode(cachedJson) as Map<String, dynamic>,
        DateTime.parse(cachedAt),
      );
    } else {
      _logWeatherFailure('weatherDataProvider', e);
      rethrow;
    }
  }

  ref
      .read(weatherThemeProvider.notifier)
      .setThemeFromConditions(data.weatherCode);
  ref.read(weatherThemeProvider.notifier).setThemeFromTimeOfDay(DateTime.now());

  return data;
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

const _cacheForecastKey = 'cached_forecast_data';
const _cacheForecastFetchedAtKey = 'cached_forecast_fetched_at';

final dailyForecastProvider = FutureProvider<List<DailyForecast>>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  if (location == null) {
    _logWeatherFailure('dailyForecastProvider', NoLocationException());
    throw NoLocationException();
  }

  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(weatherRepositoryProvider);

  List<DailyForecast> forecasts;
  try {
    forecasts = await repo.fetchForecast(location.latitude, location.longitude);

    await prefs.setString(
      _cacheForecastKey,
      jsonEncode(forecasts.map((f) => f.toJson()).toList()),
    );
    await prefs.setString(
      _cacheForecastFetchedAtKey,
      DateTime.now().toIso8601String(),
    );
  } catch (e) {
    final cachedJson = prefs.getString(_cacheForecastKey);
    if (cachedJson != null) {
      final list = jsonDecode(cachedJson) as List<dynamic>;
      forecasts = list
          .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _logWeatherFailure('dailyForecastProvider', e);
      rethrow;
    }
  }

  return forecasts;
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
    final precip = day.precipitationProbability;
    if (profile.precipLevel == 'none' && precip > 20) {
      return false;
    }
    if (profile.precipLevel == 'light_ok' && precip > 60) {
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
    data: (days) => activitiesAsync.when(
      loading: () => const AsyncLoading(),
      error: (e, st) => AsyncError(e, st),
      data: (activities) => AsyncData(
        days.map((day) {
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
  final repo = ref.watch(activityRepositoryProvider);
  return repo.fetchById(activityId);
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
