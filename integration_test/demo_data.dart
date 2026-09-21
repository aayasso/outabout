/// Demo data for the screenshot pipeline.
///
/// All values are in the units the models store (Celsius for
/// temperature, km/h for wind). The UI converts to Fahrenheit
/// via the Profile's temperatureUnit.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/category.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/notification_preference.dart';
import 'package:outabout/data/models/profile.dart';
import 'package:outabout/data/models/user_location.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/data/repositories/notification_preference_repository.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/outcomes/outcome_providers.dart';
import 'package:outabout/features/weather_scene/weather_scene_provider.dart';
import 'package:outabout/features/widget/widget_providers.dart';
import 'package:outabout/data/models/behavioral_event.dart';
import 'package:outabout/services/behavioral_event_service.dart';

// ------------------------------------------------------------------
// Mock Supabase — strict: unstubbed members throw
// ------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

/// Builds a strict mock [SupabaseClient].
///
/// Only [GoTrueClient.currentUser] and
/// [GoTrueClient.onAuthStateChange] are stubbed.
/// Any other member access throws (mocktail default).
///
/// When [authenticated] is false, `currentUser` returns null
/// (used for the onboarding shot).
MockSupabaseClient buildMockSupabase({
  bool authenticated = true,
}) {
  final mockAuth = MockGoTrueClient();

  if (authenticated) {
    final mockUser = MockUser();
    when(() => mockUser.id).thenReturn('demo-user');
    when(() => mockAuth.currentUser).thenReturn(mockUser);
  } else {
    when(() => mockAuth.currentUser).thenReturn(null);
  }
  when(() => mockAuth.onAuthStateChange)
      .thenAnswer((_) => const Stream.empty());

  final mockClient = MockSupabaseClient();
  when(() => mockClient.auth).thenReturn(mockAuth);

  return mockClient;
}

// ------------------------------------------------------------------
// No-op behavioral event service
// ------------------------------------------------------------------

class NoOpBehavioralEventService extends BehavioralEventService {
  NoOpBehavioralEventService()
      : super(
          supabase: _dummyClient,
          activeThemeName: () => 'sunny',
          geographicContext: () => const GeographicContext(
            metro: 'Pittsburgh',
            city: 'Pittsburgh',
            state: 'PA',
            country: 'US',
            latBucketed: 40.44,
            lngBucketed: -79.99,
            timezone: 'America/New_York',
          ),
          appVersion: () => '1.0.0',
        );

  static final _dummyClient = buildMockSupabase();

  final List<String> logged = [];

  @override
  Future<void> log(
    String eventType, {
    Map<String, dynamic>? extra,
    ConditionsAtEvent? conditions,
    String? monetizationEventId,
  }) async {
    logged.add(eventType);
  }

  @override
  Future<void> flushPending() async {}
}

// ------------------------------------------------------------------
// Demo user ID
// ------------------------------------------------------------------

const demoUserId = 'demo-user';

// ------------------------------------------------------------------
// Categories
// ------------------------------------------------------------------

final demoCategories = <Category>[
  const Category(
    id: 'cat-outdoor',
    userId: demoUserId,
    name: 'Outdoor',
  ),
  const Category(
    id: 'cat-sports',
    userId: demoUserId,
    name: 'Sports',
  ),
  const Category(
    id: 'cat-social',
    userId: demoUserId,
    name: 'Social',
  ),
  const Category(
    id: 'cat-rainy-day',
    userId: demoUserId,
    name: 'Rainy Day',
  ),
];

// ------------------------------------------------------------------
// Activities
// ------------------------------------------------------------------

