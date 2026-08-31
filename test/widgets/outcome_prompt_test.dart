import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/behavioral_event.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/data/repositories/activity_day_outcome_repository.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/outcomes/outcome_providers.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/widgets/outcome_prompt.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

/// Hand-written rather than mocked, for the reason the postgrest fake in
/// activity_repository_test.dart gives: these methods are awaited inside a
/// widget callback, and a mocktail stub's answer futures are one more moving
/// part between the tap and the frame.
class _StubOutcomeRepository implements ActivityDayOutcomeRepository {
  List<ActivityDayOutcome> rows = [];

  /// When true every read and write throws, standing in for being offline or
  /// for a schema the shipped build has run ahead of.
  bool fails = false;
  final List<({String outcome, String localDate, String? reason})> answers = [];

  @override
  Future<List<ActivityDayOutcome>> fetchForActivity(
    String userId,
    String activityId,
  ) async {
    if (fails) throw Exception('relation does not exist');
    return rows;
  }

  @override
  Future<void> recordMatchedDays(List<ActivityDayOutcome> rows) async {}

  @override
  Future<void> answer({
    required String userId,
    required String activityId,
    required String localDate,
    required String outcome,
    required DateTime answeredAt,
    String? reason,
  }) async {
    answers.add((outcome: outcome, localDate: localDate, reason: reason));
    // Behaves like the upsert it stands in for: the next fetch sees the
    // answer. Without this the before and after completion counts are
    // identical and no milestone could ever be crossed.
    rows = [
      ...rows.where((row) => row.localDate != localDate),
      ActivityDayOutcome(
        userId: userId,
        activityId: activityId,
        localDate: localDate,
        outcome: outcome,
        reason: reason,
        answeredAt: answeredAt,
      ),
    ];
  }
}

class _RecordingEventService extends BehavioralEventService {
  _RecordingEventService()
    : super(
        supabase: _MockSupabaseClient(),
        activeThemeName: () => 'sunny',
        geographicContext: () => const GeographicContext(
          metro: '',
          city: '',
          state: '',
          country: '',
          latBucketed: 0.0,
          lngBucketed: 0.0,
          timezone: '',
        ),
        appVersion: () => 'test',
      );

  final List<
    ({String type, ConditionsAtEvent? conditions, Map<String, dynamic>? extra})
  >
  logged = [];

  @override
  Future<void> log(
    String eventType, {
    Map<String, dynamic>? extra,
    ConditionsAtEvent? conditions,
    String? monetizationEventId,
  }) async {
    logged.add((type: eventType, conditions: conditions, extra: extra));
  }
}

