import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/condition_match.dart';
import '../../data/models/condition_profile.dart';
import '../../data/models/profile.dart';
import '../../data/models/user_location.dart';
import '../../data/models/weather_data.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/weather_repository.dart';
import '../../data/models/activity.dart';
import '../../services/location_service.dart';

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final activityRepositoryProvider =
    Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(supabaseClientProvider));
});

final weatherRepositoryProvider =
    Provider<WeatherRepository>((ref) {
  return WeatherRepository(dotenv.env['TOMORROW_API_KEY']!);
});

// ---------------------------------------------------------------------------
// User location provider
// ---------------------------------------------------------------------------

final userLocationProvider =
    FutureProvider<UserLocation?>((ref) async {
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
    final geo =
        await locationService.reverseGeocode(pos.lat, pos.lng);
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

const _cacheDataKey = 'cached_weather_data';
const _cacheFetchedAtKey = 'cached_weather_fetched_at';

final weatherDataProvider =
    FutureProvider<WeatherData>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  if (location == null) throw NoLocationException();

  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(weatherRepositoryProvider);

  WeatherData data;
  try {
    data = await repo.fetchCurrent(
      location.latitude,
      location.longitude,
    );

    // Cache the result
    await prefs.setString(
      _cacheDataKey,
      jsonEncode(data.toJson()),
    );
    await prefs.setString(
      _cacheFetchedAtKey,
      DateTime.now().toIso8601String(),
    );
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
      rethrow;
    }
  }

  ref
      .read(weatherThemeProvider.notifier)
      .setThemeFromConditions(data.weatherCode);
  ref
      .read(weatherThemeProvider.notifier)
      .setThemeFromTimeOfDay(DateTime.now());

  return data;
});

// ---------------------------------------------------------------------------
// Activities provider
// ---------------------------------------------------------------------------

final activitiesProvider =
    FutureProvider<List<Activity>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];
  final repo = ref.watch(activityRepositoryProvider);
  return repo.fetchForUser(userId);
});

// ---------------------------------------------------------------------------
// Condition match provider
// ---------------------------------------------------------------------------

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
        activities
            .map((a) =>
                ConditionMatch(activity: a, isMatch: false))
            .toList(),
      ),
      data: (weather) => AsyncData(
        activities
            .map((a) => ConditionMatch(
                  activity: a,
                  isMatch: evaluateMatch(
                    a.conditionProfile,
                    weather,
                  ),
                ))
            .toList(),
      ),
    ),
  );
});

bool evaluateMatch(
  ConditionProfile? profile,
  WeatherData weather,
) {
  if (profile == null) return true;

  if (profile.tempEnabled) {
    if (profile.tempMin != null &&
        weather.temperature < profile.tempMin!) {
      return false;
    }
    if (profile.tempMax != null &&
        weather.temperature > profile.tempMax!) {
      return false;
    }
  }

  if (profile.precipEnabled) {
    if (profile.precipLevel == 'none' &&
        weather.precipitationIntensity > 0) {
      return false;
    }
  }

  if (profile.windEnabled) {
    if (profile.windMax != null &&
        weather.windSpeed > profile.windMax!) {
      return false;
    }
  }

  if (profile.uvEnabled) {
    if (profile.uvMin != null &&
        weather.uvIndex < profile.uvMin!) {
      return false;
    }
    if (profile.uvMax != null &&
        weather.uvIndex > profile.uvMax!) {
      return false;
    }
  }

  return true;
}

// ---------------------------------------------------------------------------
// Activity detail provider
// ---------------------------------------------------------------------------

final activityDetailProvider =
    FutureProvider.family<Activity?, String>(
        (ref, activityId) async {
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
