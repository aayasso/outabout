// Keeping the home-screen widget in step with the app.
//
// The widget cannot fetch: no API key, no location permission, no session. So
// the app pushes on every refresh and the widget renders last-known state,
// stamped with the day it describes.
//
// The push listens to `scheduleMatchProvider` rather than to the forecast,
// because what the widget shows is forecast x activities and that product
// already exists. It also means all six refresh triggers are covered for free
// — cold start, resume, pull-to-refresh, error retry, sign-in, sign-out —
// since every one of them funnels through `dailyForecastProvider`, which
// `scheduleMatchProvider` derives from.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/schedule_day.dart';
import '../home/home_providers.dart';
import 'widget_gateway.dart';
import 'widget_payload.dart';

/// Builds and pushes the payload, at most once per distinct value.
class WidgetSyncController {
  WidgetSyncController({
    required HomeWidgetGateway gateway,
    required DateTime Function() now,
  }) : _gateway = gateway,
       _now = now;

  final HomeWidgetGateway _gateway;
  final DateTime Function() _now;

  /// The last payload successfully written.
  ///
  /// Set only after the write returns. Marking it before would let a single
  /// transient failure — an App Group that is not there yet, a channel error
  /// during launch — freeze the widget until the payload happened to change
  /// again on its own, which for a stable schedule could be the next day.
  String? _lastWritten;

  /// Wipes the payload, so the widget stops showing the departing user's
  /// activity names.
  ///
  /// `_lastWritten` is reset too: without it the next user's first identical
  /// payload would be deduplicated against the cleared one and never written.
  Future<void> clear() async {
    try {
      await _gateway.clear();
      _lastWritten = null;
    } catch (e) {
      debugPrint('WidgetSyncController: could not clear the widget — $e');
    }
  }

  Future<void> push(List<ScheduleDay> days, String temperatureUnit) async {
    final payload = buildWidgetPayload(
      days: days,
      now: _now(),
      temperatureUnit: temperatureUnit,
    );
    // Null means the forecast in hand has no entry for today. The previous
    // payload is deliberately left in place: the widget can say "As of
    // yesterday", which is true, where a blank widget would just look broken.
    if (payload == null) return;

    final encoded = encodeWidgetPayload(payload);
    if (encoded == _lastWritten) return;

    try {
      await _gateway.save(encoded);
      // Only after the write lands. A reload that races it re-renders the
      // previous payload and then sits on it until the next refresh.
      await _gateway.reload();
      _lastWritten = encoded;
    } catch (e) {
      // Swallowed like BehavioralEventService.log and OpportunityRecorder: a
      // widget that cannot be fed must never take down the schedule the user
      // actually opened the app to read.
      debugPrint('WidgetSyncController: could not update the widget — $e');
    }
  }
}

final widgetSyncControllerProvider = Provider<WidgetSyncController>((ref) {
  return WidgetSyncController(
    gateway: ref.watch(homeWidgetGatewayProvider),
    now: ref.watch(nowProvider),
  );
});

/// Pushes today's summary to the widget whenever the schedule changes.
///
/// The `matchedDayRecorderProvider` shape, for the same reasons: the write
/// lives in a `ref.listen` callback rather than a provider body, because
/// `scheduleMatchProvider` recomputes on every forecast refresh and activity
/// edit and a side effect in its body would fire unpredictably.
///
/// `fireImmediately` is load bearing here too. The forecast usually resolves
/// before the root widget mounts, and a change-only listener would never fire
/// for anyone who did not happen to pull to refresh.
///
/// Nothing watches this provider except `main.dart`; a provider nothing
/// watches never runs.
final widgetSyncProvider = Provider<void>((ref) {
  final controller = ref.watch(widgetSyncControllerProvider);

  ref.listen<AsyncValue<List<ScheduleDay>>>(scheduleMatchProvider, (_, next) {
    final days = next.valueOrNull;
    if (days == null) return;
    // Fahrenheit is the fallback everywhere else the unit is read, and the
    // widget must not disagree with the app it sits next to.
    final unit = ref.read(profileProvider).valueOrNull?.temperatureUnit ?? 'F';
    controller.push(days, unit);
  }, fireImmediately: true);
});
