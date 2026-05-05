import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shimmer/shimmer.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/activity_detail/activity_detail_screen.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/models/activity.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

void main() {
  const testId = 'test-activity-id';

  MockBehavioralEventService buildMockEventService() {
    final mock = MockBehavioralEventService();
    when(() => mock.log(any(), extra: any(named: 'extra')))
        .thenAnswer((_) async {});
    return mock;
  }

  Widget buildSubject({
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(
          WeatherThemeColors.sunny,
        ),
        behavioralEventServiceProvider
            .overrideWithValue(buildMockEventService()),
        ...overrides,
      ],
      child: const MaterialApp(
        home: ActivityDetailScreen(activityId: testId),
      ),
    );
  }

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

        // Complete to avoid pending timer issues.
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
        final testActivity = Activity(
          id: testId,
          userId: 'user-1',
          name: 'Test Activity',
        );

        await tester.pumpWidget(
          buildSubject(
            overrides: [
              activityDetailProvider(testId).overrideWith(
                (ref) async => testActivity,
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Clear the name field
        final nameField = find.byType(TextField).first;
        await tester.enterText(nameField, '');
        await tester.pump();

        // Find Save button and verify it's disabled
        final saveButton = find.widgetWithText(
          ElevatedButton,
          'Save',
        );
        final button =
            tester.widget<ElevatedButton>(saveButton);
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'Save button enabled when name has text',
      (tester) async {
        final testActivity = Activity(
          id: testId,
          userId: 'user-1',
          name: 'Test Activity',
        );

        await tester.pumpWidget(
          buildSubject(
            overrides: [
              activityDetailProvider(testId).overrideWith(
                (ref) async => testActivity,
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        final saveButton = find.widgetWithText(
          ElevatedButton,
          'Save',
        );
        final button =
            tester.widget<ElevatedButton>(saveButton);
        expect(button.onPressed, isNotNull);
      },
    );
  });
}
