import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/schedule_day.dart';
import 'package:outabout/data/repositories/activity_day_outcome_repository.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/outcomes/outcome_providers.dart';
import 'package:outabout/features/outcomes/outcome_stats.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class _MockRepository extends Mock implements ActivityDayOutcomeRepository {}

class _MockEventService extends Mock implements BehavioralEventService {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

DailyForecast _forecast(DateTime date) => DailyForecast(
  date: date,
  temperatureMax: 22,
  temperatureMin: 12,
  precipitationProbability: 5,
  windSpeedMax: 8,
  weatherCode: 1000,
);

final _activity = Activity(
  id: 'act-1',
  userId: 'user-1',
  name: 'Running',
  conditionProfile: const ConditionProfile(
    id: 'p-1',
    activityId: 'act-1',
    tempEnabled: true,
    tempMin: 10,
  ),
);

ActivityDayOutcome _done(String date) => ActivityDayOutcome(
  userId: 'user-1',
  activityId: 'act-1',
  localDate: date,
  outcome: DayOutcome.done,
  answeredAt: DateTime.utc(2026, 8, 23, 18),
);

void main() {
  setUpAll(() {
    registerFallbackValue(<ActivityDayOutcome>[]);
  });

  final now = DateTime(2026, 8, 23, 18);
  late _MockRepository repository;
  late _MockEventService events;
  late _MockSupabaseClient client;

  setUp(() {
    repository = _MockRepository();
    events = _MockEventService();
    client = _MockSupabaseClient();

    final auth = _MockGoTrueClient();
    final user = _MockUser();
    when(() => user.id).thenReturn('user-1');
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);

    when(() => repository.recordMatchedDays(any())).thenAnswer((_) async {});
    when(
      () => repository.answer(
        userId: any(named: 'userId'),
        activityId: any(named: 'activityId'),
        localDate: any(named: 'localDate'),
        outcome: any(named: 'outcome'),
        answeredAt: any(named: 'answeredAt'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => events.log(
        any(),
        extra: any(named: 'extra'),
        conditions: any(named: 'conditions'),
      ),
    ).thenAnswer((_) async {});
  });

  ProviderContainer build({
    List<ActivityDayOutcome> rows = const [],
    AsyncValue<List<ScheduleDay>>? schedule,
  }) {
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        activityDayOutcomeRepositoryProvider.overrideWithValue(repository),
        behavioralEventServiceProvider.overrideWithValue(events),
        nowProvider.overrideWithValue(() => now),
        activityOutcomesProvider('act-1').overrideWith((ref) async => rows),
        if (schedule != null)
          scheduleMatchProvider.overrideWith((ref) => schedule),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('activityOutcomeStatsProvider', () {
    test('derives stats from the fetched rows', () async {
      final container = build(rows: [_done('2026-08-22'), _done('2026-08-23')]);
      await container.read(activityOutcomesProvider('act-1').future);

      final stats = container
          .read(activityOutcomeStatsProvider('act-1'))
          .valueOrNull!;
      expect(stats.totalCompleted, 2);
      expect(stats.currentStreak, 2);
    });

    test('surfaces the loading state before the fetch resolves', () {
      final container = build();
      expect(
        container.read(activityOutcomeStatsProvider('act-1')),
        isA<AsyncLoading<OutcomeStats>>(),
      );
    });

    test('surfaces an error from the fetch', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          nowProvider.overrideWithValue(() => now),
          activityOutcomesProvider(
            'act-1',
          ).overrideWith((ref) async => throw Exception('offline')),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(activityOutcomesProvider('act-1').future)
          .catchError((_) => <ActivityDayOutcome>[]);

      expect(
        container.read(activityOutcomeStatsProvider('act-1')),
        isA<AsyncError<OutcomeStats>>(),
      );
    });

    test('reads the injected clock, so expiry is testable', () async {
      // Same rows, a clock eight days on: the unanswered day has expired and
      // the streak it was protecting is gone.
      final rows = [
        _done('2026-08-10'),
        ActivityDayOutcome(
          userId: 'user-1',
          activityId: 'act-1',
          localDate: '2026-08-11',
        ),
        _done('2026-08-12'),
      ];

      final inside = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          nowProvider.overrideWithValue(() => DateTime(2026, 8, 18, 12)),
          activityOutcomesProvider('act-1').overrideWith((ref) async => rows),
        ],
      );
      addTearDown(inside.dispose);
      await inside.read(activityOutcomesProvider('act-1').future);
      expect(
        inside
            .read(activityOutcomeStatsProvider('act-1'))
            .valueOrNull!
            .currentStreak,
        2,
      );

      final past = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(client),
          nowProvider.overrideWithValue(() => DateTime(2026, 8, 19, 12)),
          activityOutcomesProvider('act-1').overrideWith((ref) async => rows),
        ],
      );
      addTearDown(past.dispose);
      await past.read(activityOutcomesProvider('act-1').future);
      expect(
        past
            .read(activityOutcomeStatsProvider('act-1'))
            .valueOrNull!
            .currentStreak,
        1,
      );
    });
  });

  group('matchedDayRecorderProvider', () {
    List<ScheduleDay> todaysSchedule() => [
      ScheduleDay(
        forecast: _forecast(DateTime(2026, 8, 23)),
        matchedActivities: [_activity],
      ),
    ];

    test('records immediately when the schedule already holds data', () async {
      // fireImmediately. The forecast usually resolves before the root widget
      // mounts; a change-only listener would never fire and the day would go
      // unrecorded for anyone who did not pull to refresh.
      final container = build(schedule: AsyncData(todaysSchedule()));
      container.read(matchedDayRecorderProvider);
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.recordMatchedDays(any())).called(1);
    });

    test('records nothing while the schedule is still loading', () async {
      final container = build(schedule: const AsyncLoading());
      container.read(matchedDayRecorderProvider);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repository.recordMatchedDays(any()));
    });

    test(
      'does not write twice when the schedule recomputes unchanged',
      () async {
        final container = build(schedule: AsyncData(todaysSchedule()));
        container.read(matchedDayRecorderProvider);
        await Future<void>.delayed(Duration.zero);
        container.read(opportunityRecorderProvider).record(todaysSchedule());
        await Future<void>.delayed(Duration.zero);

        verify(() => repository.recordMatchedDays(any())).called(1);
      },
    );
  });

  group('OutcomeAnswerController', () {
    test('writes the answer for the matched day', () async {
      final container = build();
      await container
          .read(outcomeAnswerControllerProvider)
          .submit(
            activityId: 'act-1',
            matchedDay: DateTime(2026, 8, 23, 9),
            outcome: DayOutcome.done,
          );

      verify(
        () => repository.answer(
          userId: 'user-1',
          activityId: 'act-1',
          localDate: '2026-08-23',
          outcome: 'done',
          answeredAt: now,
          reason: null,
        ),
      ).called(1);
    });

    test('passes a reason chip through to the row', () async {
      final container = build();
      await container
          .read(outcomeAnswerControllerProvider)
          .submit(
            activityId: 'act-1',
            matchedDay: DateTime(2026, 8, 23, 9),
            outcome: DayOutcome.skipped,
            reason: 'too_busy',
          );

      verify(
        () => repository.answer(
          userId: any(named: 'userId'),
          activityId: any(named: 'activityId'),
          localDate: any(named: 'localDate'),
          outcome: 'skipped',
          answeredAt: any(named: 'answeredAt'),
          reason: 'too_busy',
        ),
      ).called(1);
    });

    test(
      'logs a milestone when the completion count crosses a threshold',
      () async {
        // Before the write there are no completions; the refetch returns one.
        var fetched = <ActivityDayOutcome>[];
        final container = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(client),
            activityDayOutcomeRepositoryProvider.overrideWithValue(repository),
            behavioralEventServiceProvider.overrideWithValue(events),
            nowProvider.overrideWithValue(() => now),
            activityOutcomesProvider(
              'act-1',
            ).overrideWith((ref) async => fetched),
          ],
        );
        addTearDown(container.dispose);
        await container.read(activityOutcomesProvider('act-1').future);

        fetched = [_done('2026-08-23')];
        final crossed = await container
            .read(outcomeAnswerControllerProvider)
            .submit(
              activityId: 'act-1',
              matchedDay: DateTime(2026, 8, 23, 9),
              outcome: DayOutcome.done,
            );

        expect(crossed, OutcomeMilestone.first);
        final captured = verify(
          () => events.log(
            captureAny(),
            extra: captureAny(named: 'extra'),
            conditions: any(named: 'conditions'),
          ),
        ).captured;
        expect(captured[0], 'activity_milestone_reached');
        expect((captured[1] as Map)['milestone'], 1);
        expect((captured[1] as Map)['activity_id'], 'act-1');
      },
    );

    test('logs nothing when no threshold is crossed', () async {
      final rows = [_done('2026-08-21'), _done('2026-08-22')];
      final container = build(rows: rows);
      await container.read(activityOutcomesProvider('act-1').future);

      final crossed = await container
          .read(outcomeAnswerControllerProvider)
          .submit(
            activityId: 'act-1',
            matchedDay: DateTime(2026, 8, 23, 9),
            outcome: DayOutcome.skipped,
          );

      expect(crossed, isNull);
      verifyNever(
        () => events.log(
          any(),
          extra: any(named: 'extra'),
          conditions: any(named: 'conditions'),
        ),
      );
    });
  });
}
