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
                      'Book directly from OutAbout',
                      style: OutAboutTypography.displayLarge(colors),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: OutAboutSpacing.md),
                    Text(
                      'Connect your favorite services to book activities in one tap.',
                      style: OutAboutTypography.bodyLarge(colors),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: OutAboutSpacing.xl),
                    _PartnerCard(
                      name: 'OpenTable',
                      icon: Icons.restaurant_outlined,
                      colors: colors,
                      actionLabel: 'Connect',
                      onAction: () {},
                    ),
                    const SizedBox(height: OutAboutSpacing.md),
                    _ComingSoonCard(colors: colors),
                    const SizedBox(height: OutAboutSpacing.md),
                    _ComingSoonCard(colors: colors),
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
                  TextButton(
                    onPressed: widget.onNext,
                    child: Text(
                      'Skip for Now',
                      style: OutAboutTypography.labelLarge(colors).copyWith(
                        color: colors.primaryInteractive,
                      ),
                    ),
                  ),
                  const SizedBox(height: OutAboutSpacing.sm),
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

class _PartnerCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final WeatherThemeColors colors;
  final String actionLabel;
  final VoidCallback onAction;

  const _PartnerCard({
    required this.name,
    required this.icon,
    required this.colors,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(OutAboutRadius.cards),
        boxShadow: OutAboutShadows.card,
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primaryInteractive, size: 32),
          const SizedBox(width: OutAboutSpacing.md),
          Expanded(
            child: Text(name, style: OutAboutTypography.headingMedium(colors)),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: OutAboutTypography.labelLarge(colors).copyWith(
                color: colors.primaryInteractive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  final WeatherThemeColors colors;

  const _ComingSoonCard({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      decoration: BoxDecoration(
        color: colors.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(OutAboutRadius.cards),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline,
            color: colors.text.withOpacity(0.3),
            size: 32,
          ),
          const SizedBox(width: OutAboutSpacing.md),
          Text(
            'More coming soon',
            style: OutAboutTypography.bodyLarge(colors).copyWith(
              color: colors.text.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
