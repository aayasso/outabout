import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: OutAboutSpacing.sm / 2),
          child: AnimatedContainer(
            duration: OutAboutAnimations.standardDuration,
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
    );
  }
}
