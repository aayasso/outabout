// Widget tests for "When to tell you".
//
// The behaviour worth guarding is the save path. A notification setting that
// appears to take but never reaches the server is the worst failure this
// screen can have: the user believes they have turned something off, and the
// only evidence to the contrary is a push arriving days later.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/notification_preference.dart';
import 'package:outabout/data/repositories/notification_preference_repository.dart';
import 'package:outabout/features/shared/notification_timing_form.dart';
import 'package:outabout/services/behavioral_event_service.dart';

/// Records what was saved, and can be made to fail on demand.
class _RecordingRepo implements NotificationPreferenceRepository {
  _RecordingRepo({this.throwOnSave = false});

  final bool throwOnSave;
  final List<NotificationPreference> saved = [];

  @override
  Future<NotificationPreference> forActivity(String activityId) async =>
      NotificationPreference(activityId: activityId);

  @override
  Future<void> save(NotificationPreference preference) async {
    if (throwOnSave) throw Exception('offline');
    saved.add(preference);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentEventService implements BehavioralEventService {
  @override
  dynamic noSuchMethod(Invocation invocation) async {}
}

void main() {
  const activityId = 'a1';

  Future<_RecordingRepo> pump(
    WidgetTester tester, {
    NotificationPreference? initial,
    bool throwOnSave = false,
  }) async {
    final repo = _RecordingRepo(throwOnSave: throwOnSave);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
          notificationPreferenceRepositoryProvider.overrideWithValue(repo),
          notificationPreferenceProvider(activityId).overrideWith(
            (ref) async =>
                initial ?? const NotificationPreference(activityId: activityId),
          ),
          behavioralEventServiceProvider.overrideWithValue(_SilentEventService()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotificationTimingForm(activityId: activityId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('offers all three nudge kinds', (tester) async {
    // Before this form the server honoured all three and the app exposed none,
    // so lead time was unreachable code.
    await pump(tester);
    expect(find.text('Morning of'), findsOneWidget);
    expect(find.text('The night before'), findsOneWidget);
    expect(find.text('Further ahead'), findsOneWidget);
  });

  testWidgets('states the cadence ceiling rather than leaving it to be found',
      (tester) async {
    await pump(tester);
    expect(find.textContaining('two notifications a day'), findsOneWidget);
  });

  testWidgets('turning a nudge on writes it through', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byType(Switch).at(1)); // night before
    await tester.pumpAndSettle();

    expect(repo.saved, isNotEmpty);
    expect(repo.saved.last.notifyNightBefore, true);
  });

  testWidgets('turning the last nudge OFF is persisted, not dropped',
      (tester) async {
    // The regression that matters. toJson writes every flag explicitly so an
    // upsert cannot leave a previous `true` standing.
    final repo = await pump(tester);
    await tester.tap(find.byType(Switch).first); // morning of, on by default
    await tester.pumpAndSettle();

    expect(repo.saved.last.notifyMorningOf, false);
    expect(repo.saved.last.toJson()['notify_morning_of'], false);
  });

  testWidgets('says plainly when an activity will never be notified',
      (tester) async {
    await pump(
      tester,
      initial: const NotificationPreference(
        activityId: activityId,
        notifyMorningOf: false,
      ),
    );
    expect(find.textContaining("won't be notified"), findsOneWidget);
  });

  testWidgets('a failed save rolls back rather than showing a state the '
      'server does not have', (tester) async {
    await pump(tester, throwOnSave: true);

    expect(tester.widget<Switch>(find.byType(Switch).first).value, true);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save'), findsOneWidget);
    // Back to what the server still holds.
    expect(tester.widget<Switch>(find.byType(Switch).first).value, true);
  });

  testWidgets('the days-ahead stepper stops at its bounds', (tester) async {
    final repo = await pump(
      tester,
      initial: const NotificationPreference(
        activityId: activityId,
        notifyDaysBefore: true,
        daysBeforeCount: maxDaysBeforeCount,
      ),
    );
    expect(find.text('$maxDaysBeforeCount days ahead'), findsOneWidget);

    // The increment button is disabled at the ceiling, so nothing is written.
    final plus = find.widgetWithIcon(IconButton, Icons.add);
    expect(tester.widget<IconButton>(plus).onPressed, isNull);
    expect(repo.saved, isEmpty);
  });

  testWidgets('the stepper writes a decrement through', (tester) async {
    final repo = await pump(
      tester,
      initial: const NotificationPreference(
        activityId: activityId,
        notifyDaysBefore: true,
        daysBeforeCount: 3,
      ),
    );
    await tester.tap(find.widgetWithIcon(IconButton, Icons.remove));
    await tester.pumpAndSettle();
    expect(repo.saved.last.daysBeforeCount, 2);
  });

  testWidgets('singular day reads correctly', (tester) async {
    await pump(
      tester,
      initial: const NotificationPreference(
        activityId: activityId,
        notifyDaysBefore: true,
        daysBeforeCount: 1,
      ),
    );
    expect(find.text('1 day ahead'), findsOneWidget);
  });
}
