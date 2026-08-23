import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/daily_forecast.dart';
import '../../../data/models/schedule_day.dart';
import '../../../data/repositories/weather_repository.dart';
import '../../../services/behavioral_event_service.dart';
import '../../../widgets/find_and_book_sheet.dart';
import '../../../widgets/outcome_prompt.dart';
import '../../weather_scene/weather_scene_background.dart';
import '../home_providers.dart';

// -------------------------------------------------------------------
// Scene legibility
// -------------------------------------------------------------------

/// Opacity of day headers and activity cards over the animated scene.
///
/// The scene is already dimmed toward `colors.background` by the veil, so the
/// residual contrast shift on card text is roughly a tenth of the scene's
/// deviation from the background. Measured on all five palettes; see the
/// branch notes.
const double _scheduleSurfaceOpacity = 0.90;

/// The surface every piece of schedule content sits on.
///
/// Nothing in this tab may draw text straight onto the scene. Measured against
/// the worst-case scene stack under the lightest part of the veil, bare
/// `textSecondary` reaches 1.45:1 on night and 1.95:1 on overcast; the same
/// text on this surface clears 4.98:1 in every palette.
BoxDecoration _sceneSurface(WeatherThemeColors colors) => BoxDecoration(
  color: colors.surface.withValues(alpha: _scheduleSurfaceOpacity),
  borderRadius: BorderRadius.circular(OutAboutRadius.cards),
);

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

