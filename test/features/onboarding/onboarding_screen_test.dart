import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/onboarding/onboarding_screen.dart';
import 'package:outabout/features/onboarding/widgets/progress_dots.dart';

void main() {
  group('OnboardingScreen', () {
    Future<SharedPreferences> mockPrefs() async {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }

    Widget buildSubject({
      SharedPreferences? prefs,
      WeatherTheme? themeOverride,
    }) {
      return ProviderScope(
        overrides: [
          if (prefs != null)
            sharedPreferencesProvider.overrideWithValue(prefs),
          if (themeOverride != null)
            weatherThemeProvider.overrideWith(
              (ref) => WeatherThemeNotifier(themeOverride),
            ),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
    }

    testWidgets('renders first page (Value Proposition) on launch',
        (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Value Proposition'), findsOneWidget);
    });

    testWidgets('progress dots are rendered at top', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(ProgressDots), findsOneWidget);
    });

    testWidgets('swiping left advances to the next page', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Value Proposition'), findsOneWidget);

      // Swipe left to go to next page — fling with velocity for BouncingScrollPhysics
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Location Permission'), findsOneWidget);
    });

    testWidgets('swiping through all pages works', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      final pageLabels = [
        'Value Proposition',
        'Location Permission',
        'Notification Permission',
        'Booking Integrations',
        'Auth',
        'First Activity',
      ];

      for (var i = 0; i < pageLabels.length; i++) {
        expect(find.text(pageLabels[i]), findsOneWidget,
            reason: 'Page $i (${pageLabels[i]}) should be visible');

        if (i < pageLabels.length - 1) {
          await tester.fling(
              find.byType(PageView), const Offset(-300, 0), 1000);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('scaffold background uses theme color', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      // Default theme is sunny
      expect(scaffold.backgroundColor, WeatherThemeColors.sunny.background);
    });

    // Parameterized test for all 5 themes
    for (final theme in WeatherTheme.values) {
      testWidgets('renders correctly with ${theme.displayName} theme',
          (tester) async {
        final prefs = await mockPrefs();
        final expectedColors = WeatherThemeColors.forTheme(theme);

        await tester.pumpWidget(
            buildSubject(prefs: prefs, themeOverride: theme));
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, expectedColors.background);
      });
    }

    testWidgets('contains a PageView widget', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
