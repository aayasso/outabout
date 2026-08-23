import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/router.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

/// Headline rendered by ValuePropositionPage, the first onboarding page.
const _onboardingHeadline =
    'Never miss perfect weather for the things you love';

void main() {
  group('routerProvider redirect logic', () {
    testWidgets('shows onboarding when onboarding_complete is false', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockSupabase = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentUser).thenReturn(null);
      when(() => mockAuth.onAuthStateChange)
          .thenAnswer((_) => const Stream<AuthState>.empty());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            supabaseClientProvider.overrideWithValue(mockSupabase),
          ],
          child: Builder(
            builder: (context) {
              final container = ProviderScope.containerOf(context);
              final router = container.read(routerProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Onboarding is wired: the real OnboardingScreen renders its
      // first page rather than a placeholder.
      expect(find.text(_onboardingHeadline), findsOneWidget);
    });

    testWidgets(
      'shows home when onboarding_complete is true AND session exists',
      (tester) async {
        SharedPreferences.setMockInitialValues({'onboarding_complete': true});
        final prefs = await SharedPreferences.getInstance();

        final mockSupabase = MockSupabaseClient();
        final mockAuth = MockGoTrueClient();
        final mockUser = MockUser();
        when(() => mockSupabase.auth).thenReturn(mockAuth);
        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockAuth.onAuthStateChange)
            .thenAnswer((_) => const Stream<AuthState>.empty());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              supabaseClientProvider.overrideWithValue(mockSupabase),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final router = container.read(routerProvider);
                return MaterialApp.router(routerConfig: router);
              },
            ),
          ),
        );
        // Not pumpAndSettle: /home hosts the animated weather scene, whose
        // rain and cloud loops never come to rest. Pump past the 300ms route
        // fade instead.
        await tester.pump();
        await tester.pump(OutAboutAnimations.standardDuration);

        expect(find.text('Schedule'), findsWidgets);
      },
    );

    testWidgets(
      'redirects to onboarding when onboarding_complete is true but no session (expired session)',
      (tester) async {
        SharedPreferences.setMockInitialValues({'onboarding_complete': true});
        final prefs = await SharedPreferences.getInstance();

        final mockSupabase = MockSupabaseClient();
        final mockAuth = MockGoTrueClient();
        when(() => mockSupabase.auth).thenReturn(mockAuth);
        when(() => mockAuth.currentUser).thenReturn(null); // No session
        when(() => mockAuth.onAuthStateChange)
            .thenAnswer((_) => const Stream<AuthState>.empty());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              supabaseClientProvider.overrideWithValue(mockSupabase),
            ],
            child: Builder(
              builder: (context) {
                final container = ProviderScope.containerOf(context);
                final router = container.read(routerProvider);
                return MaterialApp.router(routerConfig: router);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should redirect to onboarding, not home
        expect(find.text(_onboardingHeadline), findsOneWidget);

        // Verify the flag was cleared so subsequent launches also go to onboarding
        expect(prefs.getBool('onboarding_complete'), isFalse);
      },
    );
  });
}