/// Whether two instants fall on the same calendar day.
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The heading for a forecast day, derived from its own date.
///
/// Position is not a date. The cache is served on any fetch failure, so
/// `days[0]` is whatever day was fetched last — captioning it "Today" by
/// index is how a Monday forecast came to be presented as Wednesday's plan,
/// while the detail screen's date comparison correctly disagreed.
String _dayLabel(DateTime date, DateTime now) {
  if (_isSameDay(date, now)) return 'Today';
  if (_isSameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
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

/// The short form used on activity-first badges.
String _shortDayLabel(DateTime date, DateTime now) {
  if (_isSameDay(date, now)) return 'Today';
  if (_isSameDay(date, now.add(const Duration(days: 1)))) return 'Tmrw';
  return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday -
      1];
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
      // Only to stop RefreshIndicator rethrowing. The provider still holds
      // the AsyncError, so the error state renders.
      debugPrint('ScheduleTab refresh: forecast failed — ${redactApiKey(e)}');
      return const ForecastSnapshot(days: <DailyForecast>[]);
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
    final now = ref.watch(nowProvider)();
    // Null while loading or errored; non-null only when the days on screen
    // came out of the cache rather than a live fetch.
    final servedFromCacheAt = ref
        .watch(dailyForecastProvider)
        .valueOrNull
        ?.servedFromCacheAt;

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
                // StatefulShellRoute.indexedStack keeps every branch mounted, so
                // this FAB and the Activities one are in the tree together. With
                // the default tag both claim <default FloatingActionButton tag>
                // and every route transition throws.
                heroTag: 'scheduleFab',
                backgroundColor: colors.primary,
                onPressed: () => context.push(AppRoutes.addActivity),
                tooltip: 'Add activity',
                child: Icon(Icons.add, color: colors.onPrimary),
              )
              .animateSafely(context)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: OutAboutAnimations.standardDuration,
                curve: Curves.easeOutBack,
              ),
      body: Stack(
        children: [
          // Behind the day list, inside the shell branch: go_router wraps each
          // branch in a TickerMode, so the scene stops animating the moment the
          // user switches tabs.
          const Positioned.fill(child: WeatherSceneBackground()),
          RefreshIndicator(
            color: colors.primaryInteractive,
            backgroundColor: colors.surface,
            onRefresh: _onRefresh,
            child: scheduleAsync.when(
              loading: () => _ScheduleShimmer(colors: colors),
              error: (error, _) {
                debugPrint(
                  'ScheduleTab: ${error.runtimeType} — ${redactApiKey(error)}',
                );
                return _ScheduleErrorBanner(error: error);
              },
              data: (days) {
                final allActivities = activitiesAsync.valueOrNull ?? [];

                if (allActivities.isEmpty) {
                  return const _ScheduleEmptyState();
                }

                if (layout == ScheduleLayout.dayFirst) {
                  return _DayFirstLayout(
                    days: days,
                    now: now,
                    staleSince: servedFromCacheAt,
                    colors: colors,
                    isDark: isDark,
                    temperatureUnit: temperatureUnit,
                  );
                }

                return _ActivityFirstLayout(
                  days: days,
                  allActivities: allActivities,
                  now: now,
                  staleSince: servedFromCacheAt,
                  colors: colors,
                  isDark: isDark,
                  temperatureUnit: temperatureUnit,
                );
              },
            ),
          ),
        ],
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
    required this.now,
    required this.staleSince,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final List<ScheduleDay> days;
  final DateTime now;

  /// When the shown forecast was fetched, if it came from the cache.
  final DateTime? staleSince;
  final WeatherThemeColors colors;
  final bool isDark;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (staleSince case final fetchedAt?)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              OutAboutSpacing.md,
              OutAboutSpacing.md,
              OutAboutSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _StaleForecastBanner(
                fetchedAt: fetchedAt,
                now: now,
                colors: colors,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          sliver: SliverList.builder(
            itemCount: days.length,
            itemBuilder: (context, index) {
              return _DaySection(
                scheduleDay: days[index],
                sectionIndex: index,
                now: now,
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
// _StaleForecastBanner
// -------------------------------------------------------------------

/// Says out loud that these days came from the cache, and when.
///
/// The cache is worth serving offline, but presenting it as the current
/// forecast is what turned a Monday fetch into Wednesday's plan. Paired with
/// date-derived day headings, this makes the age explicit instead of implied.
class _StaleForecastBanner extends StatelessWidget {
  const _StaleForecastBanner({
    required this.fetchedAt,
    required this.now,
    required this.colors,
  });

  final DateTime fetchedAt;
  final DateTime now;
  final WeatherThemeColors colors;

  String get _age {
    if (_isSameDay(fetchedAt, now)) return 'earlier today';
    if (_isSameDay(fetchedAt, now.subtract(const Duration(days: 1)))) {
      return 'yesterday';
    }
    return 'on ${_dayLabel(fetchedAt, now)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: OutAboutSpacing.sm),
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: _scheduleSurfaceOpacity),
        borderRadius: BorderRadius.circular(OutAboutRadius.cards),
        border: Border.all(
          color: OutAboutColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: OutAboutColors.warning,
            ),
          ),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Text(
              'Showing the forecast saved $_age. Pull to refresh.',
              style: OutAboutTypography.bodySmall(colors),
            ),
          ),
        ],
      ),
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
    required this.now,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final ScheduleDay scheduleDay;

  /// Position in the list. Used only to stagger the entrance animation —
  /// never to decide what day this is.
  final int sectionIndex;
  final DateTime now;
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
                now: now,
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
                      forecast: scheduleDay.forecast,
                      cardIndex: cardIndex,
                      sectionIndex: sectionIndex,
                      now: now,
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
        .animateSafely(context)
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
    required this.now,
    required this.colors,
    required this.temperatureUnit,
  });

  final DailyForecast forecast;
  final DateTime now;
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
      decoration: _sceneSurface(colors),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The condition name is spelled out beside it, so the icon is
          // supplemental and its tint need not carry the meaning alone.
          ExcludeSemantics(
            child: Icon(iconData.icon, size: 32, color: iconData.tint),
          ),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          _dayLabel(forecast.date, now),
                          style: OutAboutTypography.headingSmall(colors),
                        ),
                      ),
                    ),
                    const SizedBox(width: OutAboutSpacing.sm),
                    Flexible(
                      child: Text(
                        iconData.name,
                        style: OutAboutTypography.bodySmall(colors),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OutAboutSpacing.xs),
                // A Wrap, not a Row: at the accessibility text sizes the
                // temperature range alone is wider than the card, and a Row
                // would overflow rather than reflow.
                Wrap(
                  spacing: OutAboutSpacing.sm,
                  runSpacing: OutAboutSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'H: $highTemp$tempSuffix'
                      ' / L: $lowTemp$tempSuffix',
                      style: OutAboutTypography.bodyMedium(colors),
                    ),
                    _DayHeaderStat(
                      icon: Icons.water_drop_outlined,
                      label: '${forecast.precipitationProbability.round()}%',
                      semanticLabel:
                          'Chance of precipitation '
                          '${forecast.precipitationProbability.round()} '
                          'percent',
                      colors: colors,
                    ),
                    _DayHeaderStat(
                      icon: Icons.air,
                      label: windDisplay,
                      semanticLabel: 'Wind up to $windDisplay',
                      colors: colors,
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

/// One icon-plus-value pair in the day header.
///
/// The icon tints (`OutAboutColors.rainy`, `.cloudy`) sit at 1.7-2.8:1 on a
/// light card, so each pair carries a spoken label rather than leaving the
/// glyph to say what the number means.
class _DayHeaderStat extends StatelessWidget {
  const _DayHeaderStat({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colors.textSecondary),
            const SizedBox(width: OutAboutSpacing.xs),
            Text(label, style: OutAboutTypography.labelSmall(colors)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// _ScheduleActivityCard
// -------------------------------------------------------------------

class _ScheduleActivityCard extends ConsumerWidget {
  const _ScheduleActivityCard({
    required this.activity,
    required this.forecast,
    required this.cardIndex,
    required this.sectionIndex,
    required this.now,
    required this.colors,
    required this.isDark,
  });

  final Activity activity;

  /// The day this card sits under. Carried so the outcome prompt knows which
  /// day it is asking about, and so the weather that day is attached to any
  /// event the card logs.
  final DailyForecast forecast;
  final int cardIndex;

  /// Stagger position only — see [_DaySection.sectionIndex].
  final int sectionIndex;
  final DateTime now;
  final WeatherThemeColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final categoryNames = categories
        .where((c) => activity.categoryIds.contains(c.id))
        .map((c) => c.name)
        .toList();

    void openDetail() {
      if (activity.id != null) {
        context.push('/activity/${activity.id}');
      }
    }

    // `explicitChildNodes` is what keeps this card from collapsing into one
    // node. The subtree holds three further controls — Find & book, and the
    // outcome prompt's Yes / Not today / Dismiss — and without it they merge
    // into the card's own button and stop being reachable.
    //
    // The tap action is declared on this node rather than inherited from the
    // GestureDetector below, which is excluded from semantics for the same
    // reason: two overlapping tap nodes read as two buttons.
    // An activity that set no conditions is shown on every day — nothing can
    // rule it out — but the app must not claim its weather matched. Only a
    // profile that actually constrains something earns the success rail and
    // the "conditions match" wording.
    final isConstrained = activity.conditionProfile?.isConstraining ?? false;

    return Semantics(
          container: true,
          explicitChildNodes: true,
          button: true,
          label: isConstrained
              ? 'Activity: ${activity.name}, '
                    'conditions match ${_dayLabel(forecast.date, now)}'
              : 'Activity: ${activity.name}, no weather conditions set',
          onTap: openDetail,
          child: GestureDetector(
            excludeFromSemantics: true,
            onTap: openDetail,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: colors.cardBackground.withValues(
                  alpha: _scheduleSurfaceOpacity,
                ),
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
                        color: isConstrained
                            ? OutAboutColors.success
                            : colors.divider,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(OutAboutRadius.cards),
                          bottomLeft: Radius.circular(OutAboutRadius.cards),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(OutAboutSpacing.md),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ExcludeSemantics(
                                    child: Text(
                                      activity.name,
                                      style: OutAboutTypography.bodyMedium(
                                        colors,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.travel_explore,
                                      size: 20,
                                      color: colors.primaryInteractive,
                                    ),
                                    tooltip: 'Find & book',
                                    onPressed: () => showFindAndBookSheet(
                                      context,
                                      ref,
                                      activityName: activity.name,
                                      activityId: activity.id,
                                      categoryNames: categoryNames,
                                      forecastDay: forecast,
                                    ),
                                  ),
                                ),
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Renders nothing unless this is today's match and
                          // it is past the prompt hour — see OutcomePrompt.
                          if (activity.id case final id?)
                            OutcomePrompt(
                              activityId: id,
                              activityName: activity.name,
                              matchedDay: forecast.date,
                              forecastDay: forecast,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animateSafely(context)
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
    required this.now,
    required this.staleSince,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final List<ScheduleDay> days;
  final List<Activity> allActivities;
  final DateTime now;
  final DateTime? staleSince;
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
        if (staleSince case final fetchedAt?)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              OutAboutSpacing.md,
              OutAboutSpacing.md,
              OutAboutSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _StaleForecastBanner(
                fetchedAt: fetchedAt,
                now: now,
                colors: colors,
              ),
            ),
          ),
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
                now: now,
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
    required this.now,
    required this.colors,
    required this.isDark,
    required this.temperatureUnit,
  });

  final Activity activity;
  final List<DailyForecast> matchingDays;

  /// Stagger position only — see [_DaySection.sectionIndex].
  final int sectionIndex;
  final DateTime now;
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
                        now: now,
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
        .animateSafely(context)
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
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.all(OutAboutSpacing.md),
        decoration: _sceneSurface(colors),
        child: Text(
          activity.name,
          style: OutAboutTypography.headingSmall(colors),
        ),
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
    required this.now,
    required this.colors,
    required this.temperatureUnit,
  });

  final DailyForecast forecast;
  final DateTime now;
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
    final tempSuffix = temperatureUnit == 'F' ? '\u00B0' : '\u00B0';

    // The weather icon is the only thing naming the condition here — unlike
    // _DayHeader, no text sits beside it — so the label has to carry it.
    return Semantics(
      label:
          '${_shortDayLabel(forecast.date, now)}, ${iconData.name}, '
          'high $highTemp$tempSuffix, low $lowTemp$tempSuffix',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OutAboutSpacing.sm,
            vertical: OutAboutSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: _scheduleSurfaceOpacity),
            borderRadius: BorderRadius.circular(OutAboutRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData.icon, size: 16, color: iconData.tint),
              const SizedBox(width: OutAboutSpacing.xs),
              // Flexible, because the badge sits in a Wrap cell that is free
              // to be narrower than the text wants at accessibility sizes.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _shortDayLabel(forecast.date, now),
                      style: OutAboutTypography.labelMedium(colors),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$highTemp$tempSuffix'
                      ' / $lowTemp$tempSuffix',
                      style: OutAboutTypography.labelSmall(colors),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    return Container(
      margin: const EdgeInsets.only(top: OutAboutSpacing.sm),
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      decoration: _sceneSurface(colors),
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
          child:
              Center(
                    child: Container(
                      margin: const EdgeInsets.all(OutAboutSpacing.md),
                      padding: const EdgeInsets.all(OutAboutSpacing.xl),
                      decoration: _sceneSurface(colors),
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
                              onPressed: () =>
                                  context.push(AppRoutes.addActivity),
                              child: const Text('Add Activity'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .animateSafely(context)
                  .fadeIn(duration: OutAboutAnimations.standardDuration),
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
                MotionSafeShimmer(
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
  const _ScheduleErrorBanner({required this.error});

  final Object error;

  /// What actually failed.
  ///
  /// The schedule needs both the forecast and the activity list, and it used
  /// to blame the forecast whichever one broke — including the common case
  /// where the forecast came from cache and the activity fetch was the thing
  /// that failed.
  ({String message, IconData icon}) _describe() {
    if (error is NoLocationException) {
      return (
        message:
            'OutAbout needs your location to build a schedule. '
            'Enable location access in Settings.',
        icon: Icons.location_off_outlined,
      );
    }
    final text = error.toString();
    if (text.contains('activities')) {
      return (
        message: "Couldn't load your activities.",
        icon: Icons.cloud_off_outlined,
      );
    }
    return (
      message: "Couldn't load the forecast.",
      icon: Icons.cloud_off_outlined,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final described = _describe();

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            described.icon,
                            color: OutAboutColors.errorColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: OutAboutSpacing.sm),
                        Expanded(
                          child: Text(
                            described.message,
                            style: OutAboutTypography.bodyMedium(colors),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OutAboutSpacing.sm),
                    // Pull-to-refresh was the only way out of this state, and
                    // it is neither discoverable nor reachable with a screen
                    // reader. The Activities tab has always had a button here.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          ref.invalidate(dailyForecastProvider);
                          ref.invalidate(activitiesProvider);
                        },
                        child: Text(
                          'Try again',
                          style: OutAboutTypography.labelLarge(
                            colors,
                          ).copyWith(color: colors.primaryInteractive),
                        ),
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
