import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/condition_profile.dart';
import '../../data/models/activity.dart';
import '../../data/models/daily_forecast.dart';
import '../../data/models/schedule_day.dart';
import '../../services/behavioral_event_service.dart';
import '../../widgets/category_chip_picker.dart';
import '../../widgets/find_and_book_sheet.dart';
import '../../widgets/outcome_prompt.dart';
import '../home/home_providers.dart';
import '../shared/condition_profile_form.dart';

const int maxNameLength = 50;
const int maxNotesLength = 200;

class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState
    extends ConsumerState<ActivityDetailScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  bool _initialized = false;
  final Set<String> _selectedCategoryIds = {};
  bool _isSaving = false;
  String? _errorMessage;

  // Condition form state
  bool _tempEnabled = false;
  double _tempMin = 15.0;
  double _tempMax = 30.0;
  bool _precipEnabled = false;
  String _precipLevel = PrecipLevel.avoidRain;
  bool _windEnabled = false;
  double _windMax = 25.0;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _notesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Today's forecast, if this activity matches it.
  ///
  /// Drives both the outcome prompt (which asks only about today) and the
  /// weather attached to anything this screen logs.
  DailyForecast? _todaysMatch(List<ScheduleDay> days) {
    final now = ref.read(nowProvider)();
    for (final day in days) {
      final date = day.forecast.date;
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      if (!isToday) continue;
      final matches =
          day.matchedActivities.any((a) => a.id == widget.activityId);
      return matches ? day.forecast : null;
    }
    return null;
  }

  void _initializeControllers(Activity activity) {
    if (_initialized) return;
    _nameController.text = activity.name;
    _notesController.text = activity.notes ?? '';
    _selectedCategoryIds.addAll(activity.categoryIds);

    final profile = activity.conditionProfile;
    if (profile != null) {
      _tempEnabled = profile.tempEnabled;
      _tempMin = profile.tempMin ?? 15.0;
      _tempMax = profile.tempMax ?? 30.0;
      _precipEnabled = profile.precipEnabled;
      _precipLevel = PrecipLevel.normalize(profile.precipLevel);
      _windEnabled = profile.windEnabled;
      _windMax = profile.windMax ?? 25.0;
    }
    _initialized = true;

    // One per screen entry. Deferred because this runs inside build() and
    // logging synchronously would mutate providers mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(behavioralEventServiceProvider).log(
            'activity_viewed',
            extra: {'activity_id': activity.id},
            conditions: ref.read(conditionsSnapshotProvider)(),
          );
    });
  }

  bool get _canSave {
    if (_isSaving) return false;
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > maxNameLength) {
      return false;
    }
    if (_notesController.text.length > maxNotesLength) {
      return false;
    }
    return true;
  }

  String? get _disabledReason {
    if (_isSaving) return null;
    final name = _nameController.text.trim();
    if (name.isEmpty) return null;
    if (name.length > maxNameLength) {
      return 'Name is too long';
    }
    if (_notesController.text.length > maxNotesLength) {
      return 'Notes exceed $maxNotesLength characters';
    }
    return null;
  }

  Future<void> _onSave(Activity original) async {
    if (!_canSave) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(activityRepositoryProvider);
      final events = ref.read(behavioralEventServiceProvider);

      final updatedActivity = Activity(
        id: original.id,
        userId: original.userId,
        name: _nameController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        url: original.url,
        location: original.location,
        categoryIds: _selectedCategoryIds.toList(),
        isArchived: original.isArchived,
        geographicContext: original.geographicContext,
      );

      final hasConditions = _tempEnabled ||
          _precipEnabled ||
          _windEnabled;

      final profile = hasConditions
          ? ConditionProfile(
              id: '',
              activityId: original.id!,
              tempEnabled: _tempEnabled,
              tempMin: _tempEnabled ? _tempMin : null,
              tempMax: _tempEnabled ? _tempMax : null,
              precipEnabled: _precipEnabled,
              precipLevel:
                  _precipEnabled ? _precipLevel : null,
              windEnabled: _windEnabled,
              windMax: _windEnabled ? _windMax : null,
            )
          : null;

      await repo.updateWithConditions(
        updatedActivity,
        profile,
      );

      await events.log(
        'condition_profile_updated',
        extra: {'activity_id': original.id},
      );

      OutAboutHaptics.onActivitySave();

      ref.invalidate(activitiesProvider);
      ref.invalidate(
        activityDetailProvider(widget.activityId),
      );
      if (mounted) context.popOrGo();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _onArchive(Activity activity) async {
    final colors = ref.read(weatherThemeColorsProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.cardBackground,
          title: Text(
            'Archive Activity?',
            style:
                OutAboutTypography.headingMedium(colors),
          ),
          content: Text(
            'This activity will be hidden from your list.',
            style: OutAboutTypography.bodyMedium(colors),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style:
                    OutAboutTypography.labelLarge(colors),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: Text(
                'Archive',
                style: OutAboutTypography.labelLarge(
                        colors)
                    .copyWith(
                        color: OutAboutColors.errorColor),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(activityRepositoryProvider);
      await repo.archive(activity.id!);
      ref.read(behavioralEventServiceProvider).log(
        'wishlist_removed',
        extra: {
          'activity_id': activity.id,
          'method': 'archive_button',
        },
      );
      OutAboutHaptics.onActivitySave();
      ref.invalidate(activitiesProvider);
      if (mounted) context.popOrGo();
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to archive. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final profileAsync = ref.watch(profileProvider);
    final temperatureUnit =
        profileAsync.valueOrNull?.temperatureUnit ?? 'F';
    final activityAsync = ref.watch(
      activityDetailProvider(widget.activityId),
    );
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: colors.text,
            ),
            onPressed:
                _isSaving ? null : () => context.popOrGo(),
            tooltip: 'Go back',
          ),
          title: Text(
            'Edit Activity',
            style:
                OutAboutTypography.headingLarge(colors),
          ),
        ),
        body: activityAsync.when(
          loading: () =>
              _ActivityDetailShimmer(colors: colors),
          error: (error, _) => _ActivityDetailError(
            colors: colors,
            onRetry: () => ref.invalidate(
              activityDetailProvider(widget.activityId),
            ),
          ),
          data: (activity) {
            if (activity == null) {
              return _ActivityNotFound(colors: colors);
            }
            if (activity.isArchived) {
              return _ArchivedBanner(colors: colors);
            }
            _initializeControllers(activity);
            return _buildForm(
              activity, colors, temperatureUnit);
          },
        ),
      ),
    );
  }

  Widget _buildForm(
    Activity activity,
    WeatherThemeColors colors,
    String temperatureUnit,
  ) {
    final schedule = ref.watch(scheduleMatchProvider).valueOrNull;
    final todaysForecast =
        schedule == null ? null : _todaysMatch(schedule);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            style: OutAboutTypography.bodyLarge(colors),
            decoration: InputDecoration(
              labelText: 'Activity name *',
              labelStyle:
                  OutAboutTypography.labelMedium(colors),
              errorText: _nameController.text
                          .trim()
                          .length >
                      maxNameLength
                  ? 'Name must be $maxNameLength'
                      ' characters or less'
                  : null,
              errorStyle:
                  OutAboutTypography.bodySmall(colors)
                      .copyWith(
                color: OutAboutColors.errorColor,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: colors.divider),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: colors.primary),
              ),
            ),
          ),
          const SizedBox(height: OutAboutSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _notesController,
                style:
                    OutAboutTypography.bodyMedium(colors),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle:
                      OutAboutTypography.labelMedium(
                    colors,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: colors.divider),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: colors.primary),
                  ),
                ),
              ),
              if (_notesController
                  .text.isNotEmpty) ...[
                const SizedBox(
                  height: OutAboutSpacing.xs,
                ),
                Text(
                  '${_notesController.text.length}'
                  ' / $maxNotesLength',
                  style: OutAboutTypography.bodySmall(
                    colors,
                  ).copyWith(
                    color:
                        _notesController.text.length >
                                maxNotesLength
                            ? OutAboutColors.errorColor
                            : colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: OutAboutSpacing.lg),
          CategoryChipPicker(
            selectedIds: _selectedCategoryIds,
            onToggle: (id) {
              setState(() {
                if (_selectedCategoryIds.contains(id)) {
                  _selectedCategoryIds.remove(id);
                } else {
                  _selectedCategoryIds.add(id);
                }
              });
              final isNowSelected =
                  _selectedCategoryIds.contains(id);
              ref
                  .read(behavioralEventServiceProvider)
                  .log(
                    isNowSelected
                        ? 'category_selected'
                        : 'category_deselected',
                    extra: {
                      'category_id': id,
                      'activity_id':
                          widget.activityId,
                    },
                  );
            },
            onCreateCategory: () =>
                showCreateCategoryFlow(
              context,
              ref,
              colors,
            ),
          ),
          const SizedBox(height: OutAboutSpacing.md),
          Text(
            'Weather Conditions',
            style:
                OutAboutTypography.headingMedium(colors),
          ),
          const SizedBox(height: OutAboutSpacing.md),
          ConditionSection(
            title: 'Temperature',
            icon: Icons.thermostat,
            enabled: _tempEnabled,
            onToggled: (v) =>
                setState(() => _tempEnabled = v),
            child: TemperatureSection(
              colors: colors,
              min: _tempMin,
              max: _tempMax,
              temperatureUnit: temperatureUnit,
              onChanged: (range) => setState(() {
                _tempMin = range.start;
                _tempMax = range.end;
              }),
            ),
          ),
          const SizedBox(height: OutAboutSpacing.sm),
          ConditionSection(
            title: 'Precipitation',
            icon: Icons.water_drop,
            enabled: _precipEnabled,
            onToggled: (v) =>
                setState(() => _precipEnabled = v),
            child: PrecipitationSection(
              colors: colors,
              level: _precipLevel,
              onChanged: (v) =>
                  setState(() => _precipLevel = v),
            ),
          ),
          const SizedBox(height: OutAboutSpacing.sm),
          ConditionSection(
            title: 'Wind',
            icon: Icons.air,
            enabled: _windEnabled,
            onToggled: (v) =>
                setState(() => _windEnabled = v),
            child: WindSection(
              colors: colors,
              maxWind: _windMax,
              temperatureUnit: temperatureUnit,
              onChanged: (v) =>
                  setState(() => _windMax = v),
            ),
          ),
          const SizedBox(height: OutAboutSpacing.lg),
          _FindAndBookButton(
            activity: activity,
            colors: colors,
            forecastDay: todaysForecast,
          ),
          // Silent unless this activity matches today and it is past the
          // prompt hour — see OutcomePrompt.
          if (todaysForecast != null && activity.id != null)
            OutcomePrompt(
              activityId: activity.id!,
              activityName: activity.name,
              matchedDay: todaysForecast.date,
              forecastDay: todaysForecast,
            ),
          const SizedBox(height: OutAboutSpacing.md),
          if (_errorMessage != null) ...[
            _ErrorBanner(
              colors: colors,
              message: _errorMessage!,
            ),
            const SizedBox(height: OutAboutSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSave
                  ? () => _onSave(activity)
                  : null,
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.background,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
          if (_disabledReason case final reason?)
            Padding(
              padding: const EdgeInsets.only(
                top: OutAboutSpacing.sm,
              ),
              child: Text(
                reason,
                style:
                    OutAboutTypography.bodySmall(colors)
                        .copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: OutAboutSpacing.md),
          Center(
            child: TextButton(
              onPressed:
                  _isSaving ? null : () => _onArchive(activity),
              child: Text(
                'Archive Activity',
                style: OutAboutTypography.labelLarge(colors)
                    .copyWith(
                        color: OutAboutColors.errorColor),
              ),
            ),
          ),
          const SizedBox(height: OutAboutSpacing.xl),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: OutAboutAnimations.standardDuration)
        .slideY(
          begin: 0.05,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }

}

// ---------------------------------------------------------------------------
// _FindAndBookButton
// ---------------------------------------------------------------------------

/// Opens the provider sheet for this activity.
///
/// Secondary to Save: this screen's job is editing, and finding somewhere to
/// go is the optional next step rather than the reason the user came here.
class _FindAndBookButton extends ConsumerWidget {
  const _FindAndBookButton({
    required this.activity,
    required this.colors,
    required this.forecastDay,
  });

  final Activity activity;
  final WeatherThemeColors colors;
  final DailyForecast? forecastDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final categoryNames = categories
        .where((c) => activity.categoryIds.contains(c.id))
        .map((c) => c.name)
        .toList();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(Icons.travel_explore, size: 20, color: colors.primary),
        label: Text(
          'Find & book',
          style: OutAboutTypography.labelLarge(colors)
              .copyWith(color: colors.primary),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: colors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
          ),
        ),
        onPressed: () => showFindAndBookSheet(
          context,
          ref,
          activityName: activity.name,
          activityId: activity.id,
          categoryNames: categoryNames,
          forecastDay: forecastDay,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivityDetailShimmer
// ---------------------------------------------------------------------------

class _ActivityDetailShimmer extends StatelessWidget {
  const _ActivityDetailShimmer({required this.colors});
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      child: Shimmer.fromColors(
        baseColor: colors.surface,
        highlightColor: colors.divider,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 24,
              width: 200,
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(
                  OutAboutRadius.sm,
                ),
              ),
            ),
            const SizedBox(height: OutAboutSpacing.lg),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(
                  OutAboutRadius.sm,
                ),
              ),
            ),
            const SizedBox(height: OutAboutSpacing.md),
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(
                  OutAboutRadius.sm,
                ),
              ),
            ),
            const SizedBox(height: OutAboutSpacing.lg),
            for (int i = 0; i < 4; i++) ...[
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(
                    OutAboutRadius.cards,
                  ),
                ),
              ),
              const SizedBox(height: OutAboutSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivityDetailError
// ---------------------------------------------------------------------------

class _ActivityDetailError extends StatelessWidget {
  const _ActivityDetailError({
    required this.colors,
    required this.onRetry,
  });

  final WeatherThemeColors colors;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            color: colors.textSecondary,
            size: 48,
          ),
          const SizedBox(height: OutAboutSpacing.md),
          Text(
            'Something went wrong',
            style: OutAboutTypography.bodyMedium(colors),
          ),
          const SizedBox(height: OutAboutSpacing.sm),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActivityNotFound
// ---------------------------------------------------------------------------

class _ActivityNotFound extends StatelessWidget {
  const _ActivityNotFound({required this.colors});
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            color: colors.textSecondary,
            size: 48,
          ),
          const SizedBox(height: OutAboutSpacing.md),
          Text(
            'Activity not found',
            style: OutAboutTypography.bodyMedium(colors),
          ),
          const SizedBox(height: OutAboutSpacing.sm),
          TextButton(
            onPressed: () => context.popOrGo(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ArchivedBanner
// ---------------------------------------------------------------------------

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({required this.colors});
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.archive_outlined,
            color: OutAboutColors.warning,
            size: 48,
          ),
          const SizedBox(height: OutAboutSpacing.md),
          Text(
            'This activity has been archived',
            style: OutAboutTypography.bodyMedium(colors),
          ),
          const SizedBox(height: OutAboutSpacing.sm),
          TextButton(
            onPressed: () => context.popOrGo(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorBanner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.colors,
    required this.message,
  });

  final WeatherThemeColors colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OutAboutSpacing.sm),
      decoration: BoxDecoration(
        color:
            OutAboutColors.errorColor.withValues(alpha: 0.1),
        borderRadius:
            BorderRadius.circular(OutAboutRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: OutAboutColors.errorColor,
            size: 20,
          ),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: OutAboutTypography.bodySmall(colors)
                  .copyWith(
                      color: OutAboutColors.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}

