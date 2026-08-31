import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/motion.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/condition_profile.dart';
import '../../data/models/activity.dart';
import '../../data/models/daily_forecast.dart';
import '../../data/models/schedule_day.dart';
import '../../services/behavioral_event_service.dart';
import '../../widgets/add_to_calendar_action.dart';
import '../../widgets/category_chip_picker.dart';
import '../../widgets/find_and_book_sheet.dart';
import '../../widgets/outcome_prompt.dart';
import '../home/home_providers.dart';
import '../outcomes/outcome_providers.dart';
import '../outcomes/outcome_stats.dart';
import '../suggestions/condition_suggestion.dart';
import '../suggestions/suggestion_providers.dart';
import 'widgets/activity_record_section.dart';
import 'widgets/condition_suggestion_card.dart';
import '../shared/condition_profile_form.dart';

const int maxNameLength = 50;
const int maxNotesLength = 200;

class ActivityDetailScreen extends ConsumerStatefulWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  ConsumerState<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends ConsumerState<ActivityDetailScreen> {
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

  bool _recordRefreshed = false;

  /// Refetches the history on every entry, not just after an answer.
  ///
  /// activityOutcomesProvider is a non-autoDispose family, so its list
  /// survives navigation and lives as long as the process. Until now the only
  /// thing that refreshed it was OutcomeAnswerController.submit — which meant
  /// a day answered from the schedule tab, or an opportunity recorded while
  /// the app sat open, was missing from the heat map until the next launch.
  /// The record is the reason to open this screen; showing a stale one is
  /// worse than showing a shimmer for a moment.
  ///
  /// Here rather than in [initState], where `ref` cannot reach the provider
  /// scope yet, and rather than in a post-frame callback, which would paint
  /// the stale record and then swap it — the flicker this exists to prevent.
  /// This runs before the first build, so that build already sees the refetch
  /// and renders `_RecordShimmer`.
  ///
  /// Guarded because dependencies change for unrelated reasons — a theme
  /// switch, a keyboard opening — and refetching on each of those would put
  /// the record into a shimmer every time the weather did something.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_recordRefreshed) return;
    _recordRefreshed = true;
    ref.invalidate(activityOutcomesProvider(widget.activityId));
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
  /// The soonest upcoming day this activity matches, today included.
  ///
  /// The calendar action needs *a* day, and unlike the schedule card this
  /// screen usually has no today-match. Days arrive in forecast order, so the
  /// first hit is the nearest one.
  DailyForecast? _nextMatch(List<ScheduleDay> days) {
    for (final day in days) {
      final matches = day.matchedActivities.any(
        (a) => a.id == widget.activityId,
      );
      if (matches) return day.forecast;
    }
    return null;
  }

