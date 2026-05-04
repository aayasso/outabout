import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../data/models/condition_profile.dart';
import '../../../models/activity.dart';
import '../home_providers.dart';

// ---------------------------------------------------------------------------
// ActivitiesTab — main entry point
// ---------------------------------------------------------------------------

class ActivitiesTab extends ConsumerWidget {
  const ActivitiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final weatherTheme = ref.watch(weatherThemeProvider);
    final isDark =
        weatherTheme.brightness == Brightness.dark;
    final activitiesAsync =
        ref.watch(activitiesProvider);
    final profileAsync = ref.watch(profileProvider);
    final temperatureUnit =
        profileAsync.valueOrNull?.temperatureUnit ??
            'F';

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
      body: activitiesAsync.when(
        loading: () =>
            _ActivitiesShimmer(colors: colors),
        error: (error, _) =>
            const _ActivitiesErrorState(),
        data: (activities) {
          if (activities.isEmpty) {
            return const _ActivitiesEmptyState();
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: colors.surface,
                title: Text(
                  'Activities',
                  style:
                      OutAboutTypography.headingLarge(
                    colors,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(
                  OutAboutSpacing.md,
                ),
                sliver: SliverList(
                  delegate:
                      SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: OutAboutSpacing.sm,
                        ),
                        child: _ActivityListCard(
                          activity:
                              activities[index],
                          colors: colors,
                          isDark: isDark,
                          index: index,
                          ref: ref,
                          temperatureUnit:
                              temperatureUnit,
                        ),
                      );
                    },
                    childCount: activities.length,
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.only(
                  bottom: OutAboutSpacing.xxxl,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivityListCard
// ---------------------------------------------------------------------------

class _ActivityListCard extends StatelessWidget {
  const _ActivityListCard({
    required this.activity,
    required this.colors,
    required this.isDark,
    required this.index,
    required this.ref,
    required this.temperatureUnit,
  });

  final Activity activity;
  final WeatherThemeColors colors;
  final bool isDark;
  final int index;
  final WidgetRef ref;
  final String temperatureUnit;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(
          right: OutAboutSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: OutAboutColors.errorColor,
          borderRadius: BorderRadius.circular(
            OutAboutRadius.cards,
          ),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) {
        if (activity.id != null) {
          ref
              .read(activityRepositoryProvider)
              .archive(activity.id!);
        }
        OutAboutHaptics.onActivitySave();
        ref.invalidate(activitiesProvider);
      },
      child: Semantics(
        label: 'Activity: ${activity.name}',
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
                        activity.name,
                        style: OutAboutTypography
                            .headingSmall(colors),
                      ),
                      if (activity.conditionProfile !=
                          null) ...[
                        const SizedBox(
                          height: OutAboutSpacing.sm,
                        ),
                        Wrap(
                          spacing: OutAboutSpacing.xs,
                          runSpacing:
                              OutAboutSpacing.xs,
                          children:
                              _buildConditionChips(
                            activity
                                .conditionProfile!,
                          ),
                        ),
                      ],
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

  List<Widget> _buildConditionChips(
    ConditionProfile profile,
  ) {
    final chips = <Widget>[];

    if (profile.tempEnabled) {
      final min = profile.tempMin?.round();
      final max = profile.tempMax?.round();
      if (min != null && max != null) {
        chips.add(
          _ConditionChip(
            label:
                '$min\u2013$max\u00B0$temperatureUnit',
            colors: colors,
          ),
        );
      } else if (min != null) {
        chips.add(
          _ConditionChip(
            label: '> $min\u00B0$temperatureUnit',
            colors: colors,
          ),
        );
      } else if (max != null) {
        chips.add(
          _ConditionChip(
            label: '< $max\u00B0$temperatureUnit',
            colors: colors,
          ),
        );
      }
    }

    if (profile.precipEnabled) {
      final label = profile.precipLevel == 'none'
          ? 'No rain'
          : 'Rain OK';
      chips.add(
        _ConditionChip(
          label: label,
          colors: colors,
        ),
      );
    }

    if (profile.windEnabled && profile.windMax != null) {
      final windUnit =
          temperatureUnit == 'C' ? 'km/h' : 'mph';
      chips.add(
        _ConditionChip(
          label:
              'Wind < ${profile.windMax!.round()} '
              '$windUnit',
          colors: colors,
        ),
      );
    }

    if (profile.uvEnabled) {
      final min = profile.uvMin?.round();
      final max = profile.uvMax?.round();
      if (min != null && max != null) {
        chips.add(
          _ConditionChip(
            label: 'UV $min\u2013$max',
            colors: colors,
          ),
        );
      } else if (max != null) {
        chips.add(
          _ConditionChip(
            label: 'UV < $max',
            colors: colors,
          ),
        );
      }
    }

    return chips;
  }
}

// ---------------------------------------------------------------------------
// _ConditionChip
// ---------------------------------------------------------------------------

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({
    required this.label,
    required this.colors,
  });

  final String label;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OutAboutSpacing.sm,
        vertical: OutAboutSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(
          OutAboutRadius.full,
        ),
        border: Border.all(color: colors.divider),
      ),
      child: Text(
        label,
        style: OutAboutTypography.labelSmall(colors),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivitiesEmptyState
// ---------------------------------------------------------------------------

class _ActivitiesEmptyState extends ConsumerWidget {
  const _ActivitiesEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(OutAboutSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_run_outlined,
              size: 64,
              color: colors.textSecondary,
            ),
            const SizedBox(
              height: OutAboutSpacing.md,
            ),
            Text(
              'Your wishlist is empty',
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
              'Add outdoor activities and we\'ll '
              'track the weather for you',
              style:
                  OutAboutTypography.bodyMedium(colors)
                      .copyWith(
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
                onPressed: () =>
                    context.go(AppRoutes.addActivity),
                child: const Text('Add Activity'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivitiesShimmer
// ---------------------------------------------------------------------------

class _ActivitiesShimmer extends StatelessWidget {
  const _ActivitiesShimmer({required this.colors});

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
              for (int i = 0; i < 4; i++) ...[
                Shimmer.fromColors(
                  baseColor: colors.surface,
                  highlightColor: colors.divider,
                  child: Container(
                    height: 80,
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
// _ActivitiesErrorState
// ---------------------------------------------------------------------------

class _ActivitiesErrorState extends ConsumerWidget {
  const _ActivitiesErrorState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(OutAboutSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: OutAboutColors.errorColor,
            ),
            const SizedBox(
              height: OutAboutSpacing.md,
            ),
            Text(
              'Something went wrong',
              style:
                  OutAboutTypography.headingSmall(
                colors,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: OutAboutSpacing.sm,
            ),
            TextButton(
              onPressed: () => ref.invalidate(
                activitiesProvider,
              ),
              child: Text(
                'Try again',
                style: OutAboutTypography.labelLarge(
                  colors,
                ).copyWith(color: colors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
