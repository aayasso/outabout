import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion.dart';
import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../data/models/condition_profile.dart';
import '../../../data/models/activity.dart';
import '../../../services/behavioral_event_service.dart';
import '../category_filter.dart';
import '../home_providers.dart';

// ---------------------------------------------------------------------------
// Unit conversion helpers
// ---------------------------------------------------------------------------

int _celsiusToFahrenheit(double c) => (c * 9 / 5 + 32).round();
int _kmhToMph(double kmh) => (kmh * 0.621371).round();

// ---------------------------------------------------------------------------
// ActivitiesTab — main entry point
// ---------------------------------------------------------------------------

class ActivitiesTab extends ConsumerStatefulWidget {
  const ActivitiesTab({super.key});

  @override
  ConsumerState<ActivitiesTab> createState() =>
      _ActivitiesTabState();
}

class _ActivitiesTabState
    extends ConsumerState<ActivitiesTab> {
  Set<String> _selectedCategoryIds = {};

  @override
  Widget build(BuildContext context) {
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
            context.push(AppRoutes.addActivity),
        tooltip: 'Add activity',
        child: Icon(
          Icons.add,
          color: colors.onPrimary,
        ),
      )
          .animateSafely(context)
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
          final filtered =
              filterActivitiesByCategories(
            activities,
            _selectedCategoryIds,
          );
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
              SliverToBoxAdapter(
                child: _CategoryFilterChipRow(
                  selectedCategoryIds:
                      _selectedCategoryIds,
                  onToggle: (id) {
                    setState(() {
                      if (_selectedCategoryIds
                          .contains(id)) {
                        _selectedCategoryIds.remove(
                          id,
                        );
                      } else {
                        _selectedCategoryIds.add(
                          id,
                        );
                      }
                      _selectedCategoryIds =
                          Set.of(
                        _selectedCategoryIds,
                      );
                    });
                    ref
                        .read(
                          behavioralEventServiceProvider,
                        )
                        .log(
                          'filter_applied',
                          extra: {
                            'category_id': id,
                            'active_filter_count':
                                _selectedCategoryIds
                                    .length,
                          },
                        );
                  },
                  onClearAll: () {
                    final previousCount =
                        _selectedCategoryIds.length;
                    setState(() {
                      _selectedCategoryIds = {};
                    });
                    ref
                        .read(
                          behavioralEventServiceProvider,
                        )
                        .log(
                          'filter_cleared',
                          extra: {
                            'previous_filter_count':
                                previousCount,
                          },
                        );
                  },
                ),
              ),
              if (filtered.isEmpty &&
                  _selectedCategoryIds.isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FilteredEmptyState(
                    colors: colors,
                    onClearFilters: () {
                      setState(() {
                        _selectedCategoryIds = {};
                      });
                    },
                  ),
                )
              else ...[
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
                            bottom:
                                OutAboutSpacing.sm,
                          ),
                          child: _ActivityListCard(
                            activity:
                                filtered[index],
                            colors: colors,
                            isDark: isDark,
                            index: index,
                            ref: ref,
                            temperatureUnit:
                                temperatureUnit,
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: OutAboutSpacing.xxxl,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CategoryFilterChipRow
// ---------------------------------------------------------------------------

class _CategoryFilterChipRow extends ConsumerWidget {
  const _CategoryFilterChipRow({
    required this.selectedCategoryIds,
    required this.onToggle,
    required this.onClearAll,
  });

  final Set<String> selectedCategoryIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors =
        ref.watch(weatherThemeColorsProvider);
    final categoriesAsync =
        ref.watch(categoriesProvider);

    return categoriesAsync.when(
      loading: () => _ChipRowShimmer(colors: colors),
      error: (error, stackTrace) {
        log(
          'Categories failed to load, hiding '
          'filter row',
          error: error,
          name: 'ActivitiesTab',
        );
        return const SizedBox.shrink();
      },
      data: (categories) {
        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }
        final isAllSelected =
            selectedCategoryIds.isEmpty;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: OutAboutSpacing.md,
            vertical: OutAboutSpacing.sm,
          ),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                isSelected: isAllSelected,
                selectedColor: colors.primary,
                selectedTextColor: colors.onPrimary,
                colors: colors,
                onTap: () {
                  OutAboutHaptics
                      .onConditionToggle();
                  onClearAll();
                  // Feature 5 hook:
                  // filter_cleared fires here
                },
              ),
              ...categories.map((category) {
                final id = category.id!;
                final isSelected =
                    selectedCategoryIds.contains(id);
                return Padding(
                  padding: const EdgeInsets.only(
                    left: OutAboutSpacing.sm,
                  ),
                  child: _FilterChip(
                    label: category.name,
                    isSelected: isSelected,
                    selectedColor: colors.primary
                        .withValues(alpha: 0.15),
                    selectedBorderColor:
                        colors.primaryInteractive,
                    selectedTextColor:
                        colors.primaryInteractive,
                    colors: colors,
                    onTap: () {
                      OutAboutHaptics
                          .onConditionToggle();
                      onToggle(id);
                      // Feature 5 hook:
                      // filter_applied fires here
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _FilterChip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.colors,
    required this.onTap,
    this.selectedBorderColor,
    this.selectedTextColor,
  });

  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color? selectedBorderColor;
  final Color? selectedTextColor;
  final WeatherThemeColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.sm,
              vertical: OutAboutSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor
                  : colors.surface,
              borderRadius: BorderRadius.circular(
                OutAboutRadius.full,
              ),
              border: Border.all(
                color: isSelected
                    ? (selectedBorderColor ??
                        selectedColor)
                    : colors.divider,
              ),
            ),
            child: Text(
              label,
              style: OutAboutTypography.labelMedium(
                colors,
              ).copyWith(
                color: isSelected
                    ? selectedTextColor
                    : colors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChipRowShimmer
// ---------------------------------------------------------------------------

class _ChipRowShimmer extends StatelessWidget {
  const _ChipRowShimmer({required this.colors});

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: OutAboutSpacing.md,
        vertical: OutAboutSpacing.sm,
      ),
      child: Row(
        children: List.generate(4, (index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0
                  ? 0
                  : OutAboutSpacing.sm,
            ),
            child: MotionSafeShimmer(
              baseColor: colors.surface,
              highlightColor: colors.divider,
              child: Container(
                width: 72,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius:
                      BorderRadius.circular(
                    OutAboutRadius.full,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FilteredEmptyState
// ---------------------------------------------------------------------------

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({
    required this.colors,
    required this.onClearFilters,
  });

  final WeatherThemeColors colors;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          OutAboutSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 48,
              color: colors.textSecondary,
            ),
            const SizedBox(
              height: OutAboutSpacing.md,
            ),
            Text(
              'No activities in these categories',
              style:
                  OutAboutTypography.headingMedium(
                colors,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: OutAboutSpacing.md,
            ),
            TextButton(
              onPressed: onClearFilters,
              child: Text(
                'Clear filters',
                style:
                    OutAboutTypography.labelLarge(
                  colors,
                ).copyWith(
                  color: colors.primaryInteractive,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animateSafely(context)
        .fadeIn(
          duration:
              OutAboutAnimations.standardDuration,
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
      onDismissed: (_) async {
        if (activity.id == null) return;
        try {
          await ref
              .read(activityRepositoryProvider)
              .archive(activity.id!);
          ref
              .read(behavioralEventServiceProvider)
              .log(
                'wishlist_removed',
                extra: {
                  'activity_id': activity.id,
                  'method': 'swipe_dismiss',
                },
              );
          OutAboutHaptics.onActivitySave();
          ref.invalidate(activitiesProvider);
        } catch (e, st) {
          log(
            'Failed to archive activity from '
            'swipe-dismiss',
            error: e,
            stackTrace: st,
            name: 'ActivitiesTab',
          );
          ref.invalidate(activitiesProvider);
        }
      },
      child: Semantics(
        label: 'Activity: ${activity.name}',
        button: true,
        child: GestureDetector(
          onTap: () {
            if (activity.id != null) {
              context.push(
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
        .animateSafely(context)
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
      final min = profile.tempMin != null
          ? (temperatureUnit == 'F'
              ? _celsiusToFahrenheit(profile.tempMin!)
              : profile.tempMin!.round())
          : null;
      final max = profile.tempMax != null
          ? (temperatureUnit == 'F'
              ? _celsiusToFahrenheit(profile.tempMax!)
              : profile.tempMax!.round())
          : null;
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
      final label =
          profile.precipLevel == PrecipLevel.rainOnly
              ? 'Only when raining'
              : 'Avoid rain';
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
      final windValue = temperatureUnit == 'F'
          ? _kmhToMph(profile.windMax!)
          : profile.windMax!.round();
      chips.add(
        _ConditionChip(
          label: 'Wind < $windValue $windUnit',
          colors: colors,
        ),
      );
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
              'No activities yet',
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
                    context.push(AppRoutes.addActivity),
                child: const Text('Add Activity'),
              ),
            ),
          ],
        ),
      ),
    ).animateSafely(context).fadeIn(
          duration:
              OutAboutAnimations.standardDuration,
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
                MotionSafeShimmer(
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
                ).copyWith(color: colors.primaryInteractive),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
