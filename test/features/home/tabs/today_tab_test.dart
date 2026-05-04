import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/tabs/today_tab.dart';

void main() {
  group('TodayTab', () {
    Widget buildSubject({
      required List<Override> overrides,
    }) {
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
  });
}
