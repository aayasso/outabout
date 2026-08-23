import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/motion.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/features/activity_detail/widgets/activity_record_section.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/outcomes/outcome_providers.dart';
import 'package:outabout/features/outcomes/outcome_stats.dart';

ActivityDayOutcome _row(
  String localDate, {
  String? outcome,
  bool matched = true,
}) => ActivityDayOutcome(
  userId: 'user-1',
  activityId: 'act-1',
  localDate: localDate,
  matched: matched,
  outcome: outcome,
  answeredAt: outcome == null ? null : DateTime.utc(2026, 8, 23, 18),
);

void main() {
  final now = DateTime(2026, 8, 23, 12);
  const colors = WeatherThemeColors.sunny;

  Widget host({
    required List<ActivityDayOutcome> rows,
    void Function(String, String)? onAnswerDay,
    bool loading = false,
    bool fails = false,
  }) {
    return ProviderScope(
      overrides: [
        weatherThemeColorsProvider.overrideWithValue(colors),
        nowProvider.overrideWithValue(() => now),
        activityOutcomesProvider('act-1').overrideWith((ref) async {
          if (fails) throw Exception('offline');
          if (loading) return Completer<List<ActivityDayOutcome>>().future;
          return rows;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityRecordSection(
              activityId: 'act-1',
              activityName: 'Morning trail run',
              onAnswerDay: onAnswerDay,
            ),
          ),
        ),
      ),
    );
  }

  group('heatMapDays', () {
    test('returns weeks * 7 days ending on today', () {
      final days = heatMapDays(now: now, weeks: heatMapWeeks);

      expect(days, hasLength(heatMapWeeks * 7));
      expect(days.last, '2026-08-23');
      expect(days.first, '2026-06-15');
    });

    test('is strictly ascending with no gaps', () {
      final days = heatMapDays(now: now, weeks: 3);

      for (var i = 1; i < days.length; i++) {
        expect(daysBetweenIsoDates(days[i - 1], days[i]), 1);
      }
    });

    test('spans a DST transition without dropping or repeating a day', () {
      // Ten weeks back from mid-March crosses the spring-forward boundary.
      final days = heatMapDays(now: DateTime(2026, 3, 15, 12), weeks: 10);

      expect(days.toSet(), hasLength(days.length));
      expect(days.last, '2026-03-15');
    });
  });

  group('cell presentation', () {
    test('a completed day is drawn in the interactive accent, not primary', () {
      // primary is a fill meant to carry onPrimary ink; against the card it
      // manages only 2.0:1 on sunny. See the contrast suite.
      expect(
        heatMapFill(OutcomeDayState.done, colors),
        colors.primaryInteractive,
      );
      expect(
        heatMapFill(OutcomeDayState.skipped, colors),
        isNot(colors.primaryInteractive),
      );
    });

    test('a day that never matched is not drawn as a miss', () {
      // It is not a gap in the record — it was never on offer.
      expect(
        heatMapFill(OutcomeDayState.notMatched, colors),
        isNot(heatMapFill(OutcomeDayState.skipped, colors)),
      );
    });

    test('unanswered states are outlined so they are visible when empty', () {
      expect(heatMapNeedsOutline(OutcomeDayState.pending), isTrue);
      expect(heatMapNeedsOutline(OutcomeDayState.expired), isTrue);
      expect(heatMapNeedsOutline(OutcomeDayState.done), isFalse);
    });

    test('every state has a distinct spoken label', () {
      String label(OutcomeDayState state) => heatMapCellLabel(
        localDate: '2026-08-18',
        state: state,
        activityName: 'Morning trail run',
      );

      final labels = OutcomeDayState.values.map(label).toSet();
      expect(labels, hasLength(OutcomeDayState.values.length));
      expect(label(OutcomeDayState.done), contains('you went'));
      expect(label(OutcomeDayState.skipped), contains('you did not go'));
      expect(label(OutcomeDayState.pending), contains('Tap to answer'));
      expect(label(OutcomeDayState.notMatched), contains('no match'));
    });

    test('labels name the weekday and month, not a bare number', () {
      expect(readableDate('2026-08-23'), 'Sunday 23 August');
      expect(readableDate('2026-01-01'), 'Thursday 1 January');
    });
  });

  group('stats', () {
    testWidgets('shows an em dash rather than 0% when nothing is decided', (
      tester,
    ) async {
      await tester.pumpWidget(host(rows: [_row('2026-08-23')]));
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(find.text('No days decided yet'), findsOneWidget);
    });

    testWidgets('reports the rate, streaks and total', (tester) async {
      await tester.pumpWidget(
        host(
          rows: [
            _row('2026-08-20', outcome: DayOutcome.done),
            _row('2026-08-21', outcome: DayOutcome.skipped),
            _row('2026-08-22', outcome: DayOutcome.done),
            _row('2026-08-23', outcome: DayOutcome.done),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('of 4 chances taken'), findsOneWidget);
      expect(find.text('Current streak'), findsOneWidget);
      // Current 2 (after the skip), best 2, total 3.
      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('counts up to the numbers on first render', (tester) async {
      await tester.pumpWidget(
        host(rows: [_row('2026-08-23', outcome: DayOutcome.done)]),
      );
      await tester.pump();

      // Mid-flight the tween has not arrived yet.
      expect(find.text('100%'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
    });
  });

  group('heat map', () {
    testWidgets('renders one cell per day of the window', (tester) async {
      await tester.pumpWidget(
        host(rows: [_row('2026-08-23', outcome: DayOutcome.done)]),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp('conditions matched, you went')),
        findsOneWidget,
      );
      expect(find.text('Last $heatMapWeeks weeks'), findsOneWidget);
    });

    testWidgets('a pending day is tappable and answers retroactively', (
      tester,
    ) async {
      final answered = <({String date, String outcome})>[];
      await tester.pumpWidget(
        host(
          rows: [_row('2026-08-22')],
          onAnswerDay: (date, outcome) =>
              answered.add((date: date, outcome: outcome)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsLabel(RegExp('no answer yet')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Did you go on Saturday 22 August?'), findsOneWidget);
      await tester.tap(find.text('Yes, I went'));
      await tester.pumpAndSettle();

      expect(answered.single.date, '2026-08-22');
      expect(answered.single.outcome, DayOutcome.done);
    });

    testWidgets('an expired day is not tappable', (tester) async {
      // Past the grace window: the app must not offer a door that no longer
      // leads anywhere, or the streak maths and the UI disagree.
      final answered = <String>[];
      await tester.pumpWidget(
        host(
          rows: [_row('2026-08-01')],
          onAnswerDay: (date, _) => answered.add(date),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsLabel(RegExp('never answered')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Did you go on'), findsNothing);
      expect(answered, isEmpty);
    });
  });

  group('loading and failure', () {
    testWidgets('shows a still skeleton while the history loads', (
      tester,
    ) async {
      await tester.pumpWidget(host(rows: const [], loading: true));
      await tester.pump();

      expect(find.byType(MotionSafeShimmer), findsOneWidget);
    });

    testWidgets('a failed history does not take the screen down', (
      tester,
    ) async {
      await tester.pumpWidget(host(rows: const [], fails: true));
      await tester.pumpAndSettle();

      expect(
        find.text('Your record for this activity could not be loaded.'),
        findsOneWidget,
      );
    });
  });
}
