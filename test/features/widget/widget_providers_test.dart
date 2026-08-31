import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/profile.dart';
import 'package:outabout/data/models/schedule_day.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/widget/widget_gateway.dart';
import 'package:outabout/features/widget/widget_providers.dart';

/// Records what would have crossed the platform channel.
class _FakeGateway implements HomeWidgetGateway {
  final List<String> saved = [];
  int reloads = 0;
  int clears = 0;
  bool throwOnSave = false;
  bool throwOnClear = false;

  @override
  Future<void> save(String payload) async {
    if (throwOnSave) throw Exception('no app group');
    saved.add(payload);
  }

  @override
  Future<void> reload() async => reloads += 1;

  @override
  Future<void> clear() async {
    if (throwOnClear) throw Exception('no app group');
    clears += 1;
  }
}

final _now = DateTime(2026, 8, 23, 12);

DailyForecast _forecast({DateTime? date, int weatherCode = 1001}) =>
    DailyForecast(
      date: date ?? DateTime(2026, 8, 23, 13),
      temperatureMax: 20,
      temperatureMin: 13,
      precipitationProbability: 5,
      windSpeedMax: 12,
      weatherCode: weatherCode,
    );

List<ScheduleDay> _days(List<String> matches, {DateTime? date}) => [
  ScheduleDay(
    forecast: _forecast(date: date),
    matchedActivities: [
      for (final name in matches) Activity(id: name, userId: 'u', name: name),
    ],
  ),
];

void main() {
  late _FakeGateway gateway;

  setUp(() => gateway = _FakeGateway());

  ProviderContainer build({
    AsyncValue<List<ScheduleDay>>? schedule,
    String unit = 'C',
  }) {
    final container = ProviderContainer(
      overrides: [
        homeWidgetGatewayProvider.overrideWithValue(gateway),
        nowProvider.overrideWithValue(() => _now),
        profileProvider.overrideWith(
          (ref) async => Profile(id: 'u', temperatureUnit: unit),
        ),
        scheduleMatchProvider.overrideWith(
          (ref) => schedule ?? AsyncValue.data(_days(const ['Morning Run'])),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Mounts the sync provider and lets its deferred write run.
  Future<void> run(ProviderContainer container) async {
    container.listen(widgetSyncProvider, (_, _) {});
    await container.read(profileProvider.future);
    await Future<void>.delayed(Duration.zero);
  }

  group('WidgetSyncController.clear', () {
    test('wipes the payload so the departing user is not left on screen',
        () async {
      final container = build();
      await run(container);
      expect(gateway.saved, hasLength(1));

      await container.read(widgetSyncControllerProvider).clear();

      expect(gateway.clears, 1);
    });

    test('lets the next user write an identical payload', () async {
      // The dedupe cache has to be reset alongside the wipe. Without it the
      // next sign-in whose schedule happens to encode identically would be
      // deduplicated against the payload that was just cleared, and the widget
      // would sit empty until the forecast changed on its own.
      //
      // Driven through the controller rather than widgetSyncProvider: the
      // provider's first write races profileProvider and lands on the 'F'
      // fallback, which would make this about the unit rather than the cache.
      final container = build();
      final controller = container.read(widgetSyncControllerProvider);

      await controller.push(_days(const ['Morning Run']), 'C');
      expect(gateway.saved, hasLength(1));

      // The dedupe itself: an unchanged payload is not rewritten.
      await controller.push(_days(const ['Morning Run']), 'C');
      expect(gateway.saved, hasLength(1));

      await controller.clear();
      await controller.push(_days(const ['Morning Run']), 'C');

      expect(gateway.saved, hasLength(2));
      expect(gateway.saved.first, gateway.saved.last);
    });

    test('a gateway that cannot be reached does not throw', () async {
      // Same contract as push: the widget must never take down the caller.
      // Here the caller is the sign-out teardown, which has to finish.
      final container = build();
      gateway.throwOnClear = true;

      await expectLater(
        container.read(widgetSyncControllerProvider).clear(),
        completes,
      );
    });
  });

  group('widgetSyncProvider', () {
    test('pushes today to the widget when the schedule resolves', () async {
      final container = build();
      await run(container);

      expect(gateway.saved, hasLength(1));
      final payload = jsonDecode(gateway.saved.single) as Map<String, dynamic>;
      expect(payload['local_date'], '2026-08-23');
      expect(payload['matches'], ['Morning Run']);
    });

    test('reloads the timeline after saving, never before', () async {
      // A reload that races the write shows the previous payload and then
      // sits on it until the next refresh, which can be hours.
      final container = build();
      await run(container);

      expect(gateway.saved, hasLength(1));
      expect(gateway.reloads, 1);
    });

    test('carries the unit resolved from the profile', () async {
      final container = build(unit: 'F');
      await run(container);

      final payload = jsonDecode(gateway.saved.single) as Map<String, dynamic>;
      expect(payload['unit'], 'F');
      expect(payload['temp_high'], 68);
    });

    test('writes nothing while the schedule is still loading', () async {
      final container = build(schedule: const AsyncLoading());
      await run(container);

      expect(gateway.saved, isEmpty);
      expect(gateway.reloads, 0);
    });

    test('writes nothing when the forecast errored', () async {
      // Offline with no cache. The widget keeps its last good payload and
      // says how old it is — better than being blanked by a failed refresh.
      final container = build(
        schedule: AsyncValue.error(Exception('offline'), StackTrace.empty),
      );
      await run(container);

      expect(gateway.saved, isEmpty);
    });

    test('writes nothing when today is not in the forecast', () async {
      final container = build(
        schedule: AsyncValue.data(
          _days(const ['Morning Run'], date: DateTime(2026, 8, 24, 13)),
        ),
      );
      await run(container);

      expect(gateway.saved, isEmpty);
    });

    test('does not rewrite an unchanged payload', () async {
      // scheduleMatchProvider recomputes on every forecast refresh, activity
      // edit and resume. Reloading the timeline each time costs the widget's
      // refresh budget for no visible change.
      final container = build();
      await run(container);
      await run(container);
      await run(container);

      expect(gateway.saved, hasLength(1));
      expect(gateway.reloads, 1);
    });

    test('writes again once the payload actually changes', () async {
      final container = build();
      await run(container);
      expect(gateway.saved, hasLength(1));

      container
          .read(widgetSyncControllerProvider)
          .push(_days(const ['Morning Run', 'Evening Walk']), 'C');
      await Future<void>.delayed(Duration.zero);

      expect(gateway.saved, hasLength(2));
      final payload = jsonDecode(gateway.saved.last) as Map<String, dynamic>;
      expect(payload['match_count'], 2);
    });

    test('a failed write does not take the app down', () async {
      // No App Group provisioned yet is the expected state on a simulator
      // build, and it must read as "the widget has no data" rather than as a
      // crash on every forecast refresh.
      gateway.throwOnSave = true;
      final container = build();

      await run(container);
      expect(gateway.reloads, 0);
    });

    test('a failed write is retried on the next change', () async {
      // The dedupe must not mark a payload as written when it was not, or one
      // transient failure freezes the widget until the payload happens to
      // change again.
      gateway.throwOnSave = true;
      final container = build();
      await run(container);
      expect(gateway.saved, isEmpty);

      gateway.throwOnSave = false;
      container
          .read(widgetSyncControllerProvider)
          .push(_days(const ['Morning Run']), 'C');
      await Future<void>.delayed(Duration.zero);

      expect(gateway.saved, hasLength(1));
    });
  });
}
