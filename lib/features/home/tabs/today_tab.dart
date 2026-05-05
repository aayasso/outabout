import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../data/models/condition_match.dart';
import '../../../data/models/weather_data.dart';
import '../home_providers.dart';

// ---------------------------------------------------------------------------
// Unit conversion helpers
// ---------------------------------------------------------------------------

int _celsiusToFahrenheit(double c) => (c * 9 / 5 + 32).round();
int _kmhToMph(double kmh) => (kmh * 0.621371).round();

// ---------------------------------------------------------------------------
// TodayTab — main entry point
// ---------------------------------------------------------------------------

class TodayTab extends ConsumerStatefulWidget {
  const TodayTab({super.key});

  @override
  ConsumerState<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<TodayTab> {
  bool _matchHapticFired = false;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final weatherTheme = ref.watch(weatherThemeProvider);
    final isDark =
        weatherTheme.brightness == Brightness.dark;
    final matchesAsync = ref.watch(conditionMatchProvider);
    final weatherAsync = ref.watch(weatherDataProvider);
    final locationAsync = ref.watch(userLocationProvider);
    final profileAsync = ref.watch(profileProvider);
    final temperatureUnit =
        profileAsync.valueOrNull?.temperatureUnit ?? 'F';

    ref.listen<AsyncValue<List<ConditionMatch>>>(
      conditionMatchProvider,
      (previous, next) {
        if (_matchHapticFired) return;
        next.whenData((matches) {
          final hasMatch =
              matches.any((m) => m.isMatch);
          if (hasMatch) {
            _matchHapticFired = true;
            OutAboutHaptics.onConditionMatch();
          }
        });
      },
    );

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.primary,
        onPressed: () =>
            context.go(AppRoutes.addActivity),
        tooltip: 'Add activity',
        child: Icon(
          Icons.add,
          color: isDark ? Colors.black : Colors.white,
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration:
                OutAboutAnimations.standardDuration,
            curve: Curves.easeOutBack,
          ),
      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.surface,
        onRefresh: () async {
          ref.invalidate(weatherDataProvider);
          ref.invalidate(activitiesProvider);
          await ref
              .read(weatherDataProvider.future)
              .catchError((_) => const WeatherData(
                    weatherCode: 0,
                    temperature: 0,
                    windSpeed: 0,
                    humidity: 0,
                    precipitationIntensity: 0,
                    uvIndex: 0,
                  ));
        },
        child: matchesAsync.when(
          loading: () => _TodayShimmer(colors: colors),
          error: (error, _) => _buildErrorContent(
            context,
            colors: colors,
            isDark: isDark,
            weatherAsync: weatherAsync,
            locationAsync: locationAsync,
          ),
          data: (matches) => _buildContent(
            context,
            matches: matches,
            colors: colors,
            isDark: isDark,
            weatherAsync: weatherAsync,
            locationAsync: locationAsync,
            temperatureUnit: temperatureUnit,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent(
    BuildContext context, {
    required WeatherThemeColors colors,
    required bool isDark,
    required AsyncValue<WeatherData> weatherAsync,
    required AsyncValue<dynamic> locationAsync,
  }) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _WeatherErrorBanner(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<ConditionMatch> matches,
    required WeatherThemeColors colors,
    required bool isDark,
    required AsyncValue<WeatherData> weatherAsync,
    required AsyncValue<dynamic> locationAsync,
    required String temperatureUnit,
  }) {
    if (matches.isEmpty) {
      return const _TodayEmptyState();
    }

    final matched =
        matches.where((m) => m.isMatch).toList();
    final unmatched =
        matches.where((m) => !m.isMatch).toList();
    final sorted = [...matched, ...unmatched];

    final location = locationAsync.valueOrNull;
    final showLocationBanner = location == null;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (showLocationBanner) ...[
                const _LocationPermissionBanner(),
                const SizedBox(
                  height: OutAboutSpacing.md,
                ),
              ],
              weatherAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) =>
                    const _WeatherErrorBanner(),
                data: (weather) => _WeatherSummaryCard(
                  weather: weather,
                  location: location,
                  colors: colors,
                  isDark: isDark,
                  temperatureUnit: temperatureUnit,
                ),
              ),
              const SizedBox(height: OutAboutSpacing.md),
              if (matched.isEmpty)
                _NoMatchesState(colors: colors),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: OutAboutSpacing.md,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final match = sorted[index];
                if (match.isMatch) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: OutAboutSpacing.sm,
                    ),
                    child: _MatchedActivityCard(
                      activity: match.activity,
                      colors: colors,
                      isDark: isDark,
                      index: index,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: OutAboutSpacing.sm,
                  ),
                  child: _ActivityCard(
                    activity: match.activity,
                    colors: colors,
                    isDark: isDark,
                    index: index,
                  ),
                );
              },
              childCount: sorted.length,
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(
            bottom: OutAboutSpacing.xl,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _LocationPermissionBanner
// ---------------------------------------------------------------------------

class _LocationPermissionBanner extends ConsumerWidget {
  const _LocationPermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Container(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(OutAboutRadius.cards),
        border: Border.all(
          color: OutAboutColors.warning.withValues(
            alpha: 0.4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_off_outlined,
            color: OutAboutColors.warning,
            size: 24,
          ),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Text(
              'Enable location to see weather '
              'for your area',
              style:
                  OutAboutTypography.bodyMedium(colors),
            ),
          ),
          const SizedBox(width: OutAboutSpacing.sm),
          TextButton(
            onPressed: openAppSettings,
            child: Text(
              'Enable',
              style: OutAboutTypography.labelLarge(colors)
                  .copyWith(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WeatherSummaryCard
// ---------------------------------------------------------------------------

String? _stalenessText(DateTime? fetchedAt) {
  if (fetchedAt == null) return null;
  final minutes =
      DateTime.now().difference(fetchedAt).inMinutes;
  if (minutes < 30) return null;
  if (minutes < 60) return 'Updated $minutes min ago';
  final hours = minutes ~/ 60;
  return 'Updated $hours hr ago';
}

({IconData icon, Color tint, String name}) _weatherIconData(
  int weatherCode,
) {
  return switch (weatherCode) {
    1000 => (
      icon: Icons.wb_sunny,
      tint: OutAboutColors.sunny,
      name: 'Clear',
    ),
    1100 => (
      icon: Icons.wb_sunny,
      tint: OutAboutColors.sunny,
      name: 'Mostly Clear',
    ),
    1101 => (
      icon: Icons.cloud_outlined,
      tint: OutAboutColors.cloudy,
      name: 'Partly Cloudy',
    ),
    1102 => (
      icon: Icons.cloud_outlined,
      tint: OutAboutColors.cloudy,
      name: 'Mostly Cloudy',
    ),
    1001 => (
      icon: Icons.cloud,
      tint: OutAboutColors.cloudy,
      name: 'Cloudy',
    ),
    2000 => (
      icon: Icons.cloud,
      tint: OutAboutColors.cloudy,
      name: 'Fog',
    ),
    2100 => (
      icon: Icons.cloud,
      tint: OutAboutColors.cloudy,
      name: 'Light Fog',
    ),
    4000 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.rainy,
      name: 'Drizzle',
    ),
    4001 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.rainy,
      name: 'Rain',
    ),
    4200 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.rainy,
      name: 'Light Rain',
    ),
    4201 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.rainy,
      name: 'Heavy Rain',
    ),
    5000 => (
      icon: Icons.ac_unit,
      tint: OutAboutColors.cold,
      name: 'Snow',
    ),
    5001 => (
      icon: Icons.ac_unit,
      tint: OutAboutColors.cold,
      name: 'Flurries',
    ),
    5100 => (
      icon: Icons.ac_unit,
      tint: OutAboutColors.cold,
      name: 'Light Snow',
    ),
    5101 => (
      icon: Icons.ac_unit,
      tint: OutAboutColors.cold,
      name: 'Heavy Snow',
    ),
    6000 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.cold,
      name: 'Freezing Drizzle',
    ),
    6001 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.cold,
      name: 'Freezing Rain',
    ),
    6200 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.cold,
      name: 'Light Freezing Rain',
    ),
    6201 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.cold,
      name: 'Heavy Freezing Rain',
    ),
    7000 => (
      icon: Icons.ac_unit,
      tint: OutAboutColors.cold,
      name: 'Ice Pellets',
    ),
    7101 => (
      icon: Icons.ac_unit,
      tint: OutAboutColors.cold,
      name: 'Heavy Ice Pellets',
    ),
    7102 => (
      icon: Icons.ac_unit,
      tint: OutAboutColors.cold,
      name: 'Light Ice Pellets',
    ),
    8000 => (
      icon: Icons.thunderstorm,
      tint: OutAboutColors.rainy,
      name: 'Thunderstorm',
    ),
    _ => (
      icon: Icons.wb_sunny,
      tint: OutAboutColors.sunny,
      name: 'Clear',
    ),
  };
}

