import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';

// ---------------------------------------------------------------------------
// ConditionSection — toggle wrapper with animated child
// ---------------------------------------------------------------------------

class ConditionSection extends ConsumerWidget {
  const ConditionSection({
    super.key,
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onToggled,
    required this.child,
  });

  final String title;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onToggled;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(
          OutAboutRadius.cards,
        ),
      ),
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(width: OutAboutSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style:
                      OutAboutTypography.headingSmall(colors),
                ),
              ),
              Semantics(
                label: '$title condition toggle',
                child: Switch(
                  value: enabled,
                  activeTrackColor: colors.primary,
                  activeThumbColor: colors.background,
                  onChanged: (value) {
                    OutAboutHaptics.onConditionToggle();
                    onToggled(value);
                  },
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(
                top: OutAboutSpacing.md,
              ),
              child: child,
            ),
            crossFadeState: enabled
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: OutAboutAnimations.standardDuration,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TemperatureSection — RangeSlider 0–50 C
// ---------------------------------------------------------------------------

class TemperatureSection extends StatelessWidget {
  const TemperatureSection({
    super.key,
    required this.colors,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final WeatherThemeColors colors;
  final double min;
  final double max;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${min.round()} C',
              style: OutAboutTypography.labelMedium(colors),
            ),
            Text(
              '${max.round()} C',
              style: OutAboutTypography.labelMedium(colors),
            ),
          ],
        ),
        const SizedBox(height: OutAboutSpacing.xs),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: colors.primary,
            inactiveTrackColor: colors.divider,
            thumbColor: colors.primary,
          ),
          child: RangeSlider(
            values: RangeValues(min, max),
            min: 0,
            max: 50,
            divisions: 50,
            labels: RangeLabels(
              '${min.round()}',
              '${max.round()}',
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PrecipitationSection — SegmentedButton (none / light / any)
// ---------------------------------------------------------------------------

class PrecipitationSection extends StatelessWidget {
  const PrecipitationSection({
    super.key,
    required this.colors,
    required this.level,
    required this.onChanged,
  });

  final WeatherThemeColors colors;
  final String level;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'none', label: Text('None')),
          ButtonSegment(
            value: 'light',
            label: Text('Light'),
          ),
          ButtonSegment(value: 'any', label: Text('Any')),
        ],
        selected: {level},
        onSelectionChanged: (values) =>
            onChanged(values.first),
        style: ButtonStyle(
          backgroundColor:
              WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.primary;
            }
            return colors.surface;
          }),
          foregroundColor:
              WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.background;
            }
            return colors.text;
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WindSection — Slider 0–80 km/h
// ---------------------------------------------------------------------------

class WindSection extends StatelessWidget {
  const WindSection({
    super.key,
    required this.colors,
    required this.maxWind,
    required this.onChanged,
  });

  final WeatherThemeColors colors;
  final double maxWind;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Max ${maxWind.round()} km/h',
            style: OutAboutTypography.labelMedium(colors),
          ),
        ),
        const SizedBox(height: OutAboutSpacing.xs),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: colors.primary,
            inactiveTrackColor: colors.divider,
            thumbColor: colors.primary,
          ),
          child: Slider(
            value: maxWind,
            min: 0,
            max: 80,
            divisions: 80,
            label: '${maxWind.round()} km/h',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UvSection — RangeSlider 0–11
// ---------------------------------------------------------------------------

class UvSection extends StatelessWidget {
  const UvSection({
    super.key,
    required this.colors,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final WeatherThemeColors colors;
  final double min;
  final double max;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'UV ${min.round()}',
              style: OutAboutTypography.labelMedium(colors),
            ),
            Text(
              'UV ${max.round()}',
              style: OutAboutTypography.labelMedium(colors),
            ),
          ],
        ),
        const SizedBox(height: OutAboutSpacing.xs),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: colors.primary,
            inactiveTrackColor: colors.divider,
            thumbColor: colors.primary,
          ),
          child: RangeSlider(
            values: RangeValues(min, max),
            min: 0,
            max: 11,
            divisions: 11,
            labels: RangeLabels(
              '${min.round()}',
              '${max.round()}',
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
