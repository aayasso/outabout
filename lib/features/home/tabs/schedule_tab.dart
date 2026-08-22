import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/daily_forecast.dart';
import '../../../data/models/schedule_day.dart';
import '../../../data/repositories/weather_repository.dart';
import '../../../services/behavioral_event_service.dart';
import '../home_providers.dart';

// -------------------------------------------------------------------
// Unit conversion helpers
// -------------------------------------------------------------------

int _celsiusToFahrenheit(double c) => (c * 9 / 5 + 32).round();

int _kmhToMph(double kmh) => (kmh * 0.621371).round();

// -------------------------------------------------------------------
// Weather icon helper
// -------------------------------------------------------------------

({IconData icon, Color tint, String name}) _weatherIconData(int weatherCode) {
  return switch (weatherCode) {
    1000 => (icon: Icons.wb_sunny, tint: OutAboutColors.sunny, name: 'Clear'),
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
    1001 => (icon: Icons.cloud, tint: OutAboutColors.cloudy, name: 'Cloudy'),
    2000 => (icon: Icons.cloud, tint: OutAboutColors.cloudy, name: 'Fog'),
    2100 => (icon: Icons.cloud, tint: OutAboutColors.cloudy, name: 'Light Fog'),
    4000 => (
      icon: Icons.water_drop,
      tint: OutAboutColors.rainy,
      name: 'Drizzle',
    ),
    4001 => (icon: Icons.water_drop, tint: OutAboutColors.rainy, name: 'Rain'),
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
    5000 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Snow'),
    5001 => (icon: Icons.ac_unit, tint: OutAboutColors.cold, name: 'Flurries'),
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
    _ => (icon: Icons.wb_sunny, tint: OutAboutColors.sunny, name: 'Clear'),
  };
}

// -------------------------------------------------------------------
// Day label helper
// -------------------------------------------------------------------

String _dayLabel(DateTime date, int index) {
  if (index == 0) return 'Today';
  if (index == 1) return 'Tomorrow';
  final weekday = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][date.weekday - 1];
  final month = const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][date.month - 1];
  return '$weekday, $month ${date.day}';
}

// -------------------------------------------------------------------
// ScheduleTab
// -------------------------------------------------------------------

