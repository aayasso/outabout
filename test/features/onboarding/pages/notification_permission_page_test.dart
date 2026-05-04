import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/onboarding/pages/notification_permission_page.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/services/notification_service.dart';

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  group('NotificationPermissionPage', () {
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

    MockNotificationService buildMockNotificationService({
      bool granted = true,
    }) {
      final mockNotificationService = MockNotificationService();
      when(() => mockNotificationService.requestPermission())
          .thenAnswer((_) async => granted);
      return mockNotificationService;
    }

    Widget buildSubject({
      required VoidCallback onNext,
      SharedPreferences? prefs,
      WeatherTheme? themeOverride,
      MockBehavioralEventService? mockEventService,
      MockNotificationService? mockNotificationService,
    }) {
      final eventService = mockEventService ?? buildMockEventService();
      final notificationService =
          mockNotificationService ?? buildMockNotificationService();
      return ProviderScope(
        overrides: [
          if (prefs != null)
            sharedPreferencesProvider.overrideWithValue(prefs),
          if (themeOverride != null)
            weatherThemeProvider.overrideWith(
              (ref) => WeatherThemeNotifier(themeOverride),
            ),
          behavioralEventServiceProvider.overrideWithValue(eventService),
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: MaterialApp(
          home: NotificationPermissionPage(onNext: onNext),
        ),
      );
    }

    testWidgets('renders title text', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(
        find.text('Get notified when conditions are perfect'),
        findsOneWidget,
      );
    });

    testWidgets('renders Enable Notifications CTA button', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Enable Notifications'), findsOneWidget);
    });

    testWidgets('renders Not Now skip button', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Not Now'), findsOneWidget);
    });

    testWidgets(
        'CTA triggers notification permission request, logs event with permission_granted true, calls onNext',
        (tester) async {
      final prefs = await mockPrefs();
      final mockEventService = buildMockEventService();
      final mockNotificationService =
          buildMockNotificationService(granted: true);
      var nextCalled = false;

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () => nextCalled = true,
          mockEventService: mockEventService,
          mockNotificationService: mockNotificationService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enable Notifications'));
      await tester.pumpAndSettle();

      verify(() => mockNotificationService.requestPermission()).called(1);
      verify(
        () => mockEventService.log(
          'onboarding_completed',
          extra: {'step': 3, 'permission_granted': true},
        ),
      ).called(1);
      expect(nextCalled, isTrue);
    });

    testWidgets(
        'skip advances without requesting permission, logs event with permission_granted false',
        (tester) async {
      final prefs = await mockPrefs();
      final mockEventService = buildMockEventService();
      final mockNotificationService = buildMockNotificationService();
      var nextCalled = false;

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () => nextCalled = true,
          mockEventService: mockEventService,
          mockNotificationService: mockNotificationService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      verifyNever(() => mockNotificationService.requestPermission());
      verify(
        () => mockEventService.log(
          'onboarding_completed',
          extra: {'step': 3, 'permission_granted': false},
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
          find.text('Get notified when conditions are perfect'),
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
