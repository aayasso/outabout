import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/onboarding/onboarding_screen.dart';
import 'package:outabout/features/onboarding/widgets/progress_dots.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

void main() {
  group('OnboardingScreen', () {
    Future<SharedPreferences> mockPrefs() async {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }

    MockBehavioralEventService buildMockEventService() {
      final mockEventService = MockBehavioralEventService();
      when(() => mockEventService.log(any(), extra: any(named: 'extra')))
          .thenAnswer((_) async {});
      return mockEventService;
    }

    Widget buildSubject({
      SharedPreferences? prefs,
      WeatherTheme? themeOverride,
      MockBehavioralEventService? mockEventService,
    }) {
      final eventService = mockEventService ?? buildMockEventService();
      return ProviderScope(
        overrides: [
          if (prefs != null)
            sharedPreferencesProvider.overrideWithValue(prefs),
          if (themeOverride != null)
            weatherThemeProvider.overrideWith(
              (ref) => WeatherThemeNotifier(themeOverride),
            ),
          behavioralEventServiceProvider.overrideWithValue(eventService),
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

      expect(
        find.text('Never miss perfect weather for the things you love'),
        findsOneWidget,
      );
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

      expect(
        find.text('Never miss perfect weather for the things you love'),
        findsOneWidget,
      );

      // Swipe left to go to next page — fling with velocity for BouncingScrollPhysics
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Location Permission'), findsOneWidget);
    });

    testWidgets('swiping through all pages works', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      // Page 0: Value Proposition real page
      expect(
        find.text('Never miss perfect weather for the things you love'),
        findsOneWidget,
        reason: 'Page 0 (Value Proposition) should be visible',
      );

      final remainingPageLabels = [
        'Location Permission',
        'Notification Permission',
        'Booking Integrations',
        'Auth',
        'First Activity',
      ];

      for (var i = 0; i < remainingPageLabels.length; i++) {
        await tester.fling(
            find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();

        expect(find.text(remainingPageLabels[i]), findsOneWidget,
            reason:
                'Page ${i + 1} (${remainingPageLabels[i]}) should be visible');
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
