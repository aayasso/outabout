import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/schedule_day.dart';
import 'package:outabout/data/repositories/activity_day_outcome_repository.dart';
import 'package:outabout/features/outcomes/opportunity_recorder.dart';

class _MockRepository extends Mock implements ActivityDayOutcomeRepository {}

/// A profile that actually constrains a day.
ConditionProfile _constraining() => const ConditionProfile(
  id: 'p-1',
  activityId: 'act-1',
  tempEnabled: true,
  tempMin: 10,
);

/// Enabled, but with no bound behind the flag — constrains nothing.
ConditionProfile _unbounded() =>
    const ConditionProfile(id: 'p-2', activityId: 'act-2', tempEnabled: true);

Activity _activity({String? id = 'act-1', ConditionProfile? profile}) =>
    Activity(
      id: id,
      userId: 'user-1',
      name: 'Running',
      conditionProfile: profile,
    );

DailyForecast _forecast(DateTime date) => DailyForecast(
  date: date,
  temperatureMax: 22,
  temperatureMin: 12,
  precipitationProbability: 5,
  windSpeedMax: 8,
  weatherCode: 1000,
);

ScheduleDay _day(DateTime date, List<Activity> matched) =>
    ScheduleDay(forecast: _forecast(date), matchedActivities: matched);

