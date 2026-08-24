import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/features/suggestions/condition_suggestion.dart';

/// 2026-08-23 is "today" for every test here. Answered rows are classified by
/// their outcome alone, so the clock only matters where a test is about an
/// unanswered day.
final _now = DateTime(2026, 8, 23, 12);

int _dayCounter = 0;

/// One decided day, dated far enough back that nothing collides.
///
/// Dates descend from a fixed anchor so each call gets its own civil day —
/// duplicates would be collapsed by the deduplication step and quietly shrink
/// the sample a test thought it built.
ActivityDayOutcome _day({
  required String outcome,
  double windKmh = 10,
  double tempMax = 22,
  double tempMin = 12,
  bool withSnapshot = true,
}) {
  _dayCounter += 1;
  final date = DateTime(2026, 8, 23).subtract(Duration(days: _dayCounter));
  final localDate =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return ActivityDayOutcome(
    userId: 'user-1',
    activityId: 'act-1',
    localDate: localDate,
    outcome: outcome,
    answeredAt: date,
    conditions: withSnapshot
        ? DailyForecast(
            date: date,
            temperatureMax: tempMax,
            temperatureMin: tempMin,
            precipitationProbability: 5,
            windSpeedMax: windKmh,
            weatherCode: 1000,
          ).toJson()
        : null,
  );
}

ActivityDayOutcome _done({
  double windKmh = 10,
  double tempMax = 22,
  double tempMin = 12,
  bool withSnapshot = true,
}) => _day(
  outcome: DayOutcome.done,
  windKmh: windKmh,
  tempMax: tempMax,
  tempMin: tempMin,
  withSnapshot: withSnapshot,
);

ActivityDayOutcome _skipped({
  double windKmh = 10,
  double tempMax = 22,
  double tempMin = 12,
  bool withSnapshot = true,
}) => _day(
  outcome: DayOutcome.skipped,
  windKmh: windKmh,
  tempMax: tempMax,
  tempMin: tempMin,
  withSnapshot: withSnapshot,
);

/// An unanswered day, `daysAgo` before today. Pending inside the grace window,
/// expired outside it.
ActivityDayOutcome _unanswered({required int daysAgo, double windKmh = 30}) {
  final date = DateTime(2026, 8, 23).subtract(Duration(days: daysAgo));
  final localDate =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return ActivityDayOutcome(
    userId: 'user-1',
    activityId: 'act-1',
    localDate: localDate,
    conditions: DailyForecast(
      date: date,
      temperatureMax: 22,
      temperatureMin: 12,
      precipitationProbability: 5,
      windSpeedMax: windKmh,
      weatherCode: 1000,
    ).toJson(),
  );
}

const _windProfile = ConditionProfile(
  id: 'p-1',
  activityId: 'act-1',
  windEnabled: true,
  windMax: 25,
);

ConditionSuggestion? _suggest(
  List<ActivityDayOutcome> rows, {
  ConditionProfile? profile = _windProfile,
  Map<SuggestionDimension, DeclinedSuggestion> declined = const {},
}) => suggestConditionChange(
  profile: profile,
  rows: rows,
  now: _now,
  declined: declined,
);

/// Five done days well inside the limit, plus three skips above them all.
/// Eight eligible days, three qualifying skips: the canonical trigger.
List<ActivityDayOutcome> _windPattern() => [
  _done(windKmh: 8),
  _done(windKmh: 10),
  _done(windKmh: 12),
  _done(windKmh: 9),
  _done(windKmh: 14),
  _skipped(windKmh: 21),
  _skipped(windKmh: 23),
  _skipped(windKmh: 24),
];

