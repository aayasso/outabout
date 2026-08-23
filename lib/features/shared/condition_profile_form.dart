import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/condition_profile.dart';

// ---------------------------------------------------------------------------
// Unit conversion helpers
// ---------------------------------------------------------------------------

int _celsiusToFahrenheit(double c) => (c * 9 / 5 + 32).round();
int _kmhToMph(double kmh) => (kmh * 0.621371).round();

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
        borderRadius: BorderRadius.circular(OutAboutRadius.cards),
      ),
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // One node for the whole row, the way an iOS Settings toggle reads.
          // Left unmerged, the title and the switch are two stops that both
          // say "Temperature" — the second one adding the state.
          MergeSemantics(
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: colors.primaryInteractive, size: 20),
                ),
                const SizedBox(width: OutAboutSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: OutAboutTypography.headingSmall(colors),
                  ),
                ),
                // The state rides on the node; the control type and the
                // on/off wording come from the Switch, in the user's own
                // language.
                Switch(
                  value: enabled,
                  activeTrackColor: colors.primary,
                  activeThumbColor: colors.onPrimary,
                  onChanged: (value) {
                    OutAboutHaptics.onConditionToggle();
                    onToggled(value);
                  },
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: OutAboutSpacing.md),
              child: child,
            ),
            crossFadeState: enabled
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: motionDuration(
              context,
              OutAboutAnimations.standardDuration,
            ),
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
    required this.temperatureUnit,
  });

  final WeatherThemeColors colors;
  final double min;
  final double max;
  final ValueChanged<RangeValues> onChanged;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    final minDisplay = temperatureUnit == 'F'
        ? _celsiusToFahrenheit(min)
        : min.round();
    final maxDisplay = temperatureUnit == 'F'
        ? _celsiusToFahrenheit(max)
        : max.round();
    final unit = '\u00B0$temperatureUnit';

    return Column(
      children: [
        // The two end labels repeat what the slider itself announces.
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '$minDisplay $unit',
                  style: OutAboutTypography.labelMedium(colors),
                ),
              ),
              Flexible(
                child: Text(
                  '$maxDisplay $unit',
                  style: OutAboutTypography.labelMedium(colors),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OutAboutSpacing.xs),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: colors.primaryInteractive,
            inactiveTrackColor: colors.divider,
            thumbColor: colors.primaryInteractive,
          ),
          child: Semantics(
            label: 'Temperature range',
            child: RangeSlider(
              values: RangeValues(min, max),
              min: 0,
              max: 50,
              divisions: 50,
              labels: RangeLabels('$minDisplay$unit', '$maxDisplay$unit'),
              // Stored in Celsius, shown in the user's unit. Without this the
              // screen reader announces "22" while the label reads "72 °F".
              semanticFormatterCallback: (value) {
                final shown = temperatureUnit == 'F'
                    ? _celsiusToFahrenheit(value)
                    : value.round();
                return '$shown $unit';
              },
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PrecipitationSection — SegmentedButton (avoid_rain / rain_only)
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
    return Semantics(
      label: 'Precipitation preference',
      container: true,
      explicitChildNodes: true,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: PrecipLevel.avoidRain,
              label: Text('Avoid rain'),
            ),
            ButtonSegment(
              value: PrecipLevel.rainOnly,
              label: Text('Only when raining'),
            ),
          ],
          selected: {level},
          onSelectionChanged: (values) => onChanged(values.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colors.primary;
              }
              return colors.surface;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colors.onPrimary;
              }
              return colors.text;
            }),
            // Measured at 48pt tall already, so the height is left alone.
            // The horizontal padding is trimmed because 'Only when raining'
            // has to fit a half-width segment at the accessibility sizes.
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: OutAboutSpacing.sm),
            ),
          ),
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
    required this.temperatureUnit,
  });

  final WeatherThemeColors colors;
  final double maxWind;
  final ValueChanged<double> onChanged;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    final windDisplay = temperatureUnit == 'F'
        ? _kmhToMph(maxWind)
        : maxWind.round();
    final windUnit = temperatureUnit == 'F' ? 'mph' : 'km/h';

    return Column(
      children: [
        // The slider announces the same value; leaving both addressable
        // makes VoiceOver read the wind limit twice.
        ExcludeSemantics(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Max $windDisplay $windUnit',
              style: OutAboutTypography.labelMedium(colors),
            ),
          ),
        ),
        const SizedBox(height: OutAboutSpacing.xs),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: colors.primaryInteractive,
            inactiveTrackColor: colors.divider,
            thumbColor: colors.primaryInteractive,
          ),
          child: Semantics(
            label: 'Maximum wind speed',
            child: Slider(
              value: maxWind,
              min: 0,
              max: 80,
              divisions: 80,
              label: '$windDisplay $windUnit',
              // Stored in km/h, shown in mph on the Fahrenheit profile.
              semanticFormatterCallback: (value) {
                final shown = temperatureUnit == 'F'
                    ? _kmhToMph(value)
                    : value.round();
                return 'Maximum $shown $windUnit';
              },
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
