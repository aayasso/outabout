import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shimmer/shimmer.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/condition_match.dart';
import 'package:outabout/data/models/user_location.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/tabs/today_tab.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class _MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

void main() {
  group('TodayTab', () {
    Widget buildSubject({
      required List<Override> overrides,
    }) {
      final mockEventService =
          _MockBehavioralEventService();
      when(() => mockEventService.log(
            any(),
            extra: any(named: 'extra'),
          )).thenAnswer((_) async {});
      return ProviderScope(
        overrides: [
          weatherThemeProvider.overrideWith(
            (ref) => WeatherThemeNotifier(
              WeatherTheme.sunny,
            ),
          ),
          weatherThemeColorsProvider.overrideWithValue(
            WeatherThemeColors.sunny,
          ),
          behavioralEventServiceProvider
              .overrideWithValue(mockEventService),
          ...overrides,
        ],
        child: const MaterialApp(
          home: TodayTab(),
        ),
      );
    }

    testWidgets(
      'shows shimmer in loading state',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            overrides: [
              conditionMatchProvider.overrideWithValue(
                const AsyncLoading(),
              ),
              weatherDataProvider.overrideWith(
                (ref) async =>
                    throw StateError('loading'),
              ),
              userLocationProvider.overrideWith(
                (ref) async => null,
              ),
            ],
          ),
        );

        await tester.pump();

        expect(
          find.byType(Shimmer),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'shows empty state when activities list is empty',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            overrides: [
              conditionMatchProvider.overrideWithValue(
                const AsyncData([]),
              ),
              weatherDataProvider.overrideWith(
                (ref) async => const WeatherData(
                  weatherCode: 1000,
                  temperature: 20,
                  windSpeed: 5,
                  humidity: 50,
                  precipitationIntensity: 0,
                  uvIndex: 3,
                ),
              ),
              userLocationProvider.overrideWith(
                (ref) async => null,
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Add your first outdoor activity'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows staleness text when fetchedAt is 45 min ago',
      (tester) async {
        final staleTime = DateTime.now().subtract(
          const Duration(minutes: 45),
        );
        final activity = Activity(
          id: '1',
          userId: 'u1',
          name: 'Run',
        );

        await tester.pumpWidget(
          buildSubject(
            overrides: [
              conditionMatchProvider.overrideWithValue(
                AsyncData([
                  ConditionMatch(
                    activity: activity,
                    isMatch: true,
                  ),
                ]),
              ),
              weatherDataProvider.overrideWith(
                (ref) async => WeatherData(
                  weatherCode: 1000,
                  temperature: 20,
                  windSpeed: 5,
                  humidity: 50,
                  precipitationIntensity: 0,
                  uvIndex: 3,
                  fetchedAt: staleTime,
                ),
              ),
              userLocationProvider.overrideWith(
                (ref) async => const UserLocation(
                  userId: 'u1',
                  city: 'Austin, TX',
                  latitude: 30.0,
                  longitude: -97.0,
                ),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining('Updated 45 min ago'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'no staleness text when fetchedAt is null',
      (tester) async {
        final activity = Activity(
          id: '1',
          userId: 'u1',
          name: 'Run',
        );

        await tester.pumpWidget(
          buildSubject(
            overrides: [
              conditionMatchProvider.overrideWithValue(
                AsyncData([
                  ConditionMatch(
                    activity: activity,
                    isMatch: true,
                  ),
                ]),
              ),
              weatherDataProvider.overrideWith(
                (ref) async => const WeatherData(
                  weatherCode: 1000,
                  temperature: 20,
                  windSpeed: 5,
                  humidity: 50,
                  precipitationIntensity: 0,
                  uvIndex: 3,
                ),
              ),
              userLocationProvider.overrideWith(
                (ref) async => const UserLocation(
                  userId: 'u1',
                  city: 'Austin, TX',
                  latitude: 30.0,
                  longitude: -97.0,
                ),
              ),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining('Updated'),
          findsNothing,
        );
      },
    );
  });
}