void main() {
  setUp(() => _dayCounter = 0);

  group('cold start', () {
    test('says nothing until the activity has enough decided history', () {
      // Seven days with a perfectly clean pattern is still seven days. One bad
      // week must not be enough to start editing the user's settings.
      final rows = _windPattern()..removeAt(0);
      expect(rows, hasLength(7));
      expect(_suggest(rows), isNull);
    });

    test('speaks once the floor is reached', () {
      final rows = _windPattern();
      expect(rows, hasLength(suggestionMinimumDecidedDays));
      expect(_suggest(rows), isNotNull);
    });

    test('reports how much evidence it had', () {
      final suggestion = _suggest([..._windPattern(), _done(windKmh: 11)])!;
      expect(suggestion.eligibleDays, 9);
      expect(suggestion.qualifyingSkips, 3);
    });
  });

  group('eligibility', () {
    test('a day with no snapshot does not count toward the floor', () {
      // Rows written before the conditions column existed. They are real
      // history and they still drive the streak — but the engine cannot see
      // what the weather was, so they cannot be evidence for a weather claim.
      final rows = [
        ..._windPattern()..removeAt(0),
        _done(windKmh: 10, withSnapshot: false),
      ];
      expect(rows, hasLength(8));
      expect(_suggest(rows), isNull);
    });

    test('a pending day is not evidence', () {
      // Unanswered and still answerable. Reading silence as a skip would
      // invent the very preference the feature claims to have observed.
      final rows = [
        ..._windPattern()..removeRange(5, 8),
        _unanswered(daysAgo: 1),
        _unanswered(daysAgo: 2),
        _unanswered(daysAgo: 3),
      ];
      expect(_suggest(rows), isNull);
    });

    test('an expired day is not evidence either', () {
      // Expired counts against the completion rate — silence is an answer once
      // it is old enough — but it still says nothing about *why*. The streak
      // may punish it; the engine may not cite it.
      final rows = [
        ..._windPattern()..removeRange(5, 8),
        _unanswered(daysAgo: 20),
        _unanswered(daysAgo: 21),
        _unanswered(daysAgo: 22),
      ];
      expect(_suggest(rows), isNull);
    });

    test('a day the app never claimed is skipped', () {
      final unmatched = [
        for (var i = 0; i < 3; i++)
          ActivityDayOutcome(
            userId: 'user-1',
            activityId: 'act-1',
            localDate: '2026-07-0${i + 1}',
            matched: false,
            outcome: DayOutcome.skipped,
            answeredAt: DateTime(2026, 7, i + 1),
            conditions: DailyForecast(
              date: DateTime(2026, 7, i + 1),
              temperatureMax: 22,
              temperatureMin: 12,
              precipitationProbability: 5,
              windSpeedMax: 30,
              weatherCode: 1000,
            ).toJson(),
          ),
      ];
      final rows = [..._windPattern()..removeRange(5, 8), ...unmatched];
      expect(_suggest(rows), isNull);
    });

    test('duplicate days for one date collapse to one', () {
      final pattern = _windPattern();
      final duplicated = [...pattern, ...pattern];
      final suggestion = _suggest(duplicated)!;
      expect(suggestion.eligibleDays, 8);
    });

    test('a malformed snapshot is skipped, not thrown on', () {
      // A row written by a build that stored something else. The detail screen
      // must still render.
      final rows = [
        ..._windPattern(),
        ActivityDayOutcome(
          userId: 'user-1',
          activityId: 'act-1',
          localDate: '2026-06-01',
          outcome: DayOutcome.skipped,
          answeredAt: DateTime(2026, 6),
          conditions: const {'unexpected': true},
        ),
      ];
      final suggestion = _suggest(rows)!;
      expect(suggestion.eligibleDays, 8);
    });
  });

  group('pattern floor', () {
    test('two qualifying skips is a coincidence', () {
      final rows = [
        _done(windKmh: 8),
        _done(windKmh: 10),
        _done(windKmh: 12),
        _done(windKmh: 9),
        _done(windKmh: 14),
        _done(windKmh: 11),
        _skipped(windKmh: 23),
        _skipped(windKmh: 24),
      ];
      expect(_suggest(rows), isNull);
    });

    test('three is a pattern', () {
      expect(_suggest(_windPattern())!.qualifyingSkips, 3);
    });

    test('skips below the done ceiling do not qualify', () {
      // Skipped on a calm day. Whatever the reason, it was not the wind — and
      // counting it would let a busy fortnight masquerade as a weather signal.
      final rows = [
        ..._windPattern(),
        _skipped(windKmh: 6),
        _skipped(windKmh: 7),
      ];
      expect(_suggest(rows)!.qualifyingSkips, 3);
    });
  });

  group('purity', () {
    test('one done day inside the band kills the suggestion', () {
      // They went out at 24 km/h once. Any limit that would have excluded the
      // 21 km/h skips would also have excluded that day, so the claim "you
      // never go out above X" is simply false.
      final rows = [..._windPattern(), _done(windKmh: 24)];
      expect(_suggest(rows), isNull);
    });

    test('the suggested limit never excludes a day they went out on', () {
      final rows = [..._windPattern(), _done(windKmh: 19)];
      final suggestion = _suggest(rows);
      if (suggestion != null) {
        expect(suggestion.suggestedValue, greaterThanOrEqualTo(19));
      }
    });
  });

  group('minimum delta', () {
    test('a change smaller than one step is not worth making', () {
      // A limit the user set off the grid. The nearest expressible tightening
      // is 20, a 2 km/h edit — noise dressed as an insight, and not worth
      // spending the one suggestion this activity gets on.
      const profile = ConditionProfile(
        id: 'p-1',
        activityId: 'act-1',
        windEnabled: true,
        windMax: 22,
      );
      final rows = [
        _done(windKmh: 8),
        _done(windKmh: 10),
        _done(windKmh: 12),
        _done(windKmh: 9),
        _done(windKmh: 14),
        _skipped(windKmh: 21),
        _skipped(windKmh: 23),
        _skipped(windKmh: 24),
      ];
      expect(_suggest(rows, profile: profile), isNull);
    });

    test('a change of at least the minimum delta is made', () {
      final suggestion = _suggest(_windPattern())!;
      expect(
        suggestion.currentValue - suggestion.suggestedValue,
        greaterThanOrEqualTo(windSuggestionMinDelta),
      );
    });
  });

  group('rounding', () {
    test('lands on the step and strictly excludes the qualifying skips', () {
      // Skips at 21/23/24 against a limit of 25 — the grid value below 21 is
      // 20, which excludes all three and keeps every done day.
      final suggestion = _suggest(_windPattern())!;
      expect(suggestion.suggestedValue, 20);
      expect(suggestion.suggestedValue % windSuggestionStep, 0);
    });

    test('steps down again when the lowest skip sits exactly on the grid', () {
      final rows = [
        _done(windKmh: 8),
        _done(windKmh: 10),
        _done(windKmh: 12),
        _done(windKmh: 9),
        _done(windKmh: 14),
        _skipped(windKmh: 20),
        _skipped(windKmh: 23),
        _skipped(windKmh: 24),
      ];
      // 20 would still permit the 20 km/h day it is meant to exclude.
      expect(_suggest(rows)!.suggestedValue, 15);
    });

    test(
      'says nothing when the grid leaves no room above the done ceiling',
      () {
        // They went out at 21 and skipped from 22. A limit that excludes the
        // skips has to sit in (21, 22), and there is no multiple of 5 there.
        // Landing on 20 would exclude a day they actually went out on, so the
        // suggestion is dropped rather than expressed off the grid: 21.9 km/h
        // is not a number any user chose.
        final rows = [
          _done(windKmh: 21),
          _done(windKmh: 10),
          _done(windKmh: 12),
          _done(windKmh: 9),
          _done(windKmh: 14),
          _skipped(windKmh: 22),
          _skipped(windKmh: 23),
          _skipped(windKmh: 24),
        ];
        expect(_suggest(rows), isNull);
      },
    );

    test('never suggests a non-positive wind limit', () {
      const profile = ConditionProfile(
        id: 'p-1',
        activityId: 'act-1',
        windEnabled: true,
        windMax: 6,
      );
      final rows = [
        _done(windKmh: 0),
        _done(windKmh: 0),
        _done(windKmh: 0),
        _done(windKmh: 0),
        _done(windKmh: 0),
        _skipped(windKmh: 1),
        _skipped(windKmh: 2),
        _skipped(windKmh: 3),
      ];
      final suggestion = _suggest(rows, profile: profile);
      expect(suggestion?.suggestedValue ?? 1, greaterThan(0));
    });
  });

  group('bounded to what the user already set', () {
    test('says nothing when the activity has no conditions at all', () {
      expect(_suggest(_windPattern(), profile: null), isNull);
    });

    test('never enables a condition the user left off', () {
      // A clean temperature pattern, but only wind is enabled. Enabling
      // temperature would be inventing a preference, not adjusting one.
      const windOnly = ConditionProfile(
        id: 'p-1',
        activityId: 'act-1',
        windEnabled: true,
        windMax: 25,
      );
      final rows = [
        _done(tempMax: 20, tempMin: 12),
        _done(tempMax: 21, tempMin: 13),
        _done(tempMax: 22, tempMin: 14),
        _done(tempMax: 20, tempMin: 12),
        _done(tempMax: 21, tempMin: 13),
        _skipped(tempMax: 38, tempMin: 30),
        _skipped(tempMax: 39, tempMin: 31),
        _skipped(tempMax: 40, tempMin: 32),
      ];
      expect(_suggest(rows, profile: windOnly), isNull);
    });

    test('ignores an enabled flag with no bound behind it', () {
      const unbounded = ConditionProfile(
        id: 'p-1',
        activityId: 'act-1',
        windEnabled: true,
      );
      expect(_suggest(_windPattern(), profile: unbounded), isNull);
    });

    test('never touches precipitation', () {
      // precip_level is a direction, not a threshold, and the 20% cut is a
      // global constant. There is no per-activity number to move, so the
      // engine must never name this dimension.
      const precip = ConditionProfile(
        id: 'p-1',
        activityId: 'act-1',
        precipEnabled: true,
        precipLevel: PrecipLevel.avoidRain,
      );
      expect(_suggest(_windPattern(), profile: precip), isNull);
      expect(
        SuggestionDimension.values.map((d) => d.wireName),
        isNot(contains('precip_level')),
      );
    });

    test('every suggestion tightens, never widens', () {
      const both = ConditionProfile(
        id: 'p-1',
        activityId: 'act-1',
        windEnabled: true,
        windMax: 25,
        tempEnabled: true,
        tempMin: 5,
        tempMax: 35,
      );
      final samples = <List<ActivityDayOutcome>>[
        _windPattern(),
        [
          _done(tempMin: 12),
          _done(tempMin: 13),
          _done(tempMin: 14),
          _done(tempMin: 12),
          _done(tempMin: 13),
          _skipped(tempMin: 30),
          _skipped(tempMin: 31),
          _skipped(tempMin: 32),
        ],
        [
          _done(tempMax: 20),
          _done(tempMax: 21),
          _done(tempMax: 22),
          _done(tempMax: 20),
          _done(tempMax: 21),
          _skipped(tempMax: 8),
          _skipped(tempMax: 7),
          _skipped(tempMax: 6),
        ],
      ];
      for (final rows in samples) {
        _dayCounter = 0;
        final suggestion = suggestConditionChange(
          profile: both,
          rows: rows,
          now: _now,
        );
        if (suggestion == null) continue;
        switch (suggestion.dimension) {
          case SuggestionDimension.windMax:
          case SuggestionDimension.tempMax:
            expect(
              suggestion.suggestedValue,
              lessThan(suggestion.currentValue),
              reason: '${suggestion.dimension} must tighten downward',
            );
          case SuggestionDimension.tempMin:
            expect(
              suggestion.suggestedValue,
              greaterThan(suggestion.currentValue),
              reason: 'tempMin must tighten upward',
            );
        }
      }
    });
  });

  group('temperature', () {
    const tempProfile = ConditionProfile(
      id: 'p-1',
      activityId: 'act-1',
      tempEnabled: true,
      tempMin: 5,
      tempMax: 35,
    );

    test('lowers temp_max when hot days go unused', () {
      // evaluateDayMatch rejects a day when its *minimum* exceeds temp_max, so
      // that is the quantity a temp_max suggestion has to reason about — any
      // other field would produce a limit that fails to exclude the very days
      // it cites.
      final rows = [
        _done(tempMax: 26, tempMin: 16),
        _done(tempMax: 27, tempMin: 17),
        _done(tempMax: 28, tempMin: 18),
        _done(tempMax: 26, tempMin: 16),
        _done(tempMax: 27, tempMin: 17),
        _skipped(tempMax: 40, tempMin: 30),
        _skipped(tempMax: 41, tempMin: 31),
        _skipped(tempMax: 42, tempMin: 32),
      ];
      final suggestion = _suggest(rows, profile: tempProfile)!;
      expect(suggestion.dimension, SuggestionDimension.tempMax);
      expect(suggestion.currentValue, 35);
      expect(suggestion.suggestedValue, 29);
    });

    test('raises temp_min when cold days go unused', () {
      // The mirror image: a day is rejected when its *maximum* falls below
      // temp_min.
      final rows = [
        _done(tempMax: 20, tempMin: 12),
        _done(tempMax: 21, tempMin: 13),
        _done(tempMax: 22, tempMin: 14),
        _done(tempMax: 20, tempMin: 12),
        _done(tempMax: 23, tempMin: 15),
        _skipped(tempMax: 9, tempMin: 2),
        _skipped(tempMax: 8, tempMin: 1),
        _skipped(tempMax: 7, tempMin: 0),
      ];
      final suggestion = _suggest(rows, profile: tempProfile)!;
      expect(suggestion.dimension, SuggestionDimension.tempMin);
      expect(suggestion.currentValue, 5);
      expect(suggestion.suggestedValue, 10);
    });

    test(
      'a two degree change clears the floor, a one degree change does not',
      () {
        final rows = [
          _done(tempMax: 26, tempMin: 16),
          _done(tempMax: 27, tempMin: 17),
          _done(tempMax: 28, tempMin: 34),
          _done(tempMax: 26, tempMin: 16),
          _done(tempMax: 27, tempMin: 17),
          _skipped(tempMax: 40, tempMin: 34.5),
          _skipped(tempMax: 41, tempMin: 35),
          _skipped(tempMax: 42, tempMin: 36),
        ];
        expect(_suggest(rows, profile: tempProfile), isNull);
      },
    );
  });

  group('one at a time', () {
    const everything = ConditionProfile(
      id: 'p-1',
      activityId: 'act-1',
      windEnabled: true,
      windMax: 25,
      tempEnabled: true,
      tempMin: 5,
      tempMax: 35,
    );

    test('returns exactly one suggestion when several bounds qualify', () {
      final rows = [
        _done(windKmh: 8, tempMax: 26, tempMin: 16),
        _done(windKmh: 10, tempMax: 27, tempMin: 17),
        _done(windKmh: 12, tempMax: 28, tempMin: 18),
        _done(windKmh: 9, tempMax: 26, tempMin: 16),
        _done(windKmh: 14, tempMax: 27, tempMin: 17),
        _skipped(windKmh: 21, tempMax: 40, tempMin: 30),
        _skipped(windKmh: 23, tempMax: 41, tempMin: 31),
        _skipped(windKmh: 24, tempMax: 42, tempMin: 32),
      ];
      expect(_suggest(rows, profile: everything), isA<ConditionSuggestion>());
    });

    test('prefers the dimension with more evidence behind it', () {
      final rows = [
        _done(windKmh: 8, tempMin: 16),
        _done(windKmh: 10, tempMin: 17),
        _done(windKmh: 12, tempMin: 18),
        _done(windKmh: 9, tempMin: 16),
        _done(windKmh: 14, tempMin: 17),
        // Hot on four days, windy on three of them.
        _skipped(windKmh: 21, tempMin: 30),
        _skipped(windKmh: 23, tempMin: 31),
        _skipped(windKmh: 24, tempMin: 32),
        _skipped(windKmh: 8, tempMin: 33),
      ];
      final suggestion = _suggest(rows, profile: everything)!;
      expect(suggestion.dimension, SuggestionDimension.tempMax);
      expect(suggestion.qualifyingSkips, 4);
    });

    test('breaks a tie deterministically, wind first', () {
      final rows = [
        _done(windKmh: 8, tempMin: 16),
        _done(windKmh: 10, tempMin: 17),
        _done(windKmh: 12, tempMin: 18),
        _done(windKmh: 9, tempMin: 16),
        _done(windKmh: 14, tempMin: 17),
        _skipped(windKmh: 21, tempMin: 30),
        _skipped(windKmh: 23, tempMin: 31),
        _skipped(windKmh: 24, tempMin: 32),
      ];
      final first = _suggest(rows, profile: everything)!;
      _dayCounter = 0;
      final second = _suggest(rows.reversed.toList(), profile: everything)!;
      expect(first.dimension, second.dimension);
      expect(first.suggestedValue, second.suggestedValue);
    });
  });

  group('decline suppression', () {
    test('the same suggestion never comes back', () {
      final rows = _windPattern();
      final first = _suggest(rows)!;
      expect(
        _suggest(
          rows,
          declined: {
            first.dimension: (
              qualifyingSkips: first.qualifyingSkips,
              suggestedValue: first.suggestedValue,
            ),
          },
        ),
        isNull,
      );
    });

    test('a decline on one dimension does not silence another', () {
      const everything = ConditionProfile(
        id: 'p-1',
        activityId: 'act-1',
        windEnabled: true,
        windMax: 25,
        tempEnabled: true,
        tempMin: 5,
        tempMax: 35,
      );
      final rows = [
        _done(windKmh: 8, tempMin: 16),
        _done(windKmh: 10, tempMin: 17),
        _done(windKmh: 12, tempMin: 18),
        _done(windKmh: 9, tempMin: 16),
        _done(windKmh: 14, tempMin: 17),
        _skipped(windKmh: 21, tempMin: 30),
        _skipped(windKmh: 23, tempMin: 31),
        _skipped(windKmh: 24, tempMin: 32),
      ];
      final suggestion = _suggest(
        rows,
        profile: everything,
        declined: const {
          SuggestionDimension.windMax: (qualifyingSkips: 3, suggestedValue: 20),
        },
      );
      expect(suggestion, isNotNull);
      expect(suggestion!.dimension, isNot(SuggestionDimension.windMax));
    });

    test('three more qualifying skips is a materially stronger pattern', () {
      final rows = [
        ..._windPattern(),
        _skipped(windKmh: 22),
        _skipped(windKmh: 26),
        _skipped(windKmh: 27),
      ];
      final suggestion = _suggest(
        rows,
        declined: const {
          SuggestionDimension.windMax: (qualifyingSkips: 3, suggestedValue: 20),
        },
      );
      expect(suggestion, isNotNull);
      expect(suggestion!.qualifyingSkips, 6);
    });

    test('two more qualifying skips is not enough', () {
      final rows = [..._windPattern(), _skipped(windKmh: 26)];
      expect(
        _suggest(
          rows,
          declined: const {
            SuggestionDimension.windMax: (
              qualifyingSkips: 3,
              suggestedValue: 20,
            ),
          },
        ),
        isNull,
      );
    });

    test('a materially different value is a different question', () {
      // Same three skips, but they have moved far enough down that the ask is
      // no longer the one that was refused.
      final rows = [
        _done(windKmh: 5),
        _done(windKmh: 6),
        _done(windKmh: 7),
        _done(windKmh: 5),
        _done(windKmh: 6),
        _skipped(windKmh: 11),
        _skipped(windKmh: 13),
        _skipped(windKmh: 14),
      ];
      final suggestion = _suggest(
        rows,
        declined: const {
          SuggestionDimension.windMax: (qualifyingSkips: 3, suggestedValue: 20),
        },
      );
      expect(suggestion, isNotNull);
      expect(suggestion!.suggestedValue, 10);
    });

    test('a value that has barely moved is the same question', () {
      final rows = [
        _done(windKmh: 8),
        _done(windKmh: 10),
        _done(windKmh: 12),
        _done(windKmh: 9),
        _done(windKmh: 14),
        _skipped(windKmh: 16),
        _skipped(windKmh: 23),
        _skipped(windKmh: 24),
      ];
      // Suggests 15 against a declined 20 — one step, below the 2x threshold.
      expect(
        _suggest(
          rows,
          declined: const {
            SuggestionDimension.windMax: (
              qualifyingSkips: 3,
              suggestedValue: 20,
            ),
          },
        ),
        isNull,
      );
    });
  });

  group('SuggestionDimension', () {
    test('wire names are stable — they are logged and persisted', () {
      expect(SuggestionDimension.windMax.wireName, 'wind_max');
      expect(SuggestionDimension.tempMax.wireName, 'temp_max');
      expect(SuggestionDimension.tempMin.wireName, 'temp_min');
    });

    test('round-trips through its wire name', () {
      for (final dimension in SuggestionDimension.values) {
        expect(suggestionDimensionFromWire(dimension.wireName), dimension);
      }
      expect(suggestionDimensionFromWire('uv_max'), isNull);
    });
  });
}
