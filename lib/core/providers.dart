import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// SharedPreferences key holding the outcome prompts already answered or
/// dismissed, as a JSON list of `"<activityId>|<yyyy-MM-dd>"` entries.
const outcomePromptHandledKey = 'outcome_prompt_handled';

/// SharedPreferences flag recording that the calendar-permission explainer
/// has been shown once.
///
/// Device-level, like `schedule_layout`: a refusal is a fact about this
/// device's settings, not about the account, and re-explaining after a
/// sign-out would be exactly the nagging the flag exists to prevent. So it is
/// deliberately absent from [userScopedPrefsKeys].
const calendarPermissionExplainedKey = 'calendar_permission_explained';

/// Every SharedPreferences key scoped to the signed-in user.
///
/// Cleared on both sign-out and account deletion so a new session never
/// inherits the previous user's state. Device-level preferences —
/// `theme_override`, `schedule_layout` and `calendar_permission_explained` —
/// are deliberately absent: they
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
  outcomePromptHandledKey,
];

// ---------------------------------------------------------------------------
// External URL launcher
// ---------------------------------------------------------------------------

/// Opens an external URL, returning whether it was handled.
///
/// Injected rather than called directly so widgets that open links stay
/// testable: a test overrides this provider and asserts the URL without
/// launching anything.
typedef UrlLauncher = Future<bool> Function(Uri url);

final urlLauncherProvider = Provider<UrlLauncher>((ref) {
  return (Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('urlLauncher: failed to open $url — $e');
      return false;
    }
  };
});

/// Hosted legal documents. Apple reads these URLs, not the copies in the repo.
abstract class LegalUrls {
  static const String privacyPolicy =
      'https://aayasso.github.io/outabout/privacy-policy.html';
  static const String termsOfService =
      'https://aayasso.github.io/outabout/terms-of-service.html';
}