final demoActivities = <Activity>[
  Activity(
    id: 'act-1',
    userId: demoUserId,
    name: 'Morning Run',
    categoryIds: const ['cat-outdoor', 'cat-sports'],
    conditionProfile: const ConditionProfile(
      id: 'cp-1',
      activityId: 'act-1',
      tempEnabled: true,
      tempMin: 10,
      tempMax: 21,
      precipEnabled: true,
      precipLevel: 'avoid_rain',
      windEnabled: true,
      windMax: 32,
    ),
  ),
  Activity(
    id: 'act-2',
    userId: demoUserId,
    name: 'Padel',
    categoryIds: const ['cat-sports'],
    conditionProfile: const ConditionProfile(
      id: 'cp-2',
      activityId: 'act-2',
      tempEnabled: true,
      tempMin: 18,
      tempMax: 32,
      precipEnabled: true,
      precipLevel: 'avoid_rain',
      windEnabled: true,
      windMax: 20,
    ),
  ),
  Activity(
    id: 'act-3',
    userId: demoUserId,
    name: 'Hiking at Frick Park',
    categoryIds: const ['cat-outdoor'],
    conditionProfile: const ConditionProfile(
      id: 'cp-3',
      activityId: 'act-3',
      tempEnabled: true,
      tempMin: 7,
      tempMax: 29,
      precipEnabled: true,
      precipLevel: 'avoid_rain',
      windEnabled: false,
    ),
  ),
  Activity(
    id: 'act-4',
    userId: demoUserId,
    name: 'Golf',
    categoryIds: const ['cat-outdoor', 'cat-sports'],
    conditionProfile: const ConditionProfile(
      id: 'cp-4',
      activityId: 'act-4',
      tempEnabled: true,
      tempMin: 16,
      tempMax: 32,
      precipEnabled: true,
      precipLevel: 'avoid_rain',
      windEnabled: true,
      windMax: 24,
    ),
  ),
  Activity(
    id: 'act-5',
    userId: demoUserId,
    name: 'Museum Afternoon',
    categoryIds: const ['cat-rainy-day'],
    conditionProfile: const ConditionProfile(
      id: 'cp-5',
      activityId: 'act-5',
      tempEnabled: false,
      precipEnabled: true,
      precipLevel: 'rain_only',
      windEnabled: false,
    ),
  ),
  Activity(
    id: 'act-6',
    userId: demoUserId,
    name: 'Picnic in the Park',
    categoryIds: const ['cat-outdoor', 'cat-social'],
    conditionProfile: const ConditionProfile(
      id: 'cp-6',
      activityId: 'act-6',
      tempEnabled: true,
      tempMin: 22,
      tempMax: 30,
      precipEnabled: true,
      precipLevel: 'avoid_rain',
      windEnabled: false,
    ),
  ),
  Activity(
    id: 'act-7',
    userId: demoUserId,
    name: 'Patio Dinner',
    categoryIds: const ['cat-social'],
    conditionProfile: const ConditionProfile(
      id: 'cp-7',
      activityId: 'act-7',
      tempEnabled: true,
      tempMin: 20,
      tempMax: 30,
      precipEnabled: true,
      precipLevel: 'avoid_rain',
      windEnabled: false,
    ),
  ),
];

// ------------------------------------------------------------------
// Forecast — sunny group (shots 01-05, 07, 08)
// ------------------------------------------------------------------

/// Anchor date for all demo days.
final _day1 = DateTime(2026, 9, 21);

final sunnyForecast = <DailyForecast>[
  DailyForecast(
    date: _day1,
    temperatureMin: 14,
    temperatureMax: 21,
    precipitationProbability: 5,
    windSpeedMax: 12,
    weatherCode: 1000,
  ),
  DailyForecast(
    date: _day1.add(const Duration(days: 1)),
    temperatureMin: 18,
    temperatureMax: 28,
    precipitationProbability: 10,
    windSpeedMax: 14,
    weatherCode: 1100,
  ),
  DailyForecast(
    date: _day1.add(const Duration(days: 2)),
    temperatureMin: 12,
    temperatureMax: 17,
    precipitationProbability: 85,
    windSpeedMax: 22,
    weatherCode: 4001,
  ),
  DailyForecast(
    date: _day1.add(const Duration(days: 3)),
    temperatureMin: 16,
    temperatureMax: 26,
    precipitationProbability: 5,
    windSpeedMax: 38,
    weatherCode: 1000,
  ),
  DailyForecast(
    date: _day1.add(const Duration(days: 4)),
    temperatureMin: 22,
    temperatureMax: 32,
    precipitationProbability: 0,
    windSpeedMax: 8,
    weatherCode: 1000,
  ),
];

// ------------------------------------------------------------------
// Forecast — rainy group (shot 06): rain is today
// ------------------------------------------------------------------

