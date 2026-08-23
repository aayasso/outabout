import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import 'onboarding_provider.dart';
import 'pages/booking_integrations_page.dart';
import 'pages/location_permission_page.dart';
import 'pages/notification_permission_page.dart';
import 'pages/auth_page.dart';
import 'pages/first_activity_page.dart';
import 'pages/value_proposition_page.dart';
import 'widgets/progress_dots.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final currentStep = ref.watch(onboardingStepProvider);

    // Sync PageController with provider
    ref.listen<int>(onboardingStepProvider, (prev, next) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots at top
            Padding(
              padding: EdgeInsets.only(
                top: OutAboutSpacing.lg,
                bottom: OutAboutSpacing.md,
              ),
              child: ProgressDots(currentPage: currentStep),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  ref.read(onboardingStepProvider.notifier).goTo(index);
                },
                children: [
                  ValuePropositionPage(
                    onNext: () =>
                        ref.read(onboardingStepProvider.notifier).next(),
                  ),
                  LocationPermissionPage(
                    onNext: () =>
                        ref.read(onboardingStepProvider.notifier).next(),
                  ),
                  NotificationPermissionPage(
                    onNext: () =>
                        ref.read(onboardingStepProvider.notifier).next(),
                  ),
                  BookingIntegrationsPage(
                    onNext: () =>
                        ref.read(onboardingStepProvider.notifier).next(),
                  ),
                  AuthPage(
                    onNext: () =>
                        ref.read(onboardingStepProvider.notifier).next(),
                  ),
                  const FirstActivityPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
