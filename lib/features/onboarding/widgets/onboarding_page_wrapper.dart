import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import 'onboarding_button.dart';

class OnboardingPageWrapper extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback? onCtaPressed;
  final bool isLoading;
  final String? skipLabel;
  final VoidCallback? onSkipPressed;
  final Widget? customContent;

  const OnboardingPageWrapper({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.ctaLabel,
    this.onCtaPressed,
    this.isLoading = false,
    this.skipLabel,
    this.onSkipPressed,
    this.customContent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: OutAboutSpacing.xl),
          child: Column(
            children: [
              SizedBox(height: OutAboutSpacing.xxxl),
              Icon(
                icon,
                size: 64,
                color: colors.primaryInteractive,
              ),
              const SizedBox(height: OutAboutSpacing.xl),
              Text(
                title,
                style: OutAboutTypography.displayLarge(colors),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OutAboutSpacing.md),
              Text(
                body,
                style: OutAboutTypography.bodyLarge(colors),
                textAlign: TextAlign.center,
              ),
              ?customContent,
              const Spacer(),
              if (skipLabel != null)
                TextButton(
                  onPressed: onSkipPressed,
                  child: Text(
                    skipLabel!,
                    style: OutAboutTypography.labelLarge(colors).copyWith(
                      color: colors.primaryInteractive,
                    ),
                  ),
                ),
              const SizedBox(height: OutAboutSpacing.sm),
              OnboardingButton(
                label: ctaLabel,
                onPressed: onCtaPressed,
                isLoading: isLoading,
              ),
              const SizedBox(height: OutAboutSpacing.xl),
            ],
          ),
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
