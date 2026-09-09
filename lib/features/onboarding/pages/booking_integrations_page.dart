import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../services/behavioral_event_service.dart';
import '../widgets/onboarding_button.dart';

class BookingIntegrationsPage extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const BookingIntegrationsPage({super.key, required this.onNext});

  @override
  ConsumerState<BookingIntegrationsPage> createState() =>
      _BookingIntegrationsPageState();
}

class _BookingIntegrationsPageState
    extends ConsumerState<BookingIntegrationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(behavioralEventServiceProvider).log('booking_integration_viewed');
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: OutAboutSpacing.xl,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: OutAboutSpacing.xxxl),
                    Text(
                      'We help you get there',
                      style: OutAboutTypography.displayLarge(colors),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: OutAboutSpacing.md),
                    Text(
                      'When conditions match, OutAbout hands'
                      ' you straight to the right place'
                      ' \u2014 AllTrails for a hike, OpenTable'
                      ' for dinner, Playtomic for a court,'
                      ' Mindbody for a class, and more.',
                      style: OutAboutTypography.bodyLarge(colors),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: OutAboutSpacing.xl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OutAboutSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OnboardingButton(
                    label: 'Continue',
                    onPressed: widget.onNext,
                  ),
                  const SizedBox(height: OutAboutSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animateSafely(context)
        .fadeIn(duration: OutAboutAnimations.standardDuration)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
  }
}