  DailyForecast? _todaysMatch(List<ScheduleDay> days) {
    final now = ref.read(nowProvider)();
    for (final day in days) {
      // Normalised for the reason localDateKeyOf documents: forecast dates are
      // UTC instants, so comparing `.day` raw is the wrong day for part of
      // every day in much of the world.
      final date = day.forecast.date.toLocal();
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      if (!isToday) continue;
      final matches = day.matchedActivities.any(
        (a) => a.id == widget.activityId,
      );
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
      ref
          .read(behavioralEventServiceProvider)
          .log(
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

      final hasConditions = _tempEnabled || _precipEnabled || _windEnabled;

      final profile = hasConditions
          ? ConditionProfile(
              id: '',
              activityId: original.id!,
              tempEnabled: _tempEnabled,
              tempMin: _tempEnabled ? _tempMin : null,
              tempMax: _tempEnabled ? _tempMax : null,
              precipEnabled: _precipEnabled,
              precipLevel: _precipEnabled ? _precipLevel : null,
              windEnabled: _windEnabled,
              windMax: _windEnabled ? _windMax : null,
            )
          : null;

      await repo.updateWithConditions(updatedActivity, profile);

      await events.log(
        'condition_profile_updated',
        extra: {'activity_id': original.id},
      );

      OutAboutHaptics.onActivitySave();

      ref.invalidate(activitiesProvider);
      ref.invalidate(activityDetailProvider(widget.activityId));
      if (mounted) context.popOrGo();
    } catch (e, st) {
      // `e` used to be bound and dropped, so an RLS denial, a constraint
      // violation and a dropped socket were indistinguishable in the field.
      log('Failed to save activity', error: e, stackTrace: st);
      // Guarded like the finally block below. A session that ends mid-save
      // redirects and disposes this screen before the failing write returns,
      // and setState on a dead State is a null-check failure in release with
      // no handler to catch it.
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save. Please try again.';
        });
      }
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
            style: OutAboutTypography.headingMedium(colors),
          ),
          content: Text(
            'This activity will be hidden from your list.',
            style: OutAboutTypography.bodyMedium(colors),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: OutAboutTypography.labelLarge(colors),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Archive',
                style: OutAboutTypography.labelLarge(
                  colors,
                ).copyWith(color: OutAboutColors.errorColor),
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
      ref
          .read(behavioralEventServiceProvider)
          .log(
            'wishlist_removed',
            extra: {'activity_id': activity.id, 'method': 'archive_button'},
          );
      OutAboutHaptics.onActivitySave();
      ref.invalidate(activitiesProvider);
      if (mounted) context.popOrGo();
    } catch (e) {
      // Same reason as _onSave: the archive can outlive this screen.
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to archive. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final profileAsync = ref.watch(profileProvider);
    final temperatureUnit = profileAsync.valueOrNull?.temperatureUnit ?? 'F';
    final activityAsync = ref.watch(activityDetailProvider(widget.activityId));
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.text),
            onPressed: _isSaving ? null : () => context.popOrGo(),
            tooltip: 'Go back',
          ),
          title: Text(
            'Edit Activity',
            style: OutAboutTypography.headingLarge(colors),
          ),
        ),
        body: activityAsync.when(
          loading: () => _ActivityDetailShimmer(colors: colors),
          error: (error, _) => _ActivityDetailError(
            colors: colors,
            onRetry: () =>
                ref.invalidate(activityDetailProvider(widget.activityId)),
          ),
          data: (activity) {
            if (activity == null) {
              return _ActivityNotFound(colors: colors);
            }
            if (activity.isArchived) {
              return _ArchivedBanner(colors: colors);
            }
            _initializeControllers(activity);
            return _buildForm(activity, colors, temperatureUnit);
          },
        ),
      ),
    );
  }

  /// Records an answer for a day the user reached from the heat map.
  ///
  /// Only offered for days still inside the grace window. Parsing the civil
  /// date back to a local DateTime here is safe and necessary: the controller
  /// normalises it straight back with localDateKeyOf, and the round trip
  /// cannot cross a day boundary because midday is nowhere near one.
  ///
  /// Returns what the write changed, so the sheet can say it back — a
  /// milestone crossed from the heat map is the same event as one crossed from
  /// the prompt, and was previously logged upstream and never mentioned.
  ///
  /// Failures are swallowed and reported as an empty result, matching
  /// `OutcomePrompt._record`. A history write that fails must not put a red
  /// screen over a day the user has already answered — and now that the sheet
  /// waits on this, a throw would leave the modal open with no way out, since
  /// the close timer is set from the line that follows.
  Future<({OutcomeMilestone? milestone, OutcomeStats? stats})> _answerPastDay(
    String activityId,
    String localDate,
    String outcome,
  ) async {
    final parts = localDate.split('-').map(int.parse).toList();
    try {
      return await ref
          .read(outcomeAnswerControllerProvider)
          .submit(
            activityId: activityId,
            matchedDay: DateTime(parts[0], parts[1], parts[2], 12),
            outcome: outcome,
          );
    } catch (e) {
      log('ActivityDetailScreen: could not record the past day — $e');
      return (milestone: null, stats: null);
    }
  }

  /// Applies an accepted suggestion, to the database and to this form.
  ///
  /// Both halves are required and the second is the easy one to forget. The
  /// condition sliders are local state, initialised once per screen entry
  /// behind `_initialized`, so persisting alone would leave the slider showing
  /// the value the suggestion just replaced — and the next Save would write
  /// that stale number straight back over the change the user asked for.
  ///
  /// Errors propagate: the card catches them and says so. This is the one
  /// write on this screen the user explicitly requested, so unlike the outcome
  /// history it must not fail quietly.
  Future<void> _applySuggestion(
    Activity activity,
    ConditionSuggestion suggestion,
  ) async {
    final updated = await ref
        .read(suggestionControllerProvider)
        .accept(activity: activity, suggestion: suggestion);

    if (!mounted) return;
    setState(() {
      switch (suggestion.dimension) {
        case SuggestionDimension.windMax:
          _windMax = updated.windMax ?? _windMax;
        case SuggestionDimension.tempMax:
          _tempMax = updated.tempMax ?? _tempMax;
        case SuggestionDimension.tempMin:
          _tempMin = updated.tempMin ?? _tempMin;
      }
    });
  }

  Widget _buildForm(
    Activity activity,
    WeatherThemeColors colors,
    String temperatureUnit,
  ) {
    final schedule = ref.watch(scheduleMatchProvider).valueOrNull;
    final todaysForecast = schedule == null ? null : _todaysMatch(schedule);
    final nextForecast = schedule == null ? null : _nextMatch(schedule);

    return SingleChildScrollView(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The record comes first. The history is why this screen is
              // worth opening; the form is what you do once you have seen it.
              if (activity.id case final id?) ...[
                ActivityRecordSection(
                  activityId: id,
                  activityName: activity.name,
                  onAnswerDay: (localDate, outcome) =>
                      _answerPastDay(id, localDate, outcome),
                ),
                // Reads as a footnote to the record above it rather than a
                // section of its own — it is an inference drawn from exactly
                // that history, and it sits above the sliders it would move.
                if (ref.watch(conditionSuggestionProvider(id)).valueOrNull
                    case final suggestion?)
                  ConditionSuggestionCard(
                    activityId: id,
                    activityName: activity.name,
                    suggestion: suggestion,
                    temperatureUnit: temperatureUnit,
                    onAccept: (s) => _applySuggestion(activity, s),
                    onDecline: (s) =>
                        ref.read(suggestionControllerProvider).decline(id, s),
                  ),
              ],
              TextField(
                controller: _nameController,
                style: OutAboutTypography.bodyLarge(colors),
                decoration: InputDecoration(
                  labelText: 'Activity name *',
                  labelStyle: OutAboutTypography.labelMedium(colors),
                  errorText: _nameController.text.trim().length > maxNameLength
                      ? 'Name must be $maxNameLength'
                            ' characters or less'
                      : null,
                  errorStyle: OutAboutTypography.bodySmall(
                    colors,
                  ).copyWith(color: OutAboutColors.errorColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.primaryInteractive),
                  ),
                ),
              ),
              const SizedBox(height: OutAboutSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _notesController,
                    style: OutAboutTypography.bodyMedium(colors),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      labelStyle: OutAboutTypography.labelMedium(colors),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: colors.divider),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: colors.primaryInteractive,
                        ),
                      ),
                    ),
                  ),
                  if (_notesController.text.isNotEmpty) ...[
                    const SizedBox(height: OutAboutSpacing.xs),
                    Text(
                      '${_notesController.text.length}'
                      ' / $maxNotesLength',
                      style: OutAboutTypography.bodySmall(colors).copyWith(
                        color: _notesController.text.length > maxNotesLength
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
                  final isNowSelected = _selectedCategoryIds.contains(id);
                  ref
                      .read(behavioralEventServiceProvider)
                      .log(
                        isNowSelected
                            ? 'category_selected'
                            : 'category_deselected',
                        extra: {
                          'category_id': id,
                          'activity_id': widget.activityId,
                        },
                      );
                },
                onCreateCategory: () =>
                    showCreateCategoryFlow(context, ref, colors),
              ),
              const SizedBox(height: OutAboutSpacing.md),
              Text(
                'Weather Conditions',
                style: OutAboutTypography.headingMedium(colors),
              ),
              const SizedBox(height: OutAboutSpacing.md),
              ConditionSection(
                title: 'Temperature',
                icon: Icons.thermostat,
                enabled: _tempEnabled,
                onToggled: (v) => setState(() => _tempEnabled = v),
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
                onToggled: (v) => setState(() => _precipEnabled = v),
                child: PrecipitationSection(
                  colors: colors,
                  level: _precipLevel,
                  onChanged: (v) => setState(() => _precipLevel = v),
                ),
              ),
              const SizedBox(height: OutAboutSpacing.sm),
              ConditionSection(
                title: 'Wind',
                icon: Icons.air,
                enabled: _windEnabled,
                onToggled: (v) => setState(() => _windEnabled = v),
                child: WindSection(
                  colors: colors,
                  maxWind: _windMax,
                  temperatureUnit: temperatureUnit,
                  onChanged: (v) => setState(() => _windMax = v),
                ),
              ),
              const SizedBox(height: OutAboutSpacing.lg),
              _FindAndBookButton(
                activity: activity,
                colors: colors,
                forecastDay: todaysForecast,
              ),
              // Hidden only when nothing matches in the whole 5-day window —
              // there would be no honest date to put on the event.
              if (nextForecast case final forecast?) ...[
                const SizedBox(height: OutAboutSpacing.sm),
                _AddToCalendarButton(
                  activity: activity,
                  colors: colors,
                  forecast: forecast,
                ),
              ],
              // Silent unless this activity matches today and it is past the
              // prompt hour — see OutcomePrompt.
              if (todaysForecast != null && activity.id != null)
                OutcomePrompt(
                  activityId: activity.id!,
                  activityName: activity.name,
                  matchedDay: todaysForecast.date,
                  // An activity that constrains nothing appears on every
                  // forecast day. Asking whether the user went is only
                  // meaningful when the app actually claimed the weather
                  // suited it — the same rule the schedule card applies.
                  matchIsConstrained:
                      activity.conditionProfile?.isConstraining ?? false,
                  forecastDay: todaysForecast,
                ),
              const SizedBox(height: OutAboutSpacing.md),
              if (_errorMessage != null) ...[
                _ErrorBanner(colors: colors, message: _errorMessage!),
                const SizedBox(height: OutAboutSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSave ? () => _onSave(activity) : null,
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
                  padding: const EdgeInsets.only(top: OutAboutSpacing.sm),
                  child: Text(
                    reason,
                    style: OutAboutTypography.bodySmall(
                      colors,
                    ).copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: OutAboutSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _isSaving ? null : () => _onArchive(activity),
                  child: Text(
                    'Archive Activity',
                    style: OutAboutTypography.labelLarge(
                      colors,
                    ).copyWith(color: OutAboutColors.errorColor),
                  ),
                ),
              ),
              const SizedBox(height: OutAboutSpacing.xl),
            ],
          ),
        )
        .animateSafely(context)
        .fadeIn(duration: OutAboutAnimations.standardDuration)
        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }
}

