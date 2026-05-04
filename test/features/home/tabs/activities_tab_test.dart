import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/tabs/activities_tab.dart';

void main() {
  group('ActivitiesTab', () {
    testWidgets(
      'shows empty state when no activities',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              weatherThemeProvider.overrideWith(
                (ref) => WeatherThemeNotifier(
                  WeatherTheme.sunny,
                ),
              ),
              weatherThemeColorsProvider.overrideWithValue(
                WeatherThemeColors.sunny,
              ),
              activitiesProvider.overrideWith(
                (ref) async => [],
              ),
              profileProvider.overrideWith(
                (ref) async => null,
              ),
            ],
            child: const MaterialApp(
              home: ActivitiesTab(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Your wishlist is empty'),
          findsOneWidget,
        );
      },
    );
  });
}