class _WeatherSummaryCard extends StatelessWidget {
  const _WeatherSummaryCard({
    required this.weather,
    required this.location,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final WeatherData weather;
  final dynamic location;
  final WeatherThemeColors colors;
  final bool isDark;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    final iconData = _weatherIconData(
      weather.weatherCode,
    );
    final cityName = location?.city as String? ??
        'Current Location';

    final tempDisplay = temperatureUnit == 'F'
        ? '${_celsiusToFahrenheit(weather.temperature)}\u00B0F'
        : '${weather.temperature.round()}\u00B0C';

    final windDisplay = temperatureUnit == 'F'
        ? '${_kmhToMph(weather.windSpeed)} mph'
        : '${weather.windSpeed.round()} km/h';

    return Container(
      padding: const EdgeInsets.all(OutAboutSpacing.lg),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius:
            BorderRadius.circular(OutAboutRadius.cards),
        boxShadow: isDark
            ? OutAboutShadows.cardDark
            : OutAboutShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  tempDisplay,
                  style: OutAboutTypography.displayLarge(
                    colors,
                  ),
                ),
                const SizedBox(
                  height: OutAboutSpacing.xs,
                ),
                Text(
                  iconData.name,
                  style:
                      OutAboutTypography.bodyMedium(colors),
                ),
                const SizedBox(
                  height: OutAboutSpacing.xs,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.air,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(
                      width: OutAboutSpacing.xs,
                    ),
                    Text(
                      windDisplay,
                      style:
                          OutAboutTypography.bodySmall(
                        colors,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: OutAboutSpacing.xs,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(
                      width: OutAboutSpacing.xs,
                    ),
                    Flexible(
                      child: Text(
                        cityName,
                        style:
                            OutAboutTypography.bodySmall(
                          colors,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (_stalenessText(weather.fetchedAt)
                    case final text?) ...[
                  const SizedBox(
                    height: OutAboutSpacing.xs,
                  ),
                  Text(
                    text,
                    style:
                        OutAboutTypography.bodySmall(colors),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            iconData.icon,
            size: 48,
            color: iconData.tint,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration:
              OutAboutAnimations.standardDuration,
        );
  }
}

// ---------------------------------------------------------------------------
// _MatchedActivityCard
// ---------------------------------------------------------------------------

class _MatchedActivityCard extends StatelessWidget {
  const _MatchedActivityCard({
    required this.activity,
    required this.colors,
    required this.isDark,
    required this.index,
  });

  final dynamic activity;
  final WeatherThemeColors colors;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Activity: ${activity.name}, '
          'conditions met',
      button: true,
      child: GestureDetector(
        onTap: () {
          if (activity.id != null) {
            context.go(
              '/activity/${activity.id}',
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(
              OutAboutRadius.cards,
            ),
            boxShadow: isDark
                ? OutAboutShadows.cardDark
                : OutAboutShadows.card,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: OutAboutSpacing.xs,
                  decoration: BoxDecoration(
                    color: OutAboutColors.success,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(
                        OutAboutRadius.cards,
                      ),
                      bottomLeft: Radius.circular(
                        OutAboutRadius.cards,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(
                      OutAboutSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name as String,
                          style: OutAboutTypography
                              .headingSmall(colors),
                        ),
                        const SizedBox(
                          height: OutAboutSpacing.xs,
                        ),
                        Text(
                          '\u2713 Conditions met',
                          style: OutAboutTypography
                                  .labelSmall(colors)
                              .copyWith(
                            color:
                                OutAboutColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    right: OutAboutSpacing.md,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(
            milliseconds: index * 60,
          ),
          duration:
              OutAboutAnimations.standardDuration,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: Duration(
            milliseconds: index * 60,
          ),
          duration:
              OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
  }
}

// ---------------------------------------------------------------------------
// _ActivityCard
// ---------------------------------------------------------------------------

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.colors,
    required this.isDark,
    required this.index,
  });

  final dynamic activity;
  final WeatherThemeColors colors;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Activity: ${activity.name}, '
          'conditions not met',
      button: true,
      child: GestureDetector(
        onTap: () {
          if (activity.id != null) {
            context.go(
              '/activity/${activity.id}',
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(
              OutAboutRadius.cards,
            ),
            boxShadow: isDark
                ? OutAboutShadows.cardDark
                : OutAboutShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(
              OutAboutSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.name as String,
                        style:
                            OutAboutTypography
                                .headingSmall(colors),
                      ),
                      const SizedBox(
                        height: OutAboutSpacing.xs,
                      ),
                      Text(
                        'Conditions not met',
                        style:
                            OutAboutTypography.labelSmall(
                          colors,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(
            milliseconds: index * 60,
          ),
          duration:
              OutAboutAnimations.standardDuration,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: Duration(
            milliseconds: index * 60,
          ),
          duration:
              OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
  }
}

// ---------------------------------------------------------------------------
// _NoMatchesState
// ---------------------------------------------------------------------------

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState({required this.colors});

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(OutAboutSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_outlined,
            size: 48,
            color: colors.textSecondary,
          ),
          const SizedBox(height: OutAboutSpacing.md),
          Text(
            'No matches right now',
            style:
                OutAboutTypography.headingMedium(colors),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: OutAboutSpacing.sm),
          Text(
            'Your activities don\'t match current '
            'conditions. We\'ll notify you when they do.',
            style: OutAboutTypography.bodyMedium(colors)
                .copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration:
              OutAboutAnimations.standardDuration,
        );
  }
}

// ---------------------------------------------------------------------------
// _TodayEmptyState
// ---------------------------------------------------------------------------

class _TodayEmptyState extends ConsumerWidget {
  const _TodayEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(
                OutAboutSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wb_sunny_outlined,
                    size: 64,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(
                    height: OutAboutSpacing.md,
                  ),
                  Text(
                    'Add your first outdoor activity',
                    style:
                        OutAboutTypography.headingMedium(
                      colors,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                    height: OutAboutSpacing.sm,
                  ),
                  Text(
                    'We\'ll let you know when the '
                    'weather is perfect for it',
                    style: OutAboutTypography.bodyMedium(
                      colors,
                    ).copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(
                    height: OutAboutSpacing.lg,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(
                        AppRoutes.addActivity,
                      ),
                      child: const Text(
                        'Add Activity',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _TodayShimmer
// ---------------------------------------------------------------------------

class _TodayShimmer extends StatelessWidget {
  const _TodayShimmer({required this.colors});

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(
            OutAboutSpacing.md,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Shimmer.fromColors(
                baseColor: colors.surface,
                highlightColor: colors.divider,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius:
                        BorderRadius.circular(
                      OutAboutRadius.cards,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: OutAboutSpacing.md,
              ),
              for (int i = 0; i < 3; i++) ...[
                Shimmer.fromColors(
                  baseColor: colors.surface,
                  highlightColor: colors.divider,
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius:
                          BorderRadius.circular(
                        OutAboutRadius.cards,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: OutAboutSpacing.sm,
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _WeatherErrorBanner
// ---------------------------------------------------------------------------

class _WeatherErrorBanner extends ConsumerWidget {
  const _WeatherErrorBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Container(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(OutAboutRadius.cards),
        border: Border.all(
          color: OutAboutColors.errorColor.withValues(
            alpha: 0.4,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: OutAboutColors.errorColor,
            size: 24,
          ),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Text(
              'Couldn\'t load weather. '
              'Pull to refresh.',
              style:
                  OutAboutTypography.bodyMedium(colors),
            ),
          ),
        ],
      ),
    );
  }
}
