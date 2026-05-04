import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';

void main() {
  testWidgets(
    'WeatherThemeColors applies to themed widget',
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
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final colors = ref.watch(
                  weatherThemeColorsProvider,
                );
                return Scaffold(
                  backgroundColor: colors.background,
                  body: Text(
                    'OutAbout',
                    style: TextStyle(color: colors.text),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('OutAbout'), findsOneWidget);
    },
  );
}