void main() {
  setUpAll(() => registerFallbackValue(<ActivityDayOutcome>[]));

  final now = DateTime(2026, 8, 23, 12);

  group('matchedOpportunitiesForToday', () {
    test('selects only the schedule day that is today locally', () {
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(DateTime(2026, 8, 22), [_activity(profile: _constraining())]),
          _day(DateTime(2026, 8, 23), [_activity(profile: _constraining())]),
          _day(DateTime(2026, 8, 24), [_activity(profile: _constraining())]),
        ],
        now: now,
        userId: 'user-1',
      );

      expect(rows, hasLength(1));
      expect(rows.single.localDate, '2026-08-23');
    });

    test('reads a UTC forecast instant as its local calendar day', () {
      // Tomorrow.io returns days as UTC instants. Comparing .day directly is
      // wrong for most of the world for part of every day.
      final instant = DateTime.utc(2026, 8, 23, 13);
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(instant, [_activity(profile: _constraining())]),
        ],
        now: instant.toLocal(),
        userId: 'user-1',
      );

      expect(
        rows.single.localDate,
        instant.toLocal().toIso8601String().substring(0, 10),
      );
    });

    test('produces nothing for an activity with no condition profile', () {
      // The headline regression. evaluateDayMatch returns true for a null
      // profile, so such an activity is "matched" every single day. Counting
      // those as opportunities would give it a daily unanswered day that
      // expires a week later and permanently zeroes its streak.
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(DateTime(2026, 8, 23), [_activity(profile: null)]),
        ],
        now: now,
        userId: 'user-1',
      );

      expect(rows, isEmpty);
    });

    test('produces nothing for a profile that is enabled but unbounded', () {
      // Strictly stronger than a null check: tempEnabled with no bounds
      // constrains nothing, and a `profile != null` test would wave it through.
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(DateTime(2026, 8, 23), [_activity(profile: _unbounded())]),
        ],
        now: now,
        userId: 'user-1',
      );

      expect(rows, isEmpty);
    });

    test('produces a row for a constraining profile', () {
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(DateTime(2026, 8, 23), [_activity(profile: _constraining())]),
        ],
        now: now,
        userId: 'user-1',
      );

      expect(rows.single.activityId, 'act-1');
      expect(rows.single.userId, 'user-1');
      expect(rows.single.matched, isTrue);
      expect(rows.single.outcome, isNull);
    });

    test('skips an activity with no id', () {
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(DateTime(2026, 8, 23), [
            _activity(id: null, profile: _constraining()),
          ]),
        ],
        now: now,
        userId: 'user-1',
      );

      expect(rows, isEmpty);
    });

    test('produces nothing when today is outside the forecast window', () {
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(DateTime(2026, 8, 24), [_activity(profile: _constraining())]),
        ],
        now: now,
        userId: 'user-1',
      );

      expect(rows, isEmpty);
    });

    test('produces nothing for an empty schedule', () {
      expect(
        matchedOpportunitiesForToday(days: [], now: now, userId: 'user-1'),
        isEmpty,
      );
    });
  });

  group('conditions snapshot', () {
    test('attaches the day forecast to every opportunity it builds', () {
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(DateTime(2026, 8, 23, 13), [
            _activity(profile: _constraining()),
          ]),
        ],
        now: now,
        userId: 'user-1',
      );

      expect(rows, hasLength(1));
      expect(rows.single.conditions, isNotNull);
    });

    test('writes a snapshot DailyForecast.fromJson reads straight back', () {
      // The whole point of storing toJson() verbatim rather than a bespoke
      // shape: the reader already exists, so there is no second parser to keep
      // in step with the first. Wind is the field that would break first — the
      // API sends m/s and the model stores km/h — so assert on it by value.
      final forecast = _forecast(DateTime(2026, 8, 23, 13));
      final rows = matchedOpportunitiesForToday(
        days: [
          ScheduleDay(
            forecast: forecast,
            matchedActivities: [_activity(profile: _constraining())],
          ),
        ],
        now: now,
        userId: 'user-1',
      );

      final restored = DailyForecast.fromJson(rows.single.conditions!);
      expect(restored.windSpeedMax, forecast.windSpeedMax);
      expect(restored.temperatureMax, forecast.temperatureMax);
      expect(restored.temperatureMin, forecast.temperatureMin);
      expect(
        restored.precipitationProbability,
        forecast.precipitationProbability,
      );
      expect(restored.weatherCode, forecast.weatherCode);
    });

    test('gives every activity on one day the same snapshot', () {
      // One forecast, many matched activities. A per-activity divergence here
      // would mean the snapshot came from somewhere other than the day, and
      // it would also break the batch upsert: PostgREST takes the union of
      // keys across a batch, so a payload where some rows carry `conditions`
      // and others do not is not the shape it expects.
      final rows = matchedOpportunitiesForToday(
        days: [
          _day(DateTime(2026, 8, 23, 13), [
            _activity(profile: _constraining()),
            _activity(
              id: 'act-3',
              profile: const ConditionProfile(
                id: 'p-3',
                activityId: 'act-3',
                windEnabled: true,
                windMax: 20,
              ),
            ),
          ]),
        ],
        now: now,
        userId: 'user-1',
      );

      expect(rows, hasLength(2));
      expect(rows.first.conditions, rows.last.conditions);
    });
  });

  group('OpportunityRecorder', () {
    late _MockRepository repository;

    OpportunityRecorder build({String? userId = 'user-1', DateTime? clock}) =>
        OpportunityRecorder(
          repository: repository,
          userId: userId,
          now: () => clock ?? now,
        );

    List<ScheduleDay> todaysSchedule([DateTime? date]) => [
      _day(date ?? DateTime(2026, 8, 23), [
        _activity(profile: _constraining()),
      ]),
    ];

    setUp(() {
      repository = _MockRepository();
      when(() => repository.recordMatchedDays(any())).thenAnswer((_) async {});
    });

    test('writes today\'s opportunities', () async {
      await build().record(todaysSchedule());

      final captured =
          verify(
                () => repository.recordMatchedDays(captureAny()),
              ).captured.single
              as List<ActivityDayOutcome>;
      expect(captured.single.activityId, 'act-1');
    });

    test('is a no-op on a second call with the same day', () async {
      // The schedule recomputes on every forecast refresh and every resume.
      // Without the in-session guard this is a network write each time.
      final recorder = build();
      await recorder.record(todaysSchedule());
      await recorder.record(todaysSchedule());

      verify(() => repository.recordMatchedDays(any())).called(1);
    });

    test('writes again once the local day rolls over', () async {
      final recorder = OpportunityRecorder(
        repository: repository,
        userId: 'user-1',
        now: () => DateTime(2026, 8, 23, 23, 59),
      );
      await recorder.record(todaysSchedule());

      final tomorrow = OpportunityRecorder(
        repository: repository,
        userId: 'user-1',
        now: () => DateTime(2026, 8, 24, 0, 1),
      );
      await tomorrow.record(todaysSchedule(DateTime(2026, 8, 24)));

      verify(() => repository.recordMatchedDays(any())).called(2);
    });

    test(
      'retries after a failed write instead of marking the day recorded',
      () async {
        // Marking on failure would lose the opportunity for good: the day only
        // comes round once, and nothing else ever writes it.
        when(
          () => repository.recordMatchedDays(any()),
        ).thenThrow(Exception('offline'));
        final recorder = build();
        await recorder.record(todaysSchedule());

        when(
          () => repository.recordMatchedDays(any()),
        ).thenAnswer((_) async {});
        await recorder.record(todaysSchedule());

        verify(() => repository.recordMatchedDays(any())).called(2);
      },
    );

    test('swallows repository errors so the schedule still renders', () async {
      when(
        () => repository.recordMatchedDays(any()),
      ).thenThrow(Exception('offline'));

      await expectLater(build().record(todaysSchedule()), completes);
    });

    test('does nothing when no one is signed in', () async {
      await build(userId: null).record(todaysSchedule());

      verifyNever(() => repository.recordMatchedDays(any()));
    });

    test('issues no write when nothing matched today', () async {
      await build().record([
        _day(DateTime(2026, 8, 23), [_activity(profile: null)]),
      ]);

      verifyNever(() => repository.recordMatchedDays(any()));
    });
  });
}
