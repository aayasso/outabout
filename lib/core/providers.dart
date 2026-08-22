import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Supabase client provider
// ---------------------------------------------------------------------------

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ---------------------------------------------------------------------------
// Package info provider
// ---------------------------------------------------------------------------

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

// ---------------------------------------------------------------------------
// User-scoped local state
// ---------------------------------------------------------------------------

/// SharedPreferences key holding the cached current-conditions payload.
const cachedWeatherDataKey = 'cached_weather_data';
const cachedWeatherFetchedAtKey = 'cached_weather_fetched_at';
const cachedForecastDataKey = 'cached_forecast_data';
const cachedForecastFetchedAtKey = 'cached_forecast_fetched_at';

/// Every SharedPreferences key scoped to the signed-in user.
///
/// Cleared on both sign-out and account deletion so a new session never
/// inherits the previous user's state. Device-level preferences —
/// `theme_override` and `schedule_layout` — are deliberately absent: they
/// describe the device, not the account. Temperature unit is not here either;
/// it lives server-side on `profiles.temperature_unit`, so it is already
/// per-user.
///
/// Single source of truth: both [AuthService] and `clearUserScopedState`
/// read this list so the two paths cannot drift.
const userScopedPrefsKeys = <String>[
  'onboarding_complete',
  'categories_seeded',
  cachedWeatherDataKey,
  cachedWeatherFetchedAtKey,
  cachedForecastDataKey,
  cachedForecastFetchedAtKey,
];