class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key});

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  bool _matchHapticFired = false;

  Future<void> _onRefresh() async {
    ref.read(behavioralEventServiceProvider).log('weather_refreshed');
    ref.invalidate(dailyForecastProvider);
    ref.invalidate(weatherDataProvider);
    ref.invalidate(activitiesProvider);
    await ref.read(dailyForecastProvider.future).catchError((Object e) {
      debugPrint('ScheduleTab refresh: forecast failed — ${redactApiKey(e)}');
      return <DailyForecast>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final weatherTheme = ref.watch(weatherThemeProvider);
    final isDark = weatherTheme.brightness == Brightness.dark;
    final scheduleAsync = ref.watch(scheduleMatchProvider);
    final layout = ref.watch(scheduleLayoutProvider);
    final profileAsync = ref.watch(profileProvider);
    final temperatureUnit = profileAsync.valueOrNull?.temperatureUnit ?? 'F';
    final activitiesAsync = ref.watch(activitiesProvider);

    ref.listen<AsyncValue<List<ScheduleDay>>>(scheduleMatchProvider, (
      previous,
      next,
    ) {
      if (_matchHapticFired) return;
      next.whenData((days) {
        final hasMatch = days.any((d) => d.matchedActivities.isNotEmpty);
        if (hasMatch) {
          _matchHapticFired = true;
          OutAboutHaptics.onConditionMatch();
        }
      });
    });

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton:
          FloatingActionButton(
            backgroundColor: colors.primary,
            onPressed: () => context.go(AppRoutes.addActivity),
            tooltip: 'Add activity',
            child: Icon(Icons.add, color: isDark ? Colors.black : Colors.white),
          ).animate().scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: OutAboutAnimations.standardDuration,
            curve: Curves.easeOutBack,
          ),
      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.surface,
        onRefresh: _onRefresh,
        child: scheduleAsync.when(
          loading: () => _ScheduleShimmer(colors: colors),
          error: (error, _) {
            debugPrint(
              'ScheduleTab: ${error.runtimeType} — ${redactApiKey(error)}',
            );
            return const _ScheduleErrorBanner();
          },
          data: (days) {
            final allActivities = activitiesAsync.valueOrNull ?? [];

            if (allActivities.isEmpty) {
              return const _ScheduleEmptyState();
            }

            if (layout == ScheduleLayout.dayFirst) {
              return _DayFirstLayout(
                days: days,
                colors: colors,
                isDark: isDark,
                temperatureUnit: temperatureUnit,
              );
            }

            return _ActivityFirstLayout(
              days: days,
              allActivities: allActivities,
              colors: colors,
              isDark: isDark,
              temperatureUnit: temperatureUnit,
            );
          },
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// _DayFirstLayout
// -------------------------------------------------------------------

class _DayFirstLayout extends StatelessWidget {
  const _DayFirstLayout({
    required this.days,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final List<ScheduleDay> days;
  final WeatherThemeColors colors;
  final bool isDark;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          sliver: SliverList.builder(
            itemCount: days.length,
            itemBuilder: (context, index) {
              return _DaySection(
                scheduleDay: days[index],
                sectionIndex: index,
                colors: colors,
                isDark: isDark,
                temperatureUnit: temperatureUnit,
              );
            },
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(bottom: OutAboutSpacing.xl),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------
// _DaySection
// -------------------------------------------------------------------

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.scheduleDay,
    required this.sectionIndex,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final ScheduleDay scheduleDay;
  final int sectionIndex;
  final WeatherThemeColors colors;
  final bool isDark;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.only(bottom: OutAboutSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DayHeader(
                forecast: scheduleDay.forecast,
                dayIndex: sectionIndex,
                colors: colors,
                temperatureUnit: temperatureUnit,
              ),
              if (scheduleDay.matchedActivities.isNotEmpty) ...[
                const SizedBox(height: OutAboutSpacing.sm),
                ...List.generate(
                  scheduleDay.matchedActivities.length,
                  (cardIndex) => Padding(
                    padding: const EdgeInsets.only(bottom: OutAboutSpacing.sm),
                    child: _ScheduleActivityCard(
                      activity: scheduleDay.matchedActivities[cardIndex],
                      cardIndex: cardIndex,
                      sectionIndex: sectionIndex,
                      colors: colors,
                      isDark: isDark,
                    ),
                  ),
                ),
              ] else ...[
                const _DayEmptyState(),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: sectionIndex * 80),
          duration: OutAboutAnimations.standardDuration,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: Duration(milliseconds: sectionIndex * 80),
          duration: OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
  }
}

// -------------------------------------------------------------------
// _DayHeader
// -------------------------------------------------------------------

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.forecast,
    required this.dayIndex,
    required this.colors,
    required this.temperatureUnit,
  });

  final DailyForecast forecast;
  final int dayIndex;
  final WeatherThemeColors colors;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    final iconData = _weatherIconData(forecast.weatherCode);

    final highTemp = temperatureUnit == 'F'
        ? _celsiusToFahrenheit(forecast.temperatureMax)
        : forecast.temperatureMax.round();
    final lowTemp = temperatureUnit == 'F'
        ? _celsiusToFahrenheit(forecast.temperatureMin)
        : forecast.temperatureMin.round();
    final tempSuffix = temperatureUnit == 'F' ? '\u00B0F' : '\u00B0C';

    final windDisplay = temperatureUnit == 'F'
        ? '${_kmhToMph(forecast.windSpeedMax)} mph'
        : '${forecast.windSpeedMax.round()} km/h';

    return Container(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(OutAboutRadius.cards),
      ),
      child: Row(
        children: [
          Icon(iconData.icon, size: 32, color: iconData.tint),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayLabel(forecast.date, dayIndex),
                        style: OutAboutTypography.headingSmall(colors),
                      ),
                    ),
                    Text(
                      iconData.name,
                      style: OutAboutTypography.bodySmall(colors),
                    ),
                  ],
                ),
                const SizedBox(height: OutAboutSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'H: $highTemp$tempSuffix'
                        ' / L: $lowTemp$tempSuffix',
                        style: OutAboutTypography.bodyMedium(colors),
                      ),
                    ),
                    Icon(
                      Icons.water_drop_outlined,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: OutAboutSpacing.xs),
                    Text(
                      '${forecast.precipitationProbability.round()}%',
                      style: OutAboutTypography.labelSmall(colors),
                    ),
                    const SizedBox(width: OutAboutSpacing.sm),
                    Icon(Icons.air, size: 14, color: colors.textSecondary),
                    const SizedBox(width: OutAboutSpacing.xs),
                    Text(
                      windDisplay,
                      style: OutAboutTypography.labelSmall(colors),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// _ScheduleActivityCard
// -------------------------------------------------------------------

class _ScheduleActivityCard extends StatelessWidget {
  const _ScheduleActivityCard({
    required this.activity,
    required this.cardIndex,
    required this.sectionIndex,
    required this.colors,
    required this.isDark,
  });

  final Activity activity;
  final int cardIndex;
  final int sectionIndex;
  final WeatherThemeColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
          label: 'Activity: ${activity.name}',
          button: true,
          child: GestureDetector(
            onTap: () {
              if (activity.id != null) {
                context.go('/activity/${activity.id}');
              }
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(OutAboutRadius.cards),
                boxShadow: isDark
                    ? OutAboutShadows.cardDark
                    : OutAboutShadows.card,
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: OutAboutColors.success,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(OutAboutRadius.cards),
                          bottomLeft: Radius.circular(OutAboutRadius.cards),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(OutAboutSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_run_outlined,
                              size: 20,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: OutAboutSpacing.sm),
                            Expanded(
                              child: Text(
                                activity.name,
                                style: OutAboutTypography.bodyMedium(colors),
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
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: sectionIndex * 80 + cardIndex * 60),
          duration: OutAboutAnimations.standardDuration,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: Duration(milliseconds: sectionIndex * 80 + cardIndex * 60),
          duration: OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
  }
}

// -------------------------------------------------------------------
// _ActivityFirstLayout
// -------------------------------------------------------------------

class _ActivityFirstLayout extends StatelessWidget {
  const _ActivityFirstLayout({
    required this.days,
    required this.allActivities,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final List<ScheduleDay> days;
  final List<Activity> allActivities;
  final WeatherThemeColors colors;
  final bool isDark;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    final activityDays = <String, List<DailyForecast>>{};
    for (final activity in allActivities) {
      activityDays[activity.id ?? ''] = days
          .where((sd) => sd.matchedActivities.any((a) => a.id == activity.id))
          .map((sd) => sd.forecast)
          .toList();
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          sliver: SliverList.builder(
            itemCount: allActivities.length,
            itemBuilder: (context, index) {
              final activity = allActivities[index];
              final matching = activityDays[activity.id ?? ''] ?? [];
              return _ActivitySection(
                activity: activity,
                matchingDays: matching,
                sectionIndex: index,
                colors: colors,
                isDark: isDark,
                temperatureUnit: temperatureUnit,
              );
            },
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(bottom: OutAboutSpacing.xl),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------
// _ActivitySection
// -------------------------------------------------------------------

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.activity,
    required this.matchingDays,
    required this.sectionIndex,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final Activity activity;
  final List<DailyForecast> matchingDays;
  final int sectionIndex;
  final WeatherThemeColors colors;
  final bool isDark;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.only(bottom: OutAboutSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ActivityHeader(activity: activity, colors: colors),
              if (matchingDays.isNotEmpty) ...[
                const SizedBox(height: OutAboutSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OutAboutSpacing.md,
                  ),
                  child: Wrap(
                    spacing: OutAboutSpacing.sm,
                    runSpacing: OutAboutSpacing.sm,
                    children: List.generate(
                      matchingDays.length,
                      (dayIndex) => _MatchingDayBadge(
                        forecast: matchingDays[dayIndex],
                        dayIndex: dayIndex,
                        colors: colors,
                        temperatureUnit: temperatureUnit,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const _ActivityEmptyState(),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: sectionIndex * 80),
          duration: OutAboutAnimations.standardDuration,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: Duration(milliseconds: sectionIndex * 80),
          duration: OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
  }
}

// -------------------------------------------------------------------
// _ActivityHeader
// -------------------------------------------------------------------

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.activity, required this.colors});

  final Activity activity;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.directions_run_outlined,
            size: 20,
            color: colors.textSecondary,
          ),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Text(
              activity.name,
              style: OutAboutTypography.headingSmall(colors),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// _MatchingDayBadge
// -------------------------------------------------------------------

class _MatchingDayBadge extends StatelessWidget {
  const _MatchingDayBadge({
    required this.forecast,
    required this.dayIndex,
    required this.colors,
    required this.temperatureUnit,
  });

  final DailyForecast forecast;
  final int dayIndex;
  final WeatherThemeColors colors;
  final String temperatureUnit;

  String _shortDayLabel(DateTime date, int index) {
    if (index == 0) return 'Today';
    if (index == 1) return 'Tmrw';
    final weekday = const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][date.weekday - 1];
    return weekday;
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _weatherIconData(forecast.weatherCode);
    final highTemp = temperatureUnit == 'F'
        ? _celsiusToFahrenheit(forecast.temperatureMax)
        : forecast.temperatureMax.round();
    final lowTemp = temperatureUnit == 'F'
        ? _celsiusToFahrenheit(forecast.temperatureMin)
        : forecast.temperatureMin.round();
    final tempSuffix = temperatureUnit == 'F' ? '\u00B0' : '\u00B0';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OutAboutSpacing.sm,
        vertical: OutAboutSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(OutAboutRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData.icon, size: 16, color: iconData.tint),
          const SizedBox(width: OutAboutSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _shortDayLabel(forecast.date, dayIndex),
                style: OutAboutTypography.labelMedium(colors),
              ),
              Text(
                '$highTemp$tempSuffix'
                ' / $lowTemp$tempSuffix',
                style: OutAboutTypography.labelSmall(colors),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// _DayEmptyState
// -------------------------------------------------------------------

class _DayEmptyState extends StatelessWidget {
  const _DayEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyText('No activities match this day\'s forecast');
  }
}

// -------------------------------------------------------------------
// _ActivityEmptyState
// -------------------------------------------------------------------

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _EmptyText('No matching days this week');
  }
}

class _EmptyText extends ConsumerWidget {
  const _EmptyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    return Padding(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      child: Text(text, style: OutAboutTypography.bodySmall(colors)),
    );
  }
}

// -------------------------------------------------------------------
// _ScheduleEmptyState
// -------------------------------------------------------------------

class _ScheduleEmptyState extends ConsumerWidget {
  const _ScheduleEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(OutAboutSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(height: OutAboutSpacing.md),
                  Text(
                    'Add your first outdoor activity',
                    style: OutAboutTypography.headingMedium(colors),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: OutAboutSpacing.sm),
                  Text(
                    'Set conditions and we\'ll show '
                    'you the best days',
                    style: OutAboutTypography.bodyMedium(
                      colors,
                    ).copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: OutAboutSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.addActivity),
                      child: const Text('Add Activity'),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: OutAboutAnimations.standardDuration),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------
// _ScheduleShimmer
// -------------------------------------------------------------------

class _ScheduleShimmer extends StatelessWidget {
  const _ScheduleShimmer({required this.colors});

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (int i = 0; i < 5; i++) ...[
                Shimmer.fromColors(
                  baseColor: colors.surface,
                  highlightColor: colors.divider,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(OutAboutRadius.cards),
                    ),
                  ),
                ),
                const SizedBox(height: OutAboutSpacing.md),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------
// _ScheduleErrorBanner
// -------------------------------------------------------------------

class _ScheduleErrorBanner extends ConsumerWidget {
  const _ScheduleErrorBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: const EdgeInsets.all(OutAboutSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(OutAboutRadius.cards),
                  border: Border.all(
                    color: OutAboutColors.errorColor.withValues(alpha: 0.4),
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
                        'Couldn\'t load forecast. '
                        'Pull to refresh.',
                        style: OutAboutTypography.bodyMedium(colors),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
