import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import '../core/weather_theme_provider.dart';
import '../data/models/behavioral_event.dart';

// ---------------------------------------------------------------------------
// Approved event types
// ---------------------------------------------------------------------------

const approvedEventTypes = <String>[
  'wishlist_added',
  'wishlist_removed',
  'activity_viewed',
  'condition_profile_updated',
  'condition_match_notified',
  'notification_opened',
  'app_opened_post_notification',
  'activity_confirmed',
  'condition_match_ignored',
  'affiliate_link_clicked',
  'partner_impression_viewed',
  'partner_cta_clicked',
  'theme_override_set',
  'booking_integration_viewed',
  'auth_completed',
  'auth_skipped',
  'onboarding_completed',
  // Added for behavioral event audit
  'category_created',
  'category_selected',
  'category_deselected',
  'filter_applied',
  'filter_cleared',
  'weather_refreshed',
  'settings_changed',
];

// ---------------------------------------------------------------------------
// Season helpers
// ---------------------------------------------------------------------------

/// Returns the season name for a given month (1-12).
String seasonForMonth(int month) {
  if (month >= 3 && month <= 5) return 'spring';
  if (month >= 6 && month <= 8) return 'summer';
  if (month >= 9 && month <= 11) return 'fall';
  return 'winter';
}

/// Returns the starting month for a given season.
int _seasonStartMonth(String season) {
  switch (season) {
    case 'spring':
      return 3;
    case 'summer':
      return 6;
    case 'fall':
      return 9;
    case 'winter':
      return 12;
    default:
      return 1;
  }
}

/// Calculates the week of the season for a given date.
int weekOfSeason(DateTime date) {
  final season = seasonForMonth(date.month);
  final startMonth = _seasonStartMonth(season);

  DateTime seasonStart;
  if (season == 'winter' && date.month <= 2) {
    // Winter spans Dec of previous year to Feb of current year.
    seasonStart = DateTime(date.year - 1, 12, 1);
  } else {
    seasonStart = DateTime(date.year, startMonth, 1);
  }

  final daysSinceStart = date.difference(seasonStart).inDays;
  return (daysSinceStart / 7).floor() + 1;
}

// ---------------------------------------------------------------------------
// BehavioralEventService
// ---------------------------------------------------------------------------

class BehavioralEventService {
  final SupabaseClient _supabase;
  final String _activeThemeName;
  final String _appVersion;

  BehavioralEventService({
    required SupabaseClient supabase,
    required String activeThemeName,
    required String appVersion,
  })  : _supabase = supabase,
        _activeThemeName = activeThemeName,
        _appVersion = appVersion;

  /// Builds the insert payload for a behavioral event.
  ///
  /// Exposed for testing. In production, use [log] instead.
  Map<String, dynamic> buildPayload(
    String eventType, {
    Map<String, dynamic>? extra,
  }) {
    final now = DateTime.now();
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';

    final conditions = ConditionsAtEvent(
      tempC: 0.0,
      tempF: 0.0,
      precipitationProbability: 0,
      windKph: 0.0,
      uvIndex: 0,
      airQualityIndex: 0,
      weatherTheme: _activeThemeName,
      forecastWindowHours: 0,
    );

    final geographic = GeographicContext(
      metro: '',
      city: '',
      state: '',
      country: 'US',
      latBucketed: 0.0,
      lngBucketed: 0.0,
      timezone: '',
    );

    final temporal = TemporalContext(
      hourOfDay: now.hour,
      dayOfWeek: now.weekday,
      weekOfMonth: ((now.day - 1) / 7).floor() + 1,
      monthOfYear: now.month,
      season: seasonForMonth(now.month),
      weekOfSeason: weekOfSeason(now),
      daysSinceLastMatch: 0,
      daysSinceActivityCreated: 0,
      consecutiveMatchCount: 0,
    );

    final String platformName;
    if (kIsWeb) {
      platformName = 'web';
    } else {
      platformName = Platform.isIOS ? 'ios' : 'android';
    }

    final session = SessionContext(
      platform: platformName,
      appVersion: _appVersion,
      activeTheme: _activeThemeName,
    );

    return <String, dynamic>{
      'event_type': eventType,
      'user_id': userId,
      'conditions_at_event': conditions.toJson(),
      'geographic_context': geographic.toJson(),
      'temporal_context': temporal.toJson(),
      'session_context': {...session.toJson(), if (extra != null) ...extra},
    };
  }

  /// Logs a behavioral event to the `behavioral_events` table.
  ///
  /// Validates [eventType] against [approvedEventTypes]. If invalid, logs a
  /// warning and returns without inserting.
  ///
  /// Never throws — all errors are caught and logged via [debugPrint].
  Future<void> log(
    String eventType, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      // Validate event type.
      if (!approvedEventTypes.contains(eventType)) {
        debugPrint(
          'BehavioralEventService: unknown event type "$eventType" — skipping.',
        );
        return;
      }

      final data = buildPayload(eventType, extra: extra);
      await _supabase.from('behavioral_events').insert(data);
    } catch (e, st) {
      debugPrint('BehavioralEventService: failed to log "$eventType" — $e');
      debugPrint('$st');
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final behavioralEventServiceProvider =
    Provider<BehavioralEventService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final themeNotifier = ref.watch(weatherThemeProvider.notifier);
  final packageInfoAsync = ref.watch(packageInfoProvider);
  final appVersion = packageInfoAsync.valueOrNull?.version ?? 'unknown';
  return BehavioralEventService(
    supabase: supabase,
    activeThemeName: themeNotifier.activeThemeName,
    appVersion: appVersion,
  );
});
