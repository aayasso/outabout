import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import 'theme.dart';
import 'weather_theme_provider.dart';

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GoRouter(
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
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const _PlaceholderOnboardingScreen(),
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

// ---------------------------------------------------------------------------
// Temporary placeholder — will be replaced by Task 11
// ---------------------------------------------------------------------------

class _PlaceholderOnboardingScreen extends ConsumerWidget {
  const _PlaceholderOnboardingScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Text(
          'Onboarding',
          style: OutAboutTypography.headingLarge(colors),
        ),
      ),
    );
  }
}
