import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/core/providers.dart';
import 'package:outabout/features/onboarding/onboarding_screen.dart';
import 'package:outabout/features/home/home_screen.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/services/location_service.dart';
import 'package:outabout/services/notification_service.dart';
import 'package:outabout/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

class MockLocationService extends Mock implements LocationService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockAuthService extends Mock implements AuthService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<SharedPreferences> _mockPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

MockBehavioralEventService _buildMockEventService() {
  final mock = MockBehavioralEventService();
  when(() => mock.log(any(), extra: any(named: 'extra')))
      .thenAnswer((_) async {});
  return mock;
}

MockLocationService _buildMockLocationService() {
  final mock = MockLocationService();
  when(() => mock.requestPermission())
      .thenAnswer((_) async => LocationPermissionResult.granted);
  return mock;
}

MockNotificationService _buildMockNotificationService() {
  final mock = MockNotificationService();
  when(() => mock.requestPermission()).thenAnswer((_) async => true);
  return mock;
}

MockAuthService _buildMockAuthService() {
  final mock = MockAuthService();
  when(() => mock.signInAnonymously())
      .thenAnswer((_) async => AuthResult.failure('mock'));
  when(() => mock.signUpWithEmail(any(), any()))
      .thenAnswer((_) async => AuthResult.failure('mock'));
  when(() => mock.signInWithEmail(any(), any()))
      .thenAnswer((_) async => AuthResult.failure('mock'));
  when(() => mock.sendMagicLink(any()))
      .thenAnswer((_) async => AuthResult.failure('mock'));
  return mock;
}

MockSupabaseClient _buildMockSupabaseClient() {
  final mockSupabase = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();
  when(() => mockSupabase.auth).thenReturn(mockAuth);
  when(() => mockAuth.currentUser).thenReturn(null);
  return mockSupabase;
}

Widget _buildApp({
  required SharedPreferences prefs,
  WeatherTheme? themeOverride,
  MockBehavioralEventService? mockEventService,
  MockLocationService? mockLocationService,
  MockNotificationService? mockNotificationService,
  MockAuthService? mockAuthService,
  MockSupabaseClient? mockSupabaseClient,
}) {
  final eventService = mockEventService ?? _buildMockEventService();
  final locationService = mockLocationService ?? _buildMockLocationService();
  final notificationService =
      mockNotificationService ?? _buildMockNotificationService();
  final authService = mockAuthService ?? _buildMockAuthService();
  final supabaseClient = mockSupabaseClient ?? _buildMockSupabaseClient();

  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (themeOverride != null)
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(themeOverride),
        ),
      behavioralEventServiceProvider.overrideWithValue(eventService),
      locationServiceProvider.overrideWithValue(locationService),
      notificationServiceProvider.overrideWithValue(notificationService),
      authServiceProvider.overrideWithValue(authService),
      supabaseClientProvider.overrideWithValue(supabaseClient),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Pumps enough frames to complete both the PageView animateToPage (300ms)
