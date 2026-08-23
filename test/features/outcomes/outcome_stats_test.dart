import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/features/home/outcome_prompt_provider.dart';
import 'package:outabout/features/outcomes/outcome_stats.dart';

/// A matched day. `matched` defaults true because an opportunity is the only
/// reason a row exists.
ActivityDayOutcome _row(
  String localDate, {
  bool matched = true,
  String? outcome,
  String? reason,
  DateTime? answeredAt,
}) => ActivityDayOutcome(
  userId: 'user-1',
  activityId: 'act-1',
  localDate: localDate,
  matched: matched,
  outcome: outcome,
  reason: reason,
  answeredAt:
      answeredAt ?? (outcome != null ? DateTime.utc(2026, 8, 23, 18) : null),
);

ActivityDayOutcome _done(String d) => _row(d, outcome: DayOutcome.done);
ActivityDayOutcome _skipped(String d) => _row(d, outcome: DayOutcome.skipped);
ActivityDayOutcome _unanswered(String d) => _row(d);

/// Local midday, so a test is never within hours of a day boundary.
DateTime _at(int year, int month, int day) => DateTime(year, month, day, 12);

void main() {
  group('civil date primitives', () {
    test('counts one day across a spring-forward transition', () {
      // US DST starts at 02:00 on 2026-03-08, so local midnight to local
      // midnight across that day is 23 real hours. A Duration-based
      // implementation truncates that to zero and the streak silently treats
      // the two dates as the same day.
      expect(daysBetweenIsoDates('2026-03-08', '2026-03-09'), 1);
    });

    test('counts one day across a fall-back transition', () {
      // The 25-hour day. Truncation happens to round the right way here, so
      // this is a guard rather than a regression — it stops a "fix" that
      // over-corrects by a day in the other direction.
      expect(daysBetweenIsoDates('2026-11-01', '2026-11-02'), 1);
    });

    test('spans a spring-forward transition inside a longer interval', () {
      expect(daysBetweenIsoDates('2026-03-01', '2026-03-15'), 14);
    });

    test('counts across a leap day', () {
      expect(daysBetweenIsoDates('2028-02-28', '2028-03-01'), 2);
    });

    test('counts across a year boundary', () {
      expect(daysBetweenIsoDates('2026-12-30', '2027-01-02'), 3);
    });

    test('is zero for the same date and negative going backwards', () {
      expect(daysBetweenIsoDates('2026-08-23', '2026-08-23'), 0);
      expect(daysBetweenIsoDates('2026-08-23', '2026-08-20'), -3);
    });

    test('localDateKeyOf resolves a UTC instant to the local calendar day', () {
      // The shape Tomorrow.io returns for a forecast day.
      final instant = DateTime.utc(2026, 8, 23, 13);
      expect(localDateKeyOf(instant), localDateKeyOf(instant.toLocal()));
    });

    test('localDateKeyOf reads late-evening local time as that same day', () {
      expect(localDateKeyOf(DateTime(2026, 8, 23, 23, 59)), '2026-08-23');
    });

    test('localDateKeyOf agrees with outcomePromptKey', () {
      // Anti-drift: the prompt and the ledger must name a day identically, or
      // an answer lands on a row the heat map never shows.
      final instant = DateTime.utc(2026, 8, 23, 13);
      expect(
        outcomePromptKey('act-1', instant),
        'act-1|${localDateKeyOf(instant)}',
      );
    });
  });

  group('stateFor', () {
    final now = _at(2026, 8, 23);

    test('an unmatched day is transparent whatever it carries', () {
      expect(
        stateFor(
          _row('2026-08-20', matched: false, outcome: DayOutcome.done),
          now: now,
        ),
        OutcomeDayState.notMatched,
      );
    });

    test('reads done and skipped from the outcome alone', () {
      expect(stateFor(_done('2026-01-01'), now: now), OutcomeDayState.done);
      expect(
        stateFor(_skipped('2026-01-01'), now: now),
        OutcomeDayState.skipped,
      );
    });

    test('today unanswered is pending', () {
      expect(
        stateFor(_unanswered('2026-08-23'), now: now),
        OutcomeDayState.pending,
      );
    });

    test('unanswered at exactly the grace window is still pending', () {
      expect(
        stateFor(_unanswered('2026-08-16'), now: now),
        OutcomeDayState.pending,
      );
    });

    test('unanswered one day past the grace window is expired', () {
      expect(
        stateFor(_unanswered('2026-08-15'), now: now),
        OutcomeDayState.expired,
      );
    });

    test('an unanswered future day is never expired', () {
      expect(
        stateFor(_unanswered('2026-08-25'), now: now),
        OutcomeDayState.future,
      );
    });

    test('a future-dated answer keeps its answer', () {
      // Clock skew must not throw away something the user actually told us.
      expect(stateFor(_done('2026-08-25'), now: now), OutcomeDayState.done);
    });

    test('an unrecognised outcome string reads as unanswered', () {
      expect(
        stateFor(_row('2026-08-23', outcome: 'deferred'), now: now),
        OutcomeDayState.pending,
      );
    });
  });

  group('ordering and de-duplication', () {
    final now = _at(2026, 8, 23);

    test('shuffled input produces the same result as sorted input', () {
      final sorted = [
        _done('2026-08-18'),
        _skipped('2026-08-19'),
        _done('2026-08-20'),
      ];
      final shuffled = [sorted[2], sorted[0], sorted[1]];
      expect(
        computeOutcomeStats(shuffled, now: now),
        computeOutcomeStats(sorted, now: now),
      );
    });

    test('cells come back oldest first', () {
      final cells = classifyOutcomeDays([
        _done('2026-08-20'),
        _done('2026-08-18'),
      ], now: now);
      expect(
        [for (final c in cells) c.localDate],
        ['2026-08-18', '2026-08-20'],
      );
    });

    test(
      'an answered duplicate beats an unanswered one, whatever the order',
      () {
        final answeredLast = [_unanswered('2026-08-20'), _done('2026-08-20')];
        final answeredFirst = [_done('2026-08-20'), _unanswered('2026-08-20')];
        for (final rows in [answeredLast, answeredFirst]) {
          final cells = classifyOutcomeDays(rows, now: now);
          expect(cells, hasLength(1));
          expect(cells.single.state, OutcomeDayState.done);
        }
      },
    );

    test('the later answeredAt wins between two answered duplicates', () {
      final cells = classifyOutcomeDays([
        _row(
          '2026-08-20',
          outcome: DayOutcome.done,
          answeredAt: DateTime.utc(2026, 8, 20, 17),
        ),
        _row(
          '2026-08-20',
          outcome: DayOutcome.skipped,
          answeredAt: DateTime.utc(2026, 8, 20, 21),
        ),
      ], now: now);
      expect(cells.single.state, OutcomeDayState.skipped);
    });

    test('duplicates do not inflate the completion count', () {
      final stats = computeOutcomeStats([
        _done('2026-08-20'),
        _done('2026-08-20'),
        _done('2026-08-20'),
      ], now: now);
      expect(stats.totalCompleted, 1);
    });
  });

  group('computeStreaks', () {
    test('an empty history has no streak', () {
      expect(computeStreaks([]), (current: 0, best: 0));
    });

    test('a single completed day is a streak of one', () {
      expect(computeStreaks([OutcomeDayState.done]), (current: 1, best: 1));
    });

    test('unmatched days are transparent between completions', () {
      // The core rule. A fortnight of rain cannot break a streak.
      expect(
        computeStreaks([
          OutcomeDayState.done,
          OutcomeDayState.notMatched,
          OutcomeDayState.notMatched,
          OutcomeDayState.done,
        ]),
        (current: 2, best: 2),
      );
    });

    test('a skipped day breaks the streak', () {
      expect(
        computeStreaks([
          OutcomeDayState.done,
          OutcomeDayState.done,
          OutcomeDayState.skipped,
        ]),
        (current: 0, best: 2),
      );
    });

    test('an expired day breaks the streak', () {
      expect(
        computeStreaks([
          OutcomeDayState.done,
          OutcomeDayState.done,
          OutcomeDayState.expired,
        ]),
        (current: 0, best: 2),
      );
    });

    test('a pending day between two completions is transparent', () {
      expect(
        computeStreaks([
          OutcomeDayState.done,
          OutcomeDayState.pending,
          OutcomeDayState.done,
        ]),
        (current: 2, best: 2),
      );
    });

    test('a run of pending days is transparent', () {
      expect(
        computeStreaks([
          OutcomeDayState.done,
          OutcomeDayState.pending,
          OutcomeDayState.pending,
          OutcomeDayState.future,
        ]),
        (current: 1, best: 1),
      );
    });

    test('an all-pending history has no streak', () {
      expect(
        computeStreaks([OutcomeDayState.pending, OutcomeDayState.pending]),
        (current: 0, best: 0),
      );
    });

    test('a trailing pending day does not extend the streak', () {
      expect(computeStreaks([OutcomeDayState.done, OutcomeDayState.pending]), (
        current: 1,
        best: 1,
      ));
    });

    test('best survives a break the current streak does not', () {
      expect(
        computeStreaks([
          OutcomeDayState.done,
          OutcomeDayState.done,
          OutcomeDayState.done,
          OutcomeDayState.skipped,
          OutcomeDayState.done,
          OutcomeDayState.done,
        ]),
        (current: 2, best: 3),
      );
    });

    test('an unbroken history has current equal to best', () {
      final streaks = computeStreaks(List.filled(5, OutcomeDayState.done));
      expect(streaks.current, streaks.best);
      expect(streaks.current, 5);
    });
  });

  group('expiry at the grace boundary', () {
    // One row set, two clocks. Nothing about the data changes.
    final rows = [
      _done('2026-08-10'),
      _unanswered('2026-08-11'),
      _done('2026-08-12'),
    ];

    test('the streak stands while the unanswered day is inside the window', () {
      final stats = computeOutcomeStats(rows, now: _at(2026, 8, 18));
      expect(stats.currentStreak, 2);
      expect(stats.totalExpired, 0);
    });

    test('the streak breaks the day the unanswered day expires', () {
      final stats = computeOutcomeStats(rows, now: _at(2026, 8, 19));
      expect(stats.currentStreak, 1);
      expect(stats.totalExpired, 1);
    });

    test('expiry breaks only the run through it, leaving best intact', () {
      final stats = computeOutcomeStats([
        _done('2026-08-01'),
        _done('2026-08-02'),
        _done('2026-08-03'),
        _unanswered('2026-08-04'),
        _done('2026-08-20'),
      ], now: _at(2026, 8, 23));
      expect(stats.bestStreak, 3);
      expect(stats.currentStreak, 1);
    });
  });

  group('completion rate', () {
    final now = _at(2026, 8, 23);

    test('is null, not zero, when nothing has been decided', () {
      final stats = computeOutcomeStats([_unanswered('2026-08-23')], now: now);
      expect(stats.completionRate, isNull);
      expect(stats.decidedDays, 0);
    });

    test('is null for an empty history', () {
      expect(computeOutcomeStats([], now: now).completionRate, isNull);
    });

    test('excludes pending days from both sides', () {
      final stats = computeOutcomeStats([
        _done('2026-08-20'),
        _unanswered('2026-08-22'),
      ], now: now);
      expect(stats.decidedDays, 1);
      expect(stats.completionRate, 1.0);
    });

    test('excludes unmatched and future days from both sides', () {
      final stats = computeOutcomeStats([
        _done('2026-08-20'),
        _row('2026-08-21', matched: false),
        _unanswered('2026-08-30'),
      ], now: now);
      expect(stats.decidedDays, 1);
      expect(stats.completionRate, 1.0);
    });

    test('counts an expired day in the denominator only', () {
      final stats = computeOutcomeStats([
        _done('2026-08-22'),
        _unanswered('2026-08-01'),
      ], now: now);
      expect(stats.decidedDays, 2);
      expect(stats.completionRate, 0.5);
    });

    test('is 1.0 when every decided day was completed', () {
      final stats = computeOutcomeStats([
        _done('2026-08-20'),
        _done('2026-08-21'),
      ], now: now);
      expect(stats.completionRate, 1.0);
    });

    test('is 0.0 when every decided day was missed', () {
      final stats = computeOutcomeStats([
        _skipped('2026-08-20'),
        _unanswered('2026-08-01'),
      ], now: now);
      expect(stats.completionRate, 0.0);
    });

    test(
      'a pending day tipping into expiry lowers the rate with no new row',
      () {
        final rows = [_done('2026-08-12'), _unanswered('2026-08-13')];
        expect(
          computeOutcomeStats(rows, now: _at(2026, 8, 20)).completionRate,
          1.0,
        );
        expect(
          computeOutcomeStats(rows, now: _at(2026, 8, 21)).completionRate,
          0.5,
        );
      },
    );
  });

  group('totals', () {
    final now = _at(2026, 8, 23);

    test('counts each state independently', () {
      final stats = computeOutcomeStats([
        _done('2026-08-20'),
        _done('2026-08-21'),
        _skipped('2026-08-22'),
        _unanswered('2026-08-23'),
        _unanswered('2026-08-01'),
        _row('2026-08-19', matched: false),
      ], now: now);
      expect(stats.totalCompleted, 2);
      expect(stats.totalSkipped, 1);
      expect(stats.totalPending, 1);
      expect(stats.totalExpired, 1);
      expect(stats.decidedDays, 4);
    });

    test('an empty history is all zeroes', () {
      final stats = computeOutcomeStats([], now: now);
      expect(stats.totalCompleted, 0);
      expect(stats.currentStreak, 0);
      expect(stats.bestStreak, 0);
      expect(stats.milestone, isNull);
    });
  });

  group('milestones', () {
    test('fires on landing exactly on each threshold', () {
      expect(
        milestoneCrossed(previousCompleted: 0, currentCompleted: 1),
        OutcomeMilestone.first,
      );
      expect(
        milestoneCrossed(previousCompleted: 4, currentCompleted: 5),
        OutcomeMilestone.five,
      );
      expect(
        milestoneCrossed(previousCompleted: 9, currentCompleted: 10),
        OutcomeMilestone.ten,
      );
      expect(
        milestoneCrossed(previousCompleted: 24, currentCompleted: 25),
        OutcomeMilestone.twentyFive,
      );
    });

    test('is silent when the count did not move', () {
      // A refetch recomputes the same total. Re-celebrating on every
      // pull-to-refresh is the failure this prevents.
      expect(
        milestoneCrossed(previousCompleted: 5, currentCompleted: 5),
        isNull,
      );
    });

    test('is silent between thresholds', () {
      expect(
        milestoneCrossed(previousCompleted: 5, currentCompleted: 6),
        isNull,
      );
      expect(
        milestoneCrossed(previousCompleted: 25, currentCompleted: 26),
        isNull,
      );
    });

    test('reports the highest threshold when the count jumps past several', () {
      expect(
        milestoneCrossed(previousCompleted: 4, currentCompleted: 6),
        OutcomeMilestone.five,
      );
      expect(
        milestoneCrossed(previousCompleted: 0, currentCompleted: 12),
        OutcomeMilestone.ten,
      );
    });

    test('is silent when the count decreases', () {
      expect(
        milestoneCrossed(previousCompleted: 10, currentCompleted: 4),
        isNull,
      );
    });

    test('stats report a milestone only on an exact landing', () {
      final now = _at(2026, 8, 23);
      final five = [
        for (var i = 1; i <= 5; i++)
          _done('2026-08-${i.toString().padLeft(2, '0')}'),
      ];
      expect(
        computeOutcomeStats(five, now: now).milestone,
        OutcomeMilestone.five,
      );
      expect(
        computeOutcomeStats([...five, _done('2026-08-06')], now: now).milestone,
        isNull,
      );
    });
  });
}