void main() {
  late _RecordingEventService events;
  late SharedPreferences prefs;

  final matchedDay = DateTime(2026, 8, 23);
  final forecast = DailyForecast(
    date: matchedDay,
    temperatureMax: 26.0,
    temperatureMin: 14.0,
    precipitationProbability: 18.6,
    windSpeedMax: 12.0,
    weatherCode: 1000,
  );

  late _StubOutcomeRepository outcomes;
  late _MockSupabaseClient client;

  setUp(() async {
    events = _RecordingEventService();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    outcomes = _StubOutcomeRepository();
    client = _MockSupabaseClient();
    final auth = _MockGoTrueClient();
    final user = _MockUser();
    when(() => user.id).thenReturn('user-1');
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
  });

  Widget harness({required DateTime now, bool matchIsConstrained = true}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(client),
        activityDayOutcomeRepositoryProvider.overrideWithValue(outcomes),
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
        nowProvider.overrideWithValue(() => now),
        behavioralEventServiceProvider.overrideWithValue(events),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OutcomePrompt(
            activityId: 'act-1',
            activityName: 'Morning trail run',
            matchedDay: matchedDay,
            matchIsConstrained: matchIsConstrained,
            forecastDay: forecast,
          ),
        ),
      ),
    );
  }

  testWidgets('renders nothing before the threshold hour', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 9)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('renders nothing for a day that is not today', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 25, 18)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('appears in the evening on the matched day', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Not today'), findsOneWidget);
  });

  testWidgets('Yes logs activity_confirmed with the day\'s weather', (
    tester,
  ) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    // The confirmation beat holds the row on a Timer that pumpAndSettle does
    // not advance; without expiring it the test ends with one pending.
    await tester.pump(outcomeCelebrationDuration);
    await tester.pumpAndSettle();

    final outcomeEvents = events.logged.where(
      (e) => e.type == 'activity_confirmed',
    );
    expect(outcomeEvents, hasLength(1));

    // The whole point of the outcome: it carries the conditions it happened
    // under, not a snapshot of zeros.
    final conditions = outcomeEvents.single.conditions;
    expect(conditions, isNotNull);
    expect(conditions!.weatherCode, 1000);
    expect(conditions.tempMaxC, 26.0);
    expect(conditions.precipitationProbability, 19);
  });

  testWidgets('Not today logs condition_match_ignored', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();

    expect(events.logged.single.type, 'condition_match_ignored');
  });

  testWidgets('dismissing settles the prompt without logging an outcome', (
    tester,
  ) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(RegExp('^Dismiss')));
    await tester.pumpAndSettle();

    // A dismissal is not an outcome — recording one either way would be a lie
    // about what the user told us.
    expect(events.logged, isEmpty);
    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('disappears once answered and does not come back', (
    tester,
  ) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    // The confirmation beat holds the row on a Timer that pumpAndSettle does
    // not advance; without expiring it the test ends with one pending.
    await tester.pump(outcomeCelebrationDuration);
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);

    // Rebuild from scratch, same day: still settled, and no second event.
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 20)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
    expect(
      events.logged.where((e) => e.type == 'activity_confirmed'),
      hasLength(1),
    );
  });

  testWidgets('the answer survives a fresh provider container', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    // The confirmation beat holds the row on a Timer that pumpAndSettle does
    // not advance; without expiring it the test ends with one pending.
    await tester.pump(outcomeCelebrationDuration);
    await tester.pumpAndSettle();

    // A brand new ProviderScope reading the same SharedPreferences, which is
    // what an app relaunch looks like.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 19)));
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // The outcome loop: what an answer now does beyond logging an event.
  // -------------------------------------------------------------------------

  testWidgets('Yes records a completed day against the activity', (
    tester,
  ) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.pump(outcomeCelebrationDuration);
    await tester.pumpAndSettle();

    expect(outcomes.answers.single.outcome, DayOutcome.done);
    // The local calendar day, not a UTC instant.
    expect(outcomes.answers.single.localDate, '2026-08-23');
  });

  testWidgets('Yes shows one confirmation beat, then takes itself away', (
    tester,
  ) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    // The reaction is visible before the row goes.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Did you go?'), findsNothing);

    await tester.pump(outcomeCelebrationDuration);
    await tester.pumpAndSettle();

    // And it is gone without the user doing anything.
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('the confirmation names the streak once it is worth naming', (
    tester,
  ) async {
    outcomes.rows = [
      ActivityDayOutcome(
        userId: 'user-1',
        activityId: 'act-1',
        localDate: '2026-08-22',
        outcome: DayOutcome.done,
        answeredAt: DateTime.utc(2026, 8, 22, 18),
      ),
      ActivityDayOutcome(
        userId: 'user-1',
        activityId: 'act-1',
        localDate: '2026-08-23',
        outcome: DayOutcome.done,
        answeredAt: DateTime.utc(2026, 8, 23, 18),
      ),
    ];

    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    // The line lands after submit's read-write-read round trip, which can
    // resolve a microtask after pumpAndSettle has already run dry.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('2 matched days in a row.'), findsOneWidget);

    await tester.pump(outcomeCelebrationDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('the first completion is called out as a milestone', (
    tester,
  ) async {
    // No history at all, so this Yes is the crossing. The stub supplies the
    // resulting row itself, exactly as the upsert would.
    outcomes.rows = [];
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('First one in the books.'), findsOneWidget);
    expect(
      events.logged.map((e) => e.type),
      contains('activity_milestone_reached'),
    );
    final milestone = events.logged
        .firstWhere((e) => e.type == 'activity_milestone_reached')
        .extra;
    expect(milestone!['milestone'], 1);
    expect(milestone['activity_id'], 'act-1');

    await tester.pump(outcomeCelebrationDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('Not today offers reasons and records the skip first', (
    tester,
  ) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();

    // The answer is durable before the chips are even offered — the reason is
    // a bonus question and must never gate the answer.
    expect(outcomes.answers.single.outcome, DayOutcome.skipped);
    for (final reason in outcomeReasons) {
      expect(find.text(reason.label), findsOneWidget);
    }
  });

  testWidgets('a reason chip is logged and patched onto the day', (
    tester,
  ) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Too busy'));
    await tester.pumpAndSettle();

    expect(outcomes.answers.last.reason, 'too_busy');
    expect(events.logged.last.type, 'condition_match_ignored');
    expect(events.logged.last.extra!['reason'], 'too_busy');
    expect(find.text('Too busy'), findsNothing);
  });

  testWidgets('skipping the reasons keeps the answer', (tester) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skip saying why'));
    await tester.pumpAndSettle();

    // Dismissing the chips is not dismissing the answer, and must not log a
    // second event for one answer.
    expect(outcomes.answers.single.outcome, DayOutcome.skipped);
    expect(
      events.logged.where((e) => e.type == 'condition_match_ignored'),
      hasLength(1),
    );
  });

  testWidgets('a failed history write still settles the prompt', (
    tester,
  ) async {
    // The table may be missing or the device offline. The answer is already in
    // behavioral_events, and the confirmation must still take itself away —
    // an exception escaping the handler would leave it on the card forever
    // with no way to dismiss it.
    outcomes.fails = true;

    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('Logged.'), findsOneWidget);

    await tester.pump(outcomeCelebrationDuration);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('a failed history write still records the reason chips', (
    tester,
  ) async {
    outcomes.fails = true;

    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();

    expect(find.text('Too busy'), findsOneWidget);
    await tester.tap(find.text('Too busy'));
    await tester.pumpAndSettle();

    expect(events.logged.last.extra!['reason'], 'too_busy');
  });

  testWidgets('says nothing about an activity that set no conditions', (
    tester,
  ) async {
    // evaluateDayMatch passes these through on every day, so the app never
    // claimed the weather suited them. Asking would contradict the card right
    // above, which reads "no weather conditions set".
    await tester.pumpWidget(
      harness(now: DateTime(2026, 8, 23, 18), matchIsConstrained: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Did you go?'), findsNothing);
  });

  testWidgets('chips and the dismiss control meet the 48dp tap target', (
    tester,
  ) async {
    await tester.pumpWidget(harness(now: DateTime(2026, 8, 23, 18)));
    await tester.pumpAndSettle();

    for (final label in ['Yes', 'Not today']) {
      final size = tester.getSize(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(48.0), reason: label);
      expect(size.width, greaterThanOrEqualTo(48.0), reason: label);
    }

    expect(
      tester.getSize(find.byTooltip(RegExp('^Dismiss'))).height,
      greaterThanOrEqualTo(48.0),
    );
  });
}
