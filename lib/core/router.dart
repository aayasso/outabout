import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'providers.dart';
import 'theme.dart';
import 'weather_theme_provider.dart';

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final supabase = ref.watch(supabaseClientProvider);
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final onboardingComplete =
          prefs.getBool('onboarding_complete') ?? false;
      final hasSession = supabase.auth.currentUser != null;
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Onboarding is only truly complete when BOTH the flag is set AND
      // a valid auth session exists. If the session has expired or been
      // cleared since the last run, reset the flag and restart onboarding.
      if (onboardingComplete && !hasSession) {
        prefs.setBool('onboarding_complete', false);
        if (!isOnboarding) return '/onboarding';
        return null; // already on onboarding
      }

      if (onboardingComplete && hasSession && isOnboarding) return '/home';
      if (!onboardingComplete && !isOnboarding) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const OnboardingScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: OutAboutAnimations.standardDuration,
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const HomeScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: OutAboutAnimations.standardDuration,
        ),
      ),
    ],
  );
});