final rainyForecast = <DailyForecast>[
  DailyForecast(
    date: _day1,
    temperatureMin: 12,
    temperatureMax: 17,
    precipitationProbability: 85,
    windSpeedMax: 22,
    weatherCode: 4001,
  ),
  DailyForecast(
    date: _day1.add(const Duration(days: 1)),
    temperatureMin: 18,
    temperatureMax: 28,
    precipitationProbability: 10,
    windSpeedMax: 14,
    weatherCode: 1100,
  ),
  DailyForecast(
    date: _day1.add(const Duration(days: 2)),
    temperatureMin: 14,
    temperatureMax: 21,
    precipitationProbability: 5,
    windSpeedMax: 12,
    weatherCode: 1000,
  ),
  DailyForecast(
    date: _day1.add(const Duration(days: 3)),
    temperatureMin: 16,
    temperatureMax: 26,
    precipitationProbability: 5,
    windSpeedMax: 38,
    weatherCode: 1000,
  ),
  DailyForecast(
    date: _day1.add(const Duration(days: 4)),
    temperatureMin: 22,
    temperatureMax: 32,
    precipitationProbability: 0,
    windSpeedMax: 8,
    weatherCode: 1000,
  ),
];

// ------------------------------------------------------------------
// WeatherData
// ------------------------------------------------------------------

const sunnyWeatherData = WeatherData(
  weatherCode: 1000,
  temperature: 24,
  windSpeed: 10,
  humidity: 45,
  precipitationIntensity: 0,
  uvIndex: 6,
);

const rainyWeatherData = WeatherData(
  weatherCode: 4001,
  temperature: 12,
  windSpeed: 22,
  humidity: 88,
  precipitationIntensity: 2.5,
  uvIndex: 1,
);

// ------------------------------------------------------------------
// Profile & location
// ------------------------------------------------------------------

const demoProfile = Profile(
  id: demoUserId,
  displayName: 'Alex',
  temperatureUnit: 'F',
);

const demoLocation = UserLocation(
  id: 'loc-1',
  userId: demoUserId,
  city: 'Pittsburgh, PA',
  latitude: 40.44,
  longitude: -79.99,
  timezone: 'America/New_York',
);

// ------------------------------------------------------------------
// Provider overrides shared across all shots
// ------------------------------------------------------------------

/// Builds a [ForecastSnapshot] override.
ForecastSnapshot forecastSnapshot(List<DailyForecast> days) =>
    ForecastSnapshot(days: days);

/// Returns overrides common to every shot group.
///
/// Caller adds group-specific overrides (weatherData, forecast,
/// now, theme) on top.
List<Override> baseOverrides({
  required MockSupabaseClient supabase,
  required NoOpBehavioralEventService eventService,
  required SharedPreferences prefs,
}) {
  return [
    // ignore: invalid_use_of_visible_for_testing_member
    sharedPreferencesProvider.overrideWithValue(prefs),
    supabaseClientProvider.overrideWithValue(supabase),
    activitiesProvider.overrideWith(
      (ref) async => demoActivities,
    ),
    categoriesProvider.overrideWith(
      (ref) async => demoCategories,
    ),
    profileProvider.overrideWith(
      (ref) async => demoProfile,
    ),
    userLocationProvider.overrideWith(
      (ref) async => demoLocation,
    ),
    deviceTimezoneProvider.overrideWith(
      (ref) async => 'America/New_York',
    ),
    packageInfoProvider.overrideWith((ref) async {
      throw UnimplementedError(
        'packageInfoProvider not needed in screenshots',
      );
    }),
    behavioralEventServiceProvider.overrideWithValue(
      eventService,
    ),
    urlLauncherProvider.overrideWithValue(
      (Uri url) async => true,
    ),
    appIsForegroundProvider.overrideWith((ref) => true),
    // Notification preferences — Supabase source.
    notificationPreferenceProvider.overrideWith(
      (ref, activityId) async =>
          NotificationPreference(activityId: activityId),
    ),
    // Side-effect writers — no-op.
    matchedDayRecorderProvider.overrideWith((ref) {}),
    widgetSyncProvider.overrideWith((ref) {}),
  ];
}
