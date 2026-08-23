import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import '../core/weather_theme_provider.dart';
import '../data/models/behavioral_event.dart';
import '../data/models/user_location.dart';
import '../features/home/home_providers.dart';

// ---------------------------------------------------------------------------
// Approved event types
// ---------------------------------------------------------------------------

const approvedEventTypes = <String>[
  'wishlist_added',
  'wishlist_removed',
  'activity_viewed',
  'condition_profile_updated',
  // Written by the check-weather edge function, never by this app. Kept in
  // the list so a future client-side call is not silently dropped.
  'condition_match_notified',
  'notification_opened',
  'app_opened_post_notification',
  'activity_confirmed',
  'condition_match_ignored',
  'affiliate_link_clicked',
  'partner_impression_viewed',
  // 'partner_cta_clicked' removed: no call site ever existed. The Find & book
  // sheet logs partner_impression_viewed and affiliate_link_clicked, which
  // between them describe the whole funnel. Still permitted by the DB
  // constraint — see 20260824000000.
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
  // 'notification_preference_changed' removed: the per-activity notification
  // preference UI it described was deleted in 3d3e4f2, and the model and
  // repository behind it in 49760bf. It never had a call site in this app.
  // Added for account deletion
  'account_deletion_requested',
  // Added for one-shot calendar export
  'calendar_event_added',
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

  // Calendar days, not elapsed duration. `difference().inDays` truncates a
  // Duration, and a spring-forward transition inside the season makes a
  // 7-calendar-day gap measure 6 days 23h — so every week boundary after a
  // DST change landed in the previous week. US DST starts in March, inside
  // the spring window, so spring was wrong every year.
  final startDay = DateTime(
    seasonStart.year,
    seasonStart.month,
    seasonStart.day,
  );
  final thisDay = DateTime(date.year, date.month, date.day);
  final daysSinceStart = thisDay.difference(startDay).inDays.abs();
  return (daysSinceStart / 7).floor() + 1;
}

// ---------------------------------------------------------------------------
// BehavioralEventService
// ---------------------------------------------------------------------------

class BehavioralEventService {
  final SupabaseClient _supabase;

  /// Read at log time, not captured at construction.
  ///
  /// `ref.watch(weatherThemeProvider.notifier)` only rebuilds when the
  /// notifier *instance* is replaced, and the weather sync mutates its state
  /// in place — so a captured string stayed at whatever the theme was on the
  /// first build (`sunny`, in the common case) for the whole session, and
  /// every `weather_theme` and `active_theme` written was stale.
  final String Function() _activeThemeName;

  /// Where the user is, bucketed. Read at log time for the same reason.
  final GeographicContext Function() _geographicContext;

  final String _appVersion;

  BehavioralEventService({
    required SupabaseClient supabase,
    required String Function() activeThemeName,
    required GeographicContext Function() geographicContext,
    required String appVersion,
  }) : _supabase = supabase,
       _activeThemeName = activeThemeName,
       _geographicContext = geographicContext,
       _appVersion = appVersion;

  /// Builds the insert payload for a behavioral event.
  ///
  /// [userId] must be a real authenticated user id — the `user_id` column is
  /// a uuid, so no placeholder is ever substituted. Callers without a session
  /// must not build a payload at all; see [log].
  ///
  /// Exposed for testing. In production, use [log] instead.
  Map<String, dynamic> buildPayload(
    String eventType, {
    required String userId,
    Map<String, dynamic>? extra,
    ConditionsAtEvent? conditions,
    DateTime? occurredAt,
  }) {
    // A buffered event is written after the session exists, which can be
    // several screens later. The temporal context has to describe when it
    // happened, not when it was flushed.
    final now = occurredAt ?? DateTime.now();

    // Callers that have live weather pass a real snapshot built by
    // [buildConditionsSnapshot]. The zero-filled fallback is what every event
    // in this app used to log unconditionally; it is kept so the many existing
    // call sites that have no weather in scope behave exactly as before rather
    // than silently gaining a wrong one.
    final resolvedConditions =
        conditions ??
        ConditionsAtEvent(
          tempC: 0.0,
          tempF: 0.0,
          precipitationProbability: 0,
          windKph: 0.0,
          uvIndex: 0,
          airQualityIndex: 0,
          weatherTheme: _activeThemeName(),
          forecastWindowHours: 0,
        );

    // Was hardcoded to empty strings, 0.0 coordinates and a flat 'US'. The
    // bucketed coordinates were already sitting in userLocationProvider, so
    // the geographic dimension of the whole dataset was empty — and actively
    // false for anyone outside the US.
    final geographic = _geographicContext();

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
      activeTheme: _activeThemeName(),
    );

