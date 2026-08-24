import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/repositories/activity_repository.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/outcomes/outcome_providers.dart';
import 'package:outabout/features/suggestions/condition_suggestion.dart';
import 'package:outabout/features/suggestions/suggestion_providers.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

class _MockEventService extends Mock implements BehavioralEventService {}

class _FakeActivity extends Fake implements Activity {}

final _now = DateTime(2026, 8, 23, 12);

int _dayCounter = 0;

ActivityDayOutcome _day(String outcome, double windKmh) {
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

/// The canonical trigger: five calm completed days, three windy skips.
List<ActivityDayOutcome> _windPattern() {
  _dayCounter = 0;
  return [
    _day(DayOutcome.done, 8),
    _day(DayOutcome.done, 10),
    _day(DayOutcome.done, 12),
    _day(DayOutcome.done, 9),
    _day(DayOutcome.done, 14),
    _day(DayOutcome.skipped, 21),
    _day(DayOutcome.skipped, 23),
    _day(DayOutcome.skipped, 24),
  ];
}

const _profile = ConditionProfile(
  id: 'p-1',
  activityId: 'act-1',
  windEnabled: true,
  windMax: 25,
  tempEnabled: true,
  tempMin: 5,
  tempMax: 35,
  precipEnabled: true,
  precipLevel: PrecipLevel.avoidRain,
);

final _activity = Activity(
  id: 'act-1',
  userId: 'user-1',
  name: 'Morning Run',
  conditionProfile: _profile,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivity());
    registerFallbackValue(_profile);
  });

  late SharedPreferences prefs;
  late _MockActivityRepository activities;
  late _MockEventService events;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    activities = _MockActivityRepository();
    events = _MockEventService();

    when(
      () => activities.updateWithConditions(any(), any()),
    ).thenAnswer((_) async => _activity);
    when(
      () => events.log(
        any(),
        extra: any(named: 'extra'),
        conditions: any(named: 'conditions'),
      ),
    ).thenAnswer((_) async {});
  });

  // `activity` is Object? with a Symbol sentinel so a test can override it to
  // null — "this activity was deleted" — distinctly from not overriding it.
  ProviderContainer build({
    List<ActivityDayOutcome>? rows,
    Object? activity = #unset,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activityRepositoryProvider.overrideWithValue(activities),
        behavioralEventServiceProvider.overrideWithValue(events),
        nowProvider.overrideWithValue(() => _now),
        activityOutcomesProvider(
          'act-1',
        ).overrideWith((ref) async => rows ?? _windPattern()),
        activityDetailProvider('act-1').overrideWith(
          (ref) async => activity == #unset ? _activity : activity as Activity?,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<ConditionSuggestion?> resolve(ProviderContainer container) async {
    await container.read(activityOutcomesProvider('act-1').future);
    await container.read(activityDetailProvider('act-1').future);
    return container.read(conditionSuggestionProvider('act-1')).valueOrNull;
  }

  group('conditionSuggestionProvider', () {
    test('derives a suggestion from the ledger and the profile', () async {
      final suggestion = await resolve(build());
      expect(suggestion, isNotNull);
      expect(suggestion!.dimension, SuggestionDimension.windMax);
      expect(suggestion.suggestedValue, 20);
    });

    test('is silent for an activity with no conditions', () async {
      final container = build(
        activity: Activity(id: 'act-1', userId: 'user-1', name: 'Morning Run'),
      );
      expect(await resolve(container), isNull);
    });

    test('is silent when there is not enough history', () async {
      expect(await resolve(build(rows: const [])), isNull);
    });

    test('stays loading until the ledger resolves', () {
      final container = build();
      expect(
        container.read(conditionSuggestionProvider('act-1')),
        isA<AsyncLoading<ConditionSuggestion?>>(),
      );
    });
  });

  group('markShown', () {
    test('logs the first time and never again for the same value', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      final controller = container.read(suggestionControllerProvider);

      await controller.markShown('act-1', suggestion);
      await controller.markShown('act-1', suggestion);
      await controller.markShown('act-1', suggestion);

      verify(
        () => events.log(
          suggestionShownEvent,
          extra: any(named: 'extra'),
          conditions: any(named: 'conditions'),
        ),
      ).called(1);
    });

    test('carries the stated and revealed values side by side', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .markShown('act-1', suggestion);

      final captured =
          verify(
                () => events.log(
                  suggestionShownEvent,
                  extra: captureAny(named: 'extra'),
                  conditions: any(named: 'conditions'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(captured['activity_id'], 'act-1');
      expect(captured['dimension'], 'wind_max');
      expect(captured['current_value'], 25.0);
      expect(captured['suggested_value'], 20.0);
      expect(captured['qualifying_skips'], 3);
      expect(captured['eligible_days'], 8);
    });

    test('does not suppress the card', () async {
      // Shown is a logging fact, not a refusal. A suggestion the user has
      // merely seen must still be there when they come back to it.
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .markShown('act-1', suggestion);

      expect(
        container.read(conditionSuggestionProvider('act-1')).valueOrNull,
        isNotNull,
      );
    });
  });

  group('decline', () {
    test('takes the suggestion away immediately', () async {
      final container = build();
      final suggestion = (await resolve(container))!;

      await container
          .read(suggestionControllerProvider)
          .decline('act-1', suggestion);

      expect(
        container.read(conditionSuggestionProvider('act-1')).valueOrNull,
        isNull,
      );
    });

    test('survives a rebuild of the container', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .decline('act-1', suggestion);

      // A fresh container over the same SharedPreferences — the app restarting.
      final restarted = build();
      expect(await resolve(restarted), isNull);
    });

    test('persists the evidence that stood behind the refusal', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .decline('act-1', suggestion);

      final stored =
          jsonDecode(prefs.getString(declinedSuggestionsKey)!)
              as Map<String, dynamic>;
      final record = stored['act-1|wind_max'] as Map<String, dynamic>;
      expect(record['declined_skips'], 3);
      expect(record['declined_value'], 20.0);
    });

    test('logs the refusal', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .decline('act-1', suggestion);

      verify(
        () => events.log(
          suggestionDeclinedEvent,
          extra: any(named: 'extra'),
          conditions: any(named: 'conditions'),
        ),
      ).called(1);
    });

    test('does not silence a different activity', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .decline('act-2', suggestion);

      expect(
        container.read(conditionSuggestionProvider('act-1')).valueOrNull,
        isNotNull,
      );
    });
  });

  group('accept', () {
    test('writes the new bound through the repository', () async {
      final container = build();
      final suggestion = (await resolve(container))!;

      await container
          .read(suggestionControllerProvider)
          .accept(activity: _activity, suggestion: suggestion);

      final saved =
          verify(
                () => activities.updateWithConditions(any(), captureAny()),
              ).captured.single
              as ConditionProfile;
      expect(saved.windMax, 20);
    });

    test('moves one bound and leaves every other field alone', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .accept(activity: _activity, suggestion: suggestion);

      final saved =
          verify(
                () => activities.updateWithConditions(any(), captureAny()),
              ).captured.single
              as ConditionProfile;
      expect(saved.windMax, 20);
      expect(saved.tempMin, _profile.tempMin);
      expect(saved.tempMax, _profile.tempMax);
      expect(saved.tempEnabled, _profile.tempEnabled);
      expect(saved.windEnabled, _profile.windEnabled);
      expect(saved.precipEnabled, _profile.precipEnabled);
      expect(saved.precipLevel, _profile.precipLevel);
      expect(saved.id, _profile.id);
      expect(saved.activityId, _profile.activityId);
    });

    test('returns the saved profile so the form can follow it', () async {
      // The edit form holds its condition state locally and initialises once.
      // Without this the slider would keep showing the old value and write it
      // straight back on the next Save.
      final container = build();
      final suggestion = (await resolve(container))!;
      final updated = await container
          .read(suggestionControllerProvider)
          .accept(activity: _activity, suggestion: suggestion);

      expect(updated.windMax, 20);
    });

    test('logs the acceptance', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .accept(activity: _activity, suggestion: suggestion);

      verify(
        () => events.log(
          suggestionAcceptedEvent,
          extra: any(named: 'extra'),
          conditions: any(named: 'conditions'),
        ),
      ).called(1);
    });

    test('clears an earlier refusal for that dimension', () async {
      final container = build();
      final suggestion = (await resolve(container))!;
      await container
          .read(suggestionControllerProvider)
          .decline('act-1', suggestion);
      await container
          .read(suggestionControllerProvider)
          .accept(activity: _activity, suggestion: suggestion);

      final stored =
          jsonDecode(prefs.getString(declinedSuggestionsKey)!)
              as Map<String, dynamic>;
      expect(stored.containsKey('act-1|wind_max'), isFalse);
    });

    test('refuses an activity that was never saved', () async {
      final container = build();
      final suggestion = (await resolve(container))!;

      expect(
        () => container
            .read(suggestionControllerProvider)
            .accept(
              activity: Activity(
                userId: 'user-1',
                name: 'Unsaved',
                conditionProfile: _profile,
              ),
              suggestion: suggestion,
            ),
        throwsStateError,
      );
    });

    test('lets a failed write surface', () async {
      // Unlike a history write, this one is the thing the user asked for. A
      // silent failure would leave them believing a limit had moved when it
      // had not.
      when(
        () => activities.updateWithConditions(any(), any()),
      ).thenThrow(Exception('offline'));

      final container = build();
      final suggestion = (await resolve(container))!;

      expect(
        () => container
            .read(suggestionControllerProvider)
            .accept(activity: _activity, suggestion: suggestion),
        throwsException,
      );
    });
  });

  group('SuggestionRecordsNotifier', () {
    test('starts clean when the stored value is corrupt', () async {
      // Failing open costs one re-offered suggestion. Failing closed would
      // silence the feature permanently and invisibly.
      SharedPreferences.setMockInitialValues({
        declinedSuggestionsKey: 'not json at all',
      });
      prefs = await SharedPreferences.getInstance();

      expect(await resolve(build()), isNotNull);
    });

    test('ignores a dimension it does not recognise', () async {
      SharedPreferences.setMockInitialValues({
        declinedSuggestionsKey: jsonEncode({
          'act-1|uv_max': {'declined_skips': 3, 'declined_value': 5.0},
        }),
      });
      prefs = await SharedPreferences.getInstance();

      expect(await resolve(build()), isNotNull);
    });

    test('ignores a record with no refusal in it', () async {
      SharedPreferences.setMockInitialValues({
        declinedSuggestionsKey: jsonEncode({
          'act-1|wind_max': {'shown_value': 20.0},
        }),
      });
      prefs = await SharedPreferences.getInstance();

      expect(await resolve(build()), isNotNull);
    });
  });
}
