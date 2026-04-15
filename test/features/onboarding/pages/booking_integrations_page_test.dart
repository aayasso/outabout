import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/onboarding/pages/booking_integrations_page.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

void main() {
  group('BookingIntegrationsPage', () {
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
      required VoidCallback onNext,
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
        child: MaterialApp(
          home: BookingIntegrationsPage(onNext: onNext),
        ),
      );
    }

    testWidgets('renders "Book directly from OutAbout" heading', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Book directly from OutAbout'), findsOneWidget);
    });

    testWidgets('renders OpenTable partner card', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('OpenTable'), findsOneWidget);
    });

    testWidgets('renders 2 "More coming soon" placeholder cards', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('More coming soon'), findsNWidgets(2));
    });

    testWidgets('logs booking_integration_viewed on mount', (tester) async {
      final prefs = await mockPrefs();
      final mockEventService = buildMockEventService();

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () {},
          mockEventService: mockEventService,
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => mockEventService.log('booking_integration_viewed'),
      ).called(1);
    });

    testWidgets('"Continue" CTA calls onNext', (tester) async {
      final prefs = await mockPrefs();
      var nextCalled = false;

      await tester.pumpWidget(
        buildSubject(prefs: prefs, onNext: () => nextCalled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(nextCalled, isTrue);
    });

    testWidgets('"Skip for Now" calls onNext', (tester) async {
      final prefs = await mockPrefs();
      var nextCalled = false;

      await tester.pumpWidget(
        buildSubject(prefs: prefs, onNext: () => nextCalled = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip for Now'));
      await tester.pumpAndSettle();

      expect(nextCalled, isTrue);
    });

    // Parameterized test for all 5 weather themes
    for (final theme in WeatherTheme.values) {
      testWidgets('renders correctly with ${theme.displayName} theme',
          (tester) async {
        final prefs = await mockPrefs();
        final expectedColors = WeatherThemeColors.forTheme(theme);

        await tester.pumpWidget(
          buildSubject(
            prefs: prefs,
            onNext: () {},
            themeOverride: theme,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Book directly from OutAbout'), findsOneWidget);

        final coloredBoxes = tester.widgetList<ColoredBox>(
          find.byType(ColoredBox),
        );
        final backgrounds = coloredBoxes.map((w) => w.color).toList();
        expect(
          backgrounds.any((c) => c == expectedColors.background),
          isTrue,
          reason:
              'Expected background color ${expectedColors.background} for ${theme.displayName} theme',
        );
      });
    }
  });
}
