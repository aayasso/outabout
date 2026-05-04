import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';

class ActivitiesTab extends ConsumerWidget {
  const ActivitiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Text(
          'Activities',
          style: OutAboutTypography.headingLarge(colors),
        ),
      ),
    );
  }
}
