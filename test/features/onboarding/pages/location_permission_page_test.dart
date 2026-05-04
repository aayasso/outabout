import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/onboarding/pages/location_permission_page.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/services/location_service.dart';

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

class MockLocationService extends Mock implements LocationService {}

void main() {
  group('LocationPermissionPage', () {
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

    MockLocationService buildMockLocationService({
      LocationPermissionResult result = LocationPermissionResult.granted,
    }) {
      final mockLocationService = MockLocationService();
      when(() => mockLocationService.requestPermission())
          .thenAnswer((_) async => result);
      return mockLocationService;
    }

    Widget buildSubject({
      required VoidCallback onNext,
      SharedPreferences? prefs,
      WeatherTheme? themeOverride,
      MockBehavioralEventService? mockEventService,
      MockLocationService? mockLocationService,
    }) {
      final eventService = mockEventService ?? buildMockEventService();
      final locationService =
          mockLocationService ?? buildMockLocationService();
      return ProviderScope(
        overrides: [
          if (prefs != null)
            sharedPreferencesProvider.overrideWithValue(prefs),
          if (themeOverride != null)
            weatherThemeProvider.overrideWith(
              (ref) => WeatherThemeNotifier(themeOverride),
            ),
          behavioralEventServiceProvider.overrideWithValue(eventService),
          locationServiceProvider.overrideWithValue(locationService),
        ],
        child: MaterialApp(
          home: LocationPermissionPage(onNext: onNext),
        ),
      );
    }

    testWidgets('renders explanation title text', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(
        find.text('Know what\'s happening near you'),
        findsOneWidget,
      );
    });

    testWidgets('renders Enable Location CTA button', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Enable Location'), findsOneWidget);
    });

    testWidgets('renders Not Now skip button', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Not Now'), findsOneWidget);
    });

    testWidgets(
        'CTA triggers location permission request, logs event with permission_granted true, calls onNext',
        (tester) async {
      final prefs = await mockPrefs();
      final mockEventService = buildMockEventService();
      final mockLocationService =
          buildMockLocationService(result: LocationPermissionResult.granted);
      var nextCalled = false;

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () => nextCalled = true,
          mockEventService: mockEventService,
          mockLocationService: mockLocationService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Location'));
      await tester.pumpAndSettle();

      verify(() => mockLocationService.requestPermission()).called(1);
      verify(
        () => mockEventService.log(
          'onboarding_completed',
          extra: {'step': 2, 'permission_granted': true},
        ),
      ).called(1);
      expect(nextCalled, isTrue);
    });

    testWidgets(
        'skip advances without requesting permission, logs event with permission_granted false',
        (tester) async {
      final prefs = await mockPrefs();
      final mockEventService = buildMockEventService();
      final mockLocationService = buildMockLocationService();
      var nextCalled = false;

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () => nextCalled = true,
          mockEventService: mockEventService,
          mockLocationService: mockLocationService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      verifyNever(() => mockLocationService.requestPermission());
      verify(
        () => mockEventService.log(
          'onboarding_completed',
          extra: {'step': 2, 'permission_granted': false},
        ),
      ).called(1);
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

        expect(
          find.text('Know what\'s happening near you'),
          findsOneWidget,
        );

        final coloredBox = tester.widgetList<ColoredBox>(
          find.byType(ColoredBox),
        );
        final backgrounds = coloredBox.map((w) => w.color).toList();
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
