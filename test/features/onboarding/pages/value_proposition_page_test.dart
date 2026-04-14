import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/onboarding/pages/value_proposition_page.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

void main() {
  group('ValuePropositionPage', () {
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
          home: ValuePropositionPage(onNext: onNext),
        ),
      );
    }

    testWidgets('renders headline text', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(
        buildSubject(prefs: prefs, onNext: () {}),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Never miss perfect weather for the things you love'),
        findsOneWidget,
      );
    });

    testWidgets('renders Get Started CTA button', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(
        buildSubject(prefs: prefs, onNext: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('tapping CTA calls the onNext callback', (tester) async {
      final prefs = await mockPrefs();
      var callCount = 0;

      await tester.pumpWidget(
        buildSubject(prefs: prefs, onNext: () => callCount++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets('tapping CTA logs onboarding_completed event', (tester) async {
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

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      verify(() => mockEventService.log(
            'onboarding_completed',
            extra: {'step': 1},
          )).called(1);
    });

    testWidgets('CTA button has accessibility label', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(
        buildSubject(prefs: prefs, onNext: () {}),
      );
      await tester.pumpAndSettle();

      // The button label is itself its semantic label — verify it exists as
      // a semantics node with the correct label.
      final semantics = tester.getSemantics(find.text('Get Started'));
      expect(semantics.label, isNotEmpty);
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

        // Headline should always be present regardless of theme
        expect(
          find.text('Never miss perfect weather for the things you love'),
          findsOneWidget,
        );

        // The page wrapper uses ColoredBox with the theme background
        final coloredBox = tester.widgetList<ColoredBox>(
          find.byType(ColoredBox),
        );
        final backgrounds =
            coloredBox.map((w) => w.color).toList();
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
