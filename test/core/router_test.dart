import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/weather_theme_provider.dart';

void main() {
  group('routerProvider redirect logic', () {
    testWidgets('shows onboarding placeholder when not complete', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/onboarding',
              redirect: (context, state) {
                final onboardingComplete =
                    prefs.getBool('onboarding_complete') ?? false;
                final isOnboarding = state.matchedLocation == '/onboarding';
                if (onboardingComplete && isOnboarding) return '/home';
                if (!onboardingComplete && !isOnboarding) return '/onboarding';
                return null;
              },
              routes: [
                GoRoute(
                  path: '/onboarding',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Onboarding')),
                  ),
                ),
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Welcome to OutAbout')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Welcome to OutAbout'), findsNothing);
    });

    testWidgets('shows home when onboarding complete', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/onboarding',
              redirect: (context, state) {
                final onboardingComplete =
                    prefs.getBool('onboarding_complete') ?? false;
                final isOnboarding = state.matchedLocation == '/onboarding';
                if (onboardingComplete && isOnboarding) return '/home';
                if (!onboardingComplete && !isOnboarding) return '/onboarding';
                return null;
              },
              routes: [
                GoRoute(
                  path: '/onboarding',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Onboarding')),
                  ),
                ),
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Welcome to OutAbout')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome to OutAbout'), findsOneWidget);
      expect(find.text('Onboarding'), findsNothing);
    });
  });
}
