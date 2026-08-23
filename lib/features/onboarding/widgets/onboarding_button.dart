import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';

class OnboardingButton extends ConsumerWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const OnboardingButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final foregroundColor = colors.onPrimary;

    return Semantics(
      label: label,
      button: true,
      enabled: !isLoading && onPressed != null,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isLoading
              ? null
              : onPressed == null
                  ? null
                  : () {
                      OutAboutHaptics.onActivitySave();
                      onPressed!();
                    },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: foregroundColor,
            disabledBackgroundColor: colors.primary.withValues(alpha: 0.6),
            disabledForegroundColor: foregroundColor.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
            ),
            textStyle: OutAboutTypography.labelLarge(colors).copyWith(
              color: foregroundColor,
            ),
          ),
          child: isLoading
              ? MotionSafeShimmer(
                  baseColor: foregroundColor.withValues(alpha: 0.3),
                  highlightColor: foregroundColor.withValues(alpha: 0.6),
                  child: Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: foregroundColor,
                      borderRadius:
                          BorderRadius.circular(OutAboutRadius.buttons),
                    ),
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}
