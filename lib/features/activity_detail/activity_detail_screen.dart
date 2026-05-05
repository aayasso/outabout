import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/condition_profile.dart';
import '../../models/activity.dart';
import '../../services/behavioral_event_service.dart';
import '../home/home_providers.dart';
import '../shared/condition_profile_form.dart';

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
  bool _isSaving = false;
  String? _errorMessage;

  // Condition form state
  bool _tempEnabled = false;
  double _tempMin = 15.0;
  double _tempMax = 30.0;
  bool _precipEnabled = false;
  String _precipLevel = 'none';
  bool _windEnabled = false;
  double _windMax = 25.0;
  bool _uvEnabled = false;
  double _uvMin = 0.0;
  double _uvMax = 11.0;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initializeControllers(Activity activity) {
    if (_initialized) return;
    _nameController.text = activity.name;
    _notesController.text = activity.notes ?? '';

    final profile = activity.conditionProfile;
    if (profile != null) {
      _tempEnabled = profile.tempEnabled;
      _tempMin = profile.tempMin ?? 15.0;
      _tempMax = profile.tempMax ?? 30.0;
      _precipEnabled = profile.precipEnabled;
      _precipLevel = profile.precipLevel ?? 'none';
      _windEnabled = profile.windEnabled;
      _windMax = profile.windMax ?? 25.0;
      _uvEnabled = profile.uvEnabled;
      _uvMin = profile.uvMin ?? 0.0;
      _uvMax = profile.uvMax ?? 11.0;
    }
    _initialized = true;
  }

  Future<void> _onSave(Activity original) async {
    if (_nameController.text.trim().isEmpty) return;

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
        categoryIds: original.categoryIds,
        isArchived: original.isArchived,
        geographicContext: original.geographicContext,
      );

      final hasConditions = _tempEnabled ||
          _precipEnabled ||
          _windEnabled ||
          _uvEnabled;

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
              uvEnabled: _uvEnabled,
              uvMin: _uvEnabled ? _uvMin : null,
              uvMax: _uvEnabled ? _uvMax : null,
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

      if (mounted) context.pop();
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
      OutAboutHaptics.onActivitySave();
      ref.invalidate(activitiesProvider);
      if (mounted) context.pop();
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
                _isSaving ? null : () => context.pop(),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            style: OutAboutTypography.bodyLarge(colors),
            decoration: InputDecoration(
              labelText: 'Activity Name',
              labelStyle:
                  OutAboutTypography.labelMedium(colors),
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
          TextField(
            controller: _notesController,
            style: OutAboutTypography.bodyMedium(colors),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              labelStyle:
                  OutAboutTypography.labelMedium(colors),
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
          const SizedBox(height: OutAboutSpacing.lg),
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
          const SizedBox(height: OutAboutSpacing.sm),
          ConditionSection(
            title: 'UV Index',
            icon: Icons.wb_sunny,
            enabled: _uvEnabled,
            onToggled: (v) =>
                setState(() => _uvEnabled = v),
            child: UvSection(
              colors: colors,
              min: _uvMin,
              max: _uvMax,
              onChanged: (range) => setState(() {
                _uvMin = range.start;
                _uvMax = range.end;
              }),
            ),
          ),
          const SizedBox(height: OutAboutSpacing.lg),
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
              onPressed: _nameController.text
                          .trim()
                          .isEmpty ||
                      _isSaving
                  ? null
                  : () => _onSave(activity),
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
            onPressed: () => context.pop(),
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
            onPressed: () => context.pop(),
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
