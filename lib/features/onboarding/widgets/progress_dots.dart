import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';

class ProgressDots extends ConsumerWidget {
  final int currentPage;
  final int totalPages;

  const ProgressDots({
    super.key,
    required this.currentPage,
    this.totalPages = 6,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    // Six unlabelled dots are the only indication of how far through
    // onboarding you are, and they say nothing at all to a screen reader.
    return Semantics(
      label: 'Step ${currentPage + 1} of $totalPages',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalPages, (index) {
            final isActive = index == currentPage;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: OutAboutSpacing.sm / 2),
              child: AnimatedContainer(
                duration: motionDuration(
                  context,
                  OutAboutAnimations.standardDuration,
                ),
                curve: OutAboutAnimations.standardCurve,
                width: isActive ? 12.0 : 8.0,
                height: isActive ? 12.0 : 8.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? colors.primary
                      : colors.text.withValues(alpha: 0.3),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