    return <String, dynamic>{
      'event_type': eventType,
      'user_id': userId,
      'conditions_at_event': resolvedConditions.toJson(),
      'geographic_context': geographic.toJson(),
      'temporal_context': temporal.toJson(),
      'session_context': {...session.toJson(), if (extra != null) ...extra},
    };
  }

  /// Logs a behavioral event to the `behavioral_events` table.
  ///
  /// Validates [eventType] against [approvedEventTypes]. If invalid, logs a
  /// warning and returns without inserting. Also returns without inserting
  /// when there is no authenticated session.
  ///
  /// Never throws — all errors are caught and logged via [debugPrint].
  Future<void> log(
    String eventType, {
    Map<String, dynamic>? extra,
    ConditionsAtEvent? conditions,
  }) async {
    try {
      // Validate event type.
      if (!approvedEventTypes.contains(eventType)) {
        debugPrint(
          'BehavioralEventService: unknown event type "$eventType" — skipping.',
        );
        return;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        // No session yet. Buffer rather than drop: onboarding logs
        // `onboarding_completed` from steps 1, 2 and 3, all of which run
        // before the auth page at step 5 — so five of the six call sites
        // were silently no-ops on every first run, and the funnel they exist
        // to measure was empty. No placeholder user id is invented; the row
        // is written with the real one once it exists.
        _buffer(eventType, extra: extra, conditions: conditions);
        return;
      }

      final data = buildPayload(
        eventType,
        userId: userId,
        extra: extra,
        conditions: conditions,
      );
      await _supabase.from('behavioral_events').insert(data);
    } catch (e, st) {
      debugPrint('BehavioralEventService: failed to log "$eventType" — $e');
      debugPrint('$st');
    }
  }

  /// Events logged before a session existed, oldest first.
  final List<_PendingEvent> _pending = [];

  /// Hard cap. A user who never signs in must not accumulate unboundedly.
  static const int maxPendingEvents = 50;

  /// How many events are waiting for a session. Exposed for testing.
  @visibleForTesting
  int get pendingCount => _pending.length;

  void _buffer(
    String eventType, {
    Map<String, dynamic>? extra,
    ConditionsAtEvent? conditions,
  }) {
    if (_pending.length >= maxPendingEvents) {
      // Drop the oldest: the most recent steps are the ones that describe
      // where the user actually got to.
      _pending.removeAt(0);
    }
    _pending.add(
      _PendingEvent(
        eventType: eventType,
        extra: extra,
        conditions: conditions,
        occurredAt: DateTime.now(),
      ),
    );
  }

  /// Writes any events that were logged before the session existed.
  ///
  /// Called when auth reports a signed-in session. Safe to call repeatedly:
  /// the queue is drained before the first write, so a failure discards
  /// rather than retries — these are analytics, and a retry loop on a dead
  /// connection is worse than a missing row.
  Future<void> flushPending() async {
    if (_pending.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final queued = List<_PendingEvent>.from(_pending);
    _pending.clear();

    for (final event in queued) {
      try {
        final data = buildPayload(
          event.eventType,
          userId: userId,
          extra: event.extra,
          conditions: event.conditions,
          occurredAt: event.occurredAt,
        );
        await _supabase.from('behavioral_events').insert(data);
      } catch (e) {
        debugPrint(
          'BehavioralEventService: failed to flush '
          '"${event.eventType}" — $e',
        );
      }
    }
  }
}

/// One event held until a session exists to attribute it to.
class _PendingEvent {
  const _PendingEvent({
    required this.eventType,
    required this.extra,
    required this.conditions,
    required this.occurredAt,
  });

  final String eventType;
  final Map<String, dynamic>? extra;
  final ConditionsAtEvent? conditions;
  final DateTime occurredAt;
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Builds the geographic context for an event from the user's saved location.
///
/// Coordinates are bucketed to two decimal places (~1.1 km) by [bucket] before
/// they leave the device. When there is no location yet, the fields stay empty
/// and `country` is empty rather than a hardcoded 'US' — "not collected" and
/// "United States" must not look the same in the dataset.
GeographicContext buildGeographicContext(UserLocation? location) {
  if (location == null) {
    return const GeographicContext(
      metro: '',
      city: '',
      state: '',
      country: '',
      latBucketed: 0.0,
      lngBucketed: 0.0,
      timezone: '',
    );
  }

  // `city` is stored as "City, ST" by userLocationProvider.
  final parts = (location.city ?? '').split(',');
  final city = parts.isNotEmpty ? parts.first.trim() : '';
  final state = parts.length > 1 ? parts[1].trim() : '';

  return GeographicContext(
    metro: '',
    city: city,
    state: state,
    country: '',
    latBucketed: bucket(location.latitude),
    lngBucketed: bucket(location.longitude),
    timezone: DateTime.now().timeZoneName,
  );
}

final behavioralEventServiceProvider = Provider<BehavioralEventService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final themeNotifier = ref.watch(weatherThemeProvider.notifier);
  final packageInfoAsync = ref.watch(packageInfoProvider);
  final appVersion = packageInfoAsync.valueOrNull?.version ?? 'unknown';
  return BehavioralEventService(
    supabase: supabase,
    // Read at log time — see the field docs. Capturing the value here is what
    // froze weather_theme at whatever the theme was on first build.
    activeThemeName: () => themeNotifier.activeThemeName,
    geographicContext: () =>
        buildGeographicContext(ref.read(userLocationProvider).valueOrNull),
    appVersion: appVersion,
  );
});