/// and the flutter_animate entrance animations on the new page.
/// flutter_animate animations never truly settle, so pumpAndSettle is avoided.
Future<void> _pumpPageTransition(WidgetTester tester) async {
  // Pump in increments to ensure async callbacks, post-frame callbacks,
  // and animations all get processed.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Onboarding flow integration', () {
    testWidgets('Full flow happy path — screen 1 through screen 6',
        (tester) async {
      final prefs = await _mockPrefs();
      final mockEventService = _buildMockEventService();
      final mockLocationService = _buildMockLocationService();
      final mockNotificationService = _buildMockNotificationService();
      final mockAuthService = _buildMockAuthService();
      final mockSupabase = _buildMockSupabaseClient();

      await tester.pumpWidget(
        _buildApp(
          prefs: prefs,
          mockEventService: mockEventService,
          mockLocationService: mockLocationService,
          mockNotificationService: mockNotificationService,
          mockAuthService: mockAuthService,
          mockSupabaseClient: mockSupabase,
        ),
      );
      await _pumpPageTransition(tester);

      // ---------------------------------------------------------------
      // Screen 1: Value Proposition
      // ---------------------------------------------------------------
      expect(
        find.text('Never miss perfect weather for the things you love'),
        findsOneWidget,
      );

      await tester.tap(find.text('Get Started'));
      await _pumpPageTransition(tester);

      // Verify onboarding_completed step:1 was logged
      verify(
        () => mockEventService.log(
          'onboarding_completed',
          extra: {'step': 1},
        ),
      ).called(1);

      // ---------------------------------------------------------------
      // Screen 2: Location Permission
      // ---------------------------------------------------------------
      expect(
        find.text('Know what\'s happening near you'),
        findsOneWidget,
      );

      await tester.tap(find.text('Enable Location'));
      await _pumpPageTransition(tester);

      // Verify location permission was requested
      verify(() => mockLocationService.requestPermission()).called(1);

      // Verify onboarding_completed step:2 with permission_granted:true
      verify(
        () => mockEventService.log(
          'onboarding_completed',
          extra: {'step': 2, 'permission_granted': true},
        ),
      ).called(1);

      // ---------------------------------------------------------------
      // Screen 3: Notification Permission
      // ---------------------------------------------------------------
      expect(
        find.text('Get notified when conditions are perfect'),
        findsOneWidget,
      );

      await tester.tap(find.text('Enable Notifications'));
      await _pumpPageTransition(tester);

      // Verify notification permission was requested
      verify(() => mockNotificationService.requestPermission()).called(1);

      // Verify onboarding_completed step:3 with permission_granted:true
      verify(
        () => mockEventService.log(
          'onboarding_completed',
          extra: {'step': 3, 'permission_granted': true},
        ),
      ).called(1);

      // ---------------------------------------------------------------
      // Screen 4: Booking Integrations
      // ---------------------------------------------------------------
      expect(
        find.text('Book directly from OutAbout'),
        findsOneWidget,
      );

      // The booking page logs booking_integration_viewed on mount via
      // addPostFrameCallback — the _pumpPageTransition already triggers it
      verify(
        () => mockEventService.log('booking_integration_viewed'),
      ).called(1);

      await tester.tap(find.text('Continue'));
      await _pumpPageTransition(tester);

      // ---------------------------------------------------------------
      // Screen 5: Auth
      // ---------------------------------------------------------------
      expect(find.text('Create your account'), findsOneWidget);

      // "Skip for Now" may be below the fold on the auth page — scroll to it
      await tester.scrollUntilVisible(
        find.text('Skip for Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Skip for Now" — calls signInAnonymously and logs auth_skipped
      await tester.tap(find.text('Skip for Now'));
      await _pumpPageTransition(tester);

      verify(() => mockAuthService.signInAnonymously()).called(1);
      verify(() => mockEventService.log('auth_skipped')).called(1);

      // ---------------------------------------------------------------
      // Screen 6: First Activity
      // ---------------------------------------------------------------
      expect(
        find.text('What do you love doing outside?'),
        findsOneWidget,
      );

      // Tap "Hiking" category
      await tester.tap(find.text('Hiking'));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify name field is pre-filled with "Hiking"
      final textField = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(textField.controller?.text, 'Hiking');

      // Scroll to "Add to Wishlist" which may be below the fold
      await tester.scrollUntilVisible(
        find.text('Add to Wishlist'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Add to Wishlist" — the Supabase insert throws (unmocked
      // from().insert() chain), but the isolated try/catch lets the rest
      // of the flow complete: events are logged and navigation occurs.
      await tester.tap(find.text('Add to Wishlist'));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify behavioral events were logged despite insert failure
      verify(
        () => mockEventService.log(
          'wishlist_added',
          extra: any(named: 'extra'),
        ),
      ).called(1);
      verify(
        () => mockEventService.log(
          'onboarding_completed',
          extra: {'step': 6},
        ),
      ).called(1);

      // Verify onboarding_complete flag was set
      expect(prefs.getBool('onboarding_complete'), isTrue);
    });

    // -------------------------------------------------------------------
    // Test 2: Theme verification — each theme sets correct background
    // -------------------------------------------------------------------
    for (final theme in WeatherTheme.values) {
      testWidgets(
        'Scaffold background matches ${theme.displayName} theme',
        (tester) async {
          final prefs = await _mockPrefs();
          final expectedColors = WeatherThemeColors.forTheme(theme);

          await tester.pumpWidget(
            _buildApp(prefs: prefs, themeOverride: theme),
          );
          await tester.pump(const Duration(milliseconds: 500));

          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          expect(
            scaffold.backgroundColor,
            expectedColors.background,
            reason:
                'Expected ${expectedColors.background} for ${theme.displayName}',
          );
        },
      );
    }
  });
}
