import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/onboarding/pages/auth_page.dart';
import 'package:outabout/services/auth_service.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

class MockUser extends Mock implements User {}

void main() {
  group('AuthPage', () {
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

    MockAuthService buildMockAuthService() {
      final mockAuthService = MockAuthService();
      when(() => mockAuthService.signInAnonymously())
          .thenAnswer((_) async => AuthResult.success(MockUser()));
      when(() => mockAuthService.signUpWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResult.success(MockUser()));
      when(() => mockAuthService.signInWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResult.success(MockUser()));
      when(() => mockAuthService.sendMagicLink(any()))
          .thenAnswer((_) async => AuthResult.success(MockUser()));
      return mockAuthService;
    }

    Widget buildSubject({
      required VoidCallback onNext,
      SharedPreferences? prefs,
      WeatherTheme? themeOverride,
      MockBehavioralEventService? mockEventService,
      MockAuthService? mockAuthService,
    }) {
      final eventService = mockEventService ?? buildMockEventService();
      final authService = mockAuthService ?? buildMockAuthService();
      return ProviderScope(
        overrides: [
          if (prefs != null)
            sharedPreferencesProvider.overrideWithValue(prefs),
          if (themeOverride != null)
            weatherThemeProvider.overrideWith(
              (ref) => WeatherThemeNotifier(themeOverride),
            ),
          behavioralEventServiceProvider.overrideWithValue(eventService),
          authServiceProvider.overrideWithValue(authService),
        ],
        child: MaterialApp(
          home: Scaffold(body: AuthPage(onNext: onNext)),
        ),
      );
    }

    // 1. Renders email text field
    testWidgets('renders email text field', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.keyboardType == TextInputType.emailAddress,
        ),
        findsOneWidget,
      );
    });

    // 2. Renders password text field
    testWidgets('renders password text field', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Password'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText),
        findsOneWidget,
      );
    });

    // 3. Renders "Sign Up" toggle (default selected)
    testWidgets('renders Sign Up toggle as default selected', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Sign Up'), findsWidgets);
      expect(find.text('Create your account'), findsOneWidget);
    });

    // 4. Toggle to "Sign In" mode changes title to "Welcome back"
    testWidgets('toggling to Sign In changes title to Welcome back',
        (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Create your account'), findsNothing);
    });

    // 5. "Sign Up" button calls signUpWithEmail
    testWidgets('Sign Up button calls signUpWithEmail', (tester) async {
      final prefs = await mockPrefs();
      final mockAuth = buildMockAuthService();

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () {},
          mockAuthService: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.keyboardType == TextInputType.emailAddress,
        ),
        'test@test.com',
      );
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText),
        'password123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      verify(() => mockAuth.signUpWithEmail('test@test.com', 'password123'))
          .called(1);
    });

    // 6. In sign-in mode, button calls signInWithEmail
    testWidgets('in sign-in mode, button calls signInWithEmail',
        (tester) async {
      final prefs = await mockPrefs();
      final mockAuth = buildMockAuthService();

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () {},
          mockAuthService: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to sign-in mode
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.keyboardType == TextInputType.emailAddress,
        ),
        'test@test.com',
      );
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText),
        'password123',
      );

      // The button should say "Sign In" now — find the ElevatedButton
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      verify(() => mockAuth.signInWithEmail('test@test.com', 'password123'))
          .called(1);
    });

    // 7. "Use Magic Link Instead" shows email-only, hides password
    testWidgets('Use Magic Link Instead hides password field',
        (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      // Password should be visible initially
      expect(find.text('Password'), findsOneWidget);

      await tester.tap(find.text('Use Magic Link Instead'));
      await tester.pumpAndSettle();

      // Password should be hidden
      expect(find.text('Password'), findsNothing);
      // Email should still be visible
      expect(find.text('Email'), findsOneWidget);
      // Should show "Send Magic Link" button
      expect(find.text('Send Magic Link'), findsOneWidget);
      // Should show "Use Password Instead" toggle
      expect(find.text('Use Password Instead'), findsOneWidget);
    });

    // 8. "Skip for Now" calls signInAnonymously, logs auth_skipped, calls onNext
    testWidgets('Skip for Now calls signInAnonymously and logs auth_skipped',
        (tester) async {
      final prefs = await mockPrefs();
      final mockAuth = buildMockAuthService();
      final mockEventService = buildMockEventService();
      var nextCalled = false;

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () => nextCalled = true,
          mockAuthService: mockAuth,
          mockEventService: mockEventService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip for Now'));
      await tester.pumpAndSettle();

      verify(() => mockAuth.signInAnonymously()).called(1);
      verify(() => mockEventService.log('auth_skipped')).called(1);
      expect(nextCalled, isTrue);
    });

    // 9. Success logs auth_completed, calls onNext
    testWidgets('successful auth logs auth_completed and calls onNext',
        (tester) async {
      final prefs = await mockPrefs();
      final mockAuth = buildMockAuthService();
      final mockEventService = buildMockEventService();
      var nextCalled = false;

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () => nextCalled = true,
          mockAuthService: mockAuth,
          mockEventService: mockEventService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.keyboardType == TextInputType.emailAddress,
        ),
        'test@test.com',
      );
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText),
        'password123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      verify(() => mockEventService.log('auth_completed')).called(1);
      expect(nextCalled, isTrue);
    });

    // 10. Error shows user-friendly message
    testWidgets('error shows user-friendly message', (tester) async {
      final prefs = await mockPrefs();
      final mockAuth = buildMockAuthService();
      when(() => mockAuth.signUpWithEmail(any(), any()))
          .thenAnswer((_) async => AuthResult.failure(
                'An account with this email already exists. Try signing in instead.',
              ));

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () {},
          mockAuthService: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.keyboardType == TextInputType.emailAddress,
        ),
        'test@test.com',
      );
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.obscureText),
        'password123',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'An account with this email already exists. Try signing in instead.',
        ),
        findsOneWidget,
      );
    });

    // 11. Loading state shows shimmer on button
    testWidgets('loading state disables button', (tester) async {
      final prefs = await mockPrefs();
      final mockAuth = buildMockAuthService();
      // Use a Completer so the Future never completes but no timer is pending
      final completer = Completer<AuthResult>();
      when(() => mockAuth.signUpWithEmail(any(), any()))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        buildSubject(
          prefs: prefs,
          onNext: () {},
          mockAuthService: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      // Pump once to enter loading state (don't settle — it will never finish)
      await tester.pump();

      // The button should be in loading state (OnboardingButton with isLoading=true)
      // Verify Skip for Now is disabled (null onPressed)
      final skipButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Skip for Now'),
      );
      expect(skipButton.onPressed, isNull);

      // Complete the future to avoid pending timer issues
      completer.complete(AuthResult.success(MockUser()));
      await tester.pumpAndSettle();
    });

    // 12. All 5 weather themes (parameterized)
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

        expect(find.text('Create your account'), findsOneWidget);

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

    // 13. Email and password fields have accessibility labels
    testWidgets('email and password fields have accessibility labels',
        (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs, onNext: () {}));
      await tester.pumpAndSettle();

      // Check Semantics widgets wrapping the text fields
      final emailSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Email address',
      );
      expect(emailSemantics, findsOneWidget);

      final passwordSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Password',
      );
      expect(passwordSemantics, findsOneWidget);
    });
  });
}
