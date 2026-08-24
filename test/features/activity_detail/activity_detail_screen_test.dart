import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/activity_detail/activity_detail_screen.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/outcomes/outcome_providers.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

void main() {
  const testId = 'test-activity-id';

  late SharedPreferences prefs;

  setUp(() async {
    // The screen reads prefs transitively now: the suggestion card's
    // declined-suggestion store lives there.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final testActivity = Activity(
    id: testId,
    userId: 'user-1',
    name: 'Test Activity',
  );

  MockBehavioralEventService buildMockEventService() {
    final mock = MockBehavioralEventService();
    when(() => mock.log(
          any(),
          extra: any(named: 'extra'),
          conditions: any(named: 'conditions'),
        )).thenAnswer((_) async {});
    return mock;
  }

  List<Override> baseOverrides({Activity? activity}) => [
        sharedPreferencesProvider.overrideWithValue(prefs),
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(
          WeatherThemeColors.sunny,
        ),
        behavioralEventServiceProvider
            .overrideWithValue(buildMockEventService()),
        categoriesProvider.overrideWith(
          (ref) async => [],
        ),
        activityDetailProvider(testId).overrideWith(
          (ref) async => activity ?? testActivity,
        ),
      ];

  Widget buildSubject({
    List<Override> overrides = const [],
    Activity? activity,
  }) {
    return ProviderScope(
      overrides: [...baseOverrides(activity: activity), ...overrides],
      child: const MaterialApp(
        home: ActivityDetailScreen(activityId: testId),
      ),
    );
  }

  Finder findNameField() =>
      find.widgetWithText(TextField, 'Activity name *');

  Finder findNotesField() =>
      find.widgetWithText(TextField, 'Notes (optional)');

  group('record freshness', () {
    testWidgets('refetches the history every time the screen opens',
        (tester) async {
      // activityOutcomesProvider is a family and is not autoDispose, so its
      // list survives navigation for the whole app run. Before this, the only
      // thing that refreshed it was answering a day — so a day answered on the
      // schedule tab, or recorded as an opportunity while the app was open,
      // did not appear in the heat map until the process restarted.
      var fetches = 0;
      final container = ProviderContainer(
        overrides: [
          ...baseOverrides(),
          activityOutcomesProvider(testId).overrideWith((ref) async {
            fetches += 1;
            return <ActivityDayOutcome>[];
          }),
        ],
      );
      addTearDown(container.dispose);

      // Something already read the history this session and cached it.
      await container.read(activityOutcomesProvider(testId).future);
      expect(fetches, 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ActivityDetailScreen(activityId: testId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fetches, 2, reason: 'opening the screen must refetch');
    });
  });

  group('ActivityDetailScreen', () {
    testWidgets(
      'shows shimmer in loading state',
      (tester) async {
        final completer = Completer<Activity?>();

        await tester.pumpWidget(
          buildSubject(
            overrides: [
              activityDetailProvider(testId).overrideWith(
                (ref) => completer.future,
              ),
            ],
          ),
        );

        await tester.pump();

        expect(find.byType(Shimmer), findsWidgets);

        completer.complete(null);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'shows error state on fetch failure',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            overrides: [
              activityDetailProvider(testId).overrideWith(
                (ref) async =>
                    throw Exception('Network error'),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Something went wrong'),
          findsOneWidget,
        );
        expect(
          find.text('Try again'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows not found when activity is null',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            overrides: [
              activityDetailProvider(testId).overrideWith(
                (ref) async => null,
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Activity not found'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Save button disabled when name is empty',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final nameField = findNameField();
        await tester.enterText(nameField, '');
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'Save button enabled when name has text',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    // -- Form validation tests --

    testWidgets(
      'name over 50 chars shows inline error',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final longName = 'A' * 51;
        await tester.enterText(findNameField(), longName);
        await tester.pump();

        expect(
          find.text('Name must be 50 characters or less'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'notes counter displays correct count when non-empty',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.enterText(
          findNotesField(),
          'Some notes here',
        );
        await tester.pump();

        expect(find.text('15 / 200'), findsOneWidget);
      },
    );

    testWidgets(
      'empty notes shows no counter',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Activity loads with empty notes — no counter
        expect(find.textContaining('/ 200'), findsNothing);
      },
    );

    testWidgets(
      'save button disabled when name exceeds limit '
      'with reason text',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final longName = 'A' * 51;
        await tester.enterText(findNameField(), longName);
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNull);
        expect(
          find.text('Name is too long'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'save button disabled when name is empty '
      'with no reason text',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.enterText(findNameField(), '');
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNull);
        expect(
          find.text('Name is too long'),
          findsNothing,
        );
        expect(
          find.text('Notes exceed 200 characters'),
          findsNothing,
        );
      },
    );
  });
}
