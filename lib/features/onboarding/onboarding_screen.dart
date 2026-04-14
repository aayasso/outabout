import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import 'onboarding_provider.dart';
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
                  // Placeholder containers — each task (12-17) replaces one
                  ValuePropositionPage(
                    onNext: () =>
                        ref.read(onboardingStepProvider.notifier).next(),
                  ),
                  _PlaceholderPage(
                      label: 'Location Permission', colors: colors),
                  _PlaceholderPage(
                      label: 'Notification Permission', colors: colors),
                  _PlaceholderPage(
                      label: 'Booking Integrations', colors: colors),
                  _PlaceholderPage(label: 'Auth', colors: colors),
                  _PlaceholderPage(label: 'First Activity', colors: colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String label;
  final WeatherThemeColors colors;

  const _PlaceholderPage({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: OutAboutTypography.headingLarge(colors)),
    );
  }
}