// ---------------------------------------------------------------------------
// _FindAndBookButton
// ---------------------------------------------------------------------------

/// Adds this activity's next matching day to the device calendar.
///
/// One-shot: the event is created and forgotten. Nothing here syncs it,
/// updates it, or removes it later.
class _AddToCalendarButton extends ConsumerWidget {
  const _AddToCalendarButton({
    required this.activity,
    required this.colors,
    required this.forecast,
  });

  final Activity activity;
  final WeatherThemeColors colors;
  final DailyForecast forecast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(
          Icons.event_available_outlined,
          size: 20,
          color: colors.primaryInteractive,
        ),
        label: Text(
          'Add to Calendar',
          style: OutAboutTypography.labelLarge(
            colors,
          ).copyWith(color: colors.primaryInteractive),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: colors.primaryInteractive),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
          ),
        ),
        onPressed: () => addActivityToCalendar(
          context,
          ref,
          activityName: activity.name,
          activityId: activity.id,
          forecast: forecast,
        ),
      ),
    );
  }
}

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
        icon: Icon(
          Icons.travel_explore,
          size: 20,
          color: colors.primaryInteractive,
        ),
        label: Text(
          'Find & book',
          style: OutAboutTypography.labelLarge(
            colors,
          ).copyWith(color: colors.primaryInteractive),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: colors.primaryInteractive),
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
      child: MotionSafeShimmer(
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
                borderRadius: BorderRadius.circular(OutAboutRadius.sm),
              ),
            ),
            const SizedBox(height: OutAboutSpacing.lg),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(OutAboutRadius.sm),
              ),
            ),
            const SizedBox(height: OutAboutSpacing.md),
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(OutAboutRadius.sm),
              ),
            ),
            const SizedBox(height: OutAboutSpacing.lg),
            for (int i = 0; i < 4; i++) ...[
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(OutAboutRadius.cards),
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
  const _ActivityDetailError({required this.colors, required this.onRetry});

  final WeatherThemeColors colors;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: colors.textSecondary, size: 48),
          const SizedBox(height: OutAboutSpacing.md),
          Text(
            'Something went wrong',
            style: OutAboutTypography.bodyMedium(colors),
          ),
          const SizedBox(height: OutAboutSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
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
          Icon(Icons.search_off, color: colors.textSecondary, size: 48),
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
          Icon(Icons.archive_outlined, color: OutAboutColors.warning, size: 48),
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
  const _ErrorBanner({required this.colors, required this.message});

  final WeatherThemeColors colors;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OutAboutSpacing.sm),
      decoration: BoxDecoration(
        color: OutAboutColors.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(OutAboutRadius.sm),
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
              style: OutAboutTypography.bodySmall(
                colors,
              ).copyWith(color: OutAboutColors.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
