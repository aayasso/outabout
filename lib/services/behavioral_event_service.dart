import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  // Added for the outcome loop. One type carrying the threshold in
  // session_context rather than four separate types, so a future milestone
  // needs no migration. The value is bounded vocabulary (1|5|10|25), so it
  // survives deidentify_behavioral_events' key-drop list intact.
  'activity_milestone_reached',
  // Added for adaptive condition suggestions. Three types rather than one
  // carrying the stage, because shown/accepted/declined is a funnel and a
  // funnel is counted per stage — see 20260826000100.
  'condition_suggestion_shown',
  'condition_suggestion_accepted',
  'condition_suggestion_declined',
  // Added for the home-screen widget. The tap itself is not observable inside
  // a widget — WidgetKit gives the extension no callback — so the open is
  // logged by the app when it is launched via the widget's deep link. That is
  // the whole funnel available: impressions are unmeasurable by design.
  'app_opened_from_widget',
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

  /// Read at log time, for the same reason as the two closures above.
  ///
  /// `packageInfoProvider` is a FutureProvider, so watching it rebuilt this
  /// provider the moment PackageInfo resolved — a few frames into launch — and
  /// the replacement instance carried an empty `_pending` list, silently
  /// dropping anything buffered before a session existed. It also froze
  /// app_version at 'unknown' in the OneSignal click handler, which main.dart
  /// captures exactly once and holds for the life of the process, so every
  /// notification_opened row was written unversioned.
  final String Function() _appVersion;

  BehavioralEventService({
    required SupabaseClient supabase,
    required String Function() activeThemeName,
    required GeographicContext Function() geographicContext,
    required String Function() appVersion,
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
    String? monetizationEventId,
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
      appVersion: _appVersion(),
      activeTheme: _activeThemeName(),
    );

    return <String, dynamic>{
      'event_type': eventType,
      'user_id': userId,
      'conditions_at_event': resolvedConditions.toJson(),
      'geographic_context': geographic.toJson(),
      'temporal_context': temporal.toJson(),
      'session_context': {...session.toJson(), if (extra != null) ...extra},
      // Omitted rather than sent as null, so a row for a non-partner event is
      // byte-identical to what this method produced before the column had a
      // writer. Keeps the dataset free of a column that is explicitly null on
      // every row but a handful.
      'monetization_event_id': ?monetizationEventId,
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
    /// The monetization_events row this event describes, when there is one.
    ///
    /// Only the partner surfaces pass it. It is the join the schema was built
    /// around — behavioral_events.monetization_event_id — and until the Find &
    /// book sheet started writing monetization rows, nothing could ever
    /// populate it, so revenue and behaviour were two disconnected records of
    /// the same tap.
    String? monetizationEventId,
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
        monetizationEventId: monetizationEventId,
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
///
/// [timezone] is the device's IANA identifier, supplied by
/// [deviceTimezoneProvider]. Passed in rather than read here so this stays a
/// function of its arguments: the lookup is an async platform call and this is
/// synchronous, called on the hot path of every event.
GeographicContext buildGeographicContext(
  UserLocation? location, {
  required String timezone,
}) {
  final zone = _resolveTimezone(timezone);
  if (location == null) {
    return GeographicContext(
      metro: '',
      city: '',
      state: '',
      country: '',
      latBucketed: 0.0,
      lngBucketed: 0.0,
      timezone: zone,
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
    timezone: zone,
  );
}

/// The zone to record, never empty.
///
/// The platform lookup is async and this path is not, so the first events of a
/// session can arrive before it resolves. `DateTime.now().timeZoneName` is
/// what this field held before — an abbreviation like "PDT" — so falling back
/// to it degrades to the old behaviour rather than to a hole in the dataset.
/// Distinguishable downstream on sight: an IANA identifier always contains a
/// slash and an abbreviation never does.
String _resolveTimezone(String timezone) =>
    timezone.isNotEmpty ? timezone : DateTime.now().timeZoneName;

/// The device's IANA timezone identifier, e.g. `America/Los_Angeles`.
///
/// Resolved once per app run. The device is the only place the user's real
/// zone is known — `user_locations` does not store one — and until now the app
/// reported only an abbreviation, which is ambiguous across zones, absent in
/// much of the world, and changes twice a year for a user who has not moved.
///
/// Recorded now so that server-side work has it when it arrives: anything that
/// wants to know which local day an event fell on, or to run at a sensible
/// local hour, needs the identifier, and it cannot be backfilled onto events
/// already written.
///
/// Failure yields an empty string rather than throwing. A timezone lookup must
/// never be able to take down event logging, and [_resolveTimezone] turns the
/// empty string back into the old abbreviation.
final deviceTimezoneProvider = FutureProvider<String>((ref) async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  } catch (e) {
    debugPrint('deviceTimezoneProvider: no IANA timezone available — $e');
    return '';
  }
});

final behavioralEventServiceProvider = Provider<BehavioralEventService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final themeNotifier = ref.watch(weatherThemeProvider.notifier);
  // Read, not watched — see the _appVersion field docs. Watching this made
  // the provider rebuild mid-launch and take the pending event buffer with it.
  String appVersion() =>
      ref.read(packageInfoProvider).valueOrNull?.version ?? 'unknown';
  return BehavioralEventService(
    supabase: supabase,
    // Read at log time — see the field docs. Capturing the value here is what
    // froze weather_theme at whatever the theme was on first build.
    activeThemeName: () => themeNotifier.activeThemeName,
    geographicContext: () => buildGeographicContext(
      ref.read(userLocationProvider).valueOrNull,
      // Read at log time, like the location beside it: the zone resolves
      // asynchronously and capturing it here would freeze whatever was known
      // when the service was first built, which is nothing.
      timezone: ref.read(deviceTimezoneProvider).valueOrNull ?? '',
    ),
    appVersion: appVersion,
  );
});
