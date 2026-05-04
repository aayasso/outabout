import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/condition_profile.dart';
import '../../features/home/home_providers.dart';
import '../../models/activity.dart';
import '../../services/behavioral_event_service.dart';

class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key});

  @override
  ConsumerState<AddActivityScreen> createState() =>
      _AddActivityScreenState();
}

class _AddActivityScreenState
    extends ConsumerState<AddActivityScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  // Condition toggles
  bool _tempEnabled = false;
  bool _precipEnabled = false;
  bool _windEnabled = false;
  bool _uvEnabled = false;

  // Condition values
  RangeValues _tempRange = const RangeValues(15, 30);
  String _precipLevel = 'none';
  double _windMax = 25;
  RangeValues _uvRange = const RangeValues(0, 11);

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && !_isSaving;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(
        supabaseClientProvider,
      );
      final userId = client.auth.currentUser!.id;

      final activity = Activity(
        userId: userId,
        name: name,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final profile = ConditionProfile(
        id: '',
        activityId: '',
        tempEnabled: _tempEnabled,
        tempMin: _tempEnabled ? _tempRange.start : null,
        tempMax: _tempEnabled ? _tempRange.end : null,
        precipEnabled: _precipEnabled,
        precipLevel: _precipEnabled ? _precipLevel : null,
        windEnabled: _windEnabled,
        windMax: _windEnabled ? _windMax : null,
        uvEnabled: _uvEnabled,
        uvMin: _uvEnabled ? _uvRange.start : null,
        uvMax: _uvEnabled ? _uvRange.end : null,
      );

      final repo = ref.read(activityRepositoryProvider);
      await repo.insertWithConditions(
        activity: activity,
        profile: profile,
      );

      ref.read(behavioralEventServiceProvider).log(
        'wishlist_added',
        extra: {'activity_name': name},
      );

      OutAboutHaptics.onActivitySave();
      ref.invalidate(activitiesProvider);

      if (mounted) context.pop();
    } catch (e, st) {
      log(
        'Failed to save activity',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage =
              'Could not save activity. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.surface,
          title: Text(
            'Add Activity',
            style: OutAboutTypography.headingLarge(colors),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed:
                _isSaving ? null : () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(
            OutAboutSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                _ErrorBanner(
                  message: _errorMessage!,
                  colors: colors,
                ),
              _ActivityNameField(
                controller: _nameController,
                colors: colors,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: OutAboutSpacing.md),
              _NotesField(
                controller: _notesController,
                colors: colors,
              ),
              const SizedBox(height: OutAboutSpacing.lg),
              Text(
                'Weather Conditions',
                style:
                    OutAboutTypography.headingMedium(colors),
              ),
              const SizedBox(height: OutAboutSpacing.sm),
              _TemperatureSection(
                enabled: _tempEnabled,
                range: _tempRange,
                colors: colors,
                onToggle: (v) {
                  OutAboutHaptics.onConditionToggle();
                  setState(() => _tempEnabled = v);
                },
                onChanged: (v) =>
                    setState(() => _tempRange = v),
              ),
              _PrecipitationSection(
                enabled: _precipEnabled,
                level: _precipLevel,
                colors: colors,
                onToggle: (v) {
                  OutAboutHaptics.onConditionToggle();
                  setState(() => _precipEnabled = v);
                },
                onChanged: (v) =>
                    setState(() => _precipLevel = v),
              ),
              _WindSection(
                enabled: _windEnabled,
                maxSpeed: _windMax,
                colors: colors,
                onToggle: (v) {
                  OutAboutHaptics.onConditionToggle();
                  setState(() => _windEnabled = v);
                },
                onChanged: (v) =>
                    setState(() => _windMax = v),
              ),
              _UvSection(
                enabled: _uvEnabled,
                range: _uvRange,
                colors: colors,
                onToggle: (v) {
                  OutAboutHaptics.onConditionToggle();
                  setState(() => _uvEnabled = v);
                },
                onChanged: (v) =>
                    setState(() => _uvRange = v),
              ),
              const SizedBox(height: OutAboutSpacing.lg),
              _SaveButton(
                canSave: _canSave,
                isSaving: _isSaving,
                colors: colors,
                onPressed: _save,
              ),
              const SizedBox(height: OutAboutSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.colors,
  });

  final String message;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: OutAboutSpacing.md,
      ),
      padding: const EdgeInsets.all(OutAboutSpacing.sm),
      decoration: BoxDecoration(
        color: OutAboutColors.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
          OutAboutRadius.sm,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: OutAboutColors.errorColor,
            size: 20,
          ),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: OutAboutTypography.bodyMedium(colors)
                  .copyWith(
                color: OutAboutColors.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityNameField extends StatelessWidget {
  const _ActivityNameField({
    required this.controller,
    required this.colors,
    required this.onChanged,
  });

  final TextEditingController controller;
  final WeatherThemeColors colors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: OutAboutTypography.bodyLarge(colors),
      decoration: InputDecoration(
        hintText: 'Activity name',
        hintStyle: OutAboutTypography.bodyLarge(colors)
            .copyWith(color: colors.textSecondary),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({
    required this.controller,
    required this.colors,
  });

  final TextEditingController controller;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: OutAboutTypography.bodyMedium(colors),
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'Notes (optional)',
        hintStyle: OutAboutTypography.bodyMedium(colors)
            .copyWith(color: colors.textSecondary),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _ConditionSection extends StatelessWidget {
  const _ConditionSection({
    required this.label,
    required this.enabled,
    required this.colors,
    required this.onToggle,
    required this.child,
  });

  final String label;
  final bool enabled;
  final WeatherThemeColors colors;
  final ValueChanged<bool> onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: OutAboutSpacing.sm,
      ),
      padding: const EdgeInsets.all(OutAboutSpacing.sm),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(
          OutAboutRadius.cards,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: OutAboutTypography.headingSmall(
                    colors,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: colors.primary,
              ),
            ],
          ),
          if (enabled) child,
        ],
      ),
    );
  }
}

class _TemperatureSection extends StatelessWidget {
  const _TemperatureSection({
    required this.enabled,
    required this.range,
    required this.colors,
    required this.onToggle,
    required this.onChanged,
  });

  final bool enabled;
  final RangeValues range;
  final WeatherThemeColors colors;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ConditionSection(
      label: 'Temperature',
      enabled: enabled,
      colors: colors,
      onToggle: onToggle,
      child: Column(
        children: [
          RangeSlider(
            values: range,
            min: 0,
            max: 50,
            divisions: 50,
            activeColor: colors.primary,
            inactiveColor: colors.divider,
            labels: RangeLabels(
              '${range.start.round()} C',
              '${range.end.round()} C',
            ),
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.md,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${range.start.round()} C',
                  style: OutAboutTypography.labelMedium(
                    colors,
                  ),
                ),
                Text(
                  '${range.end.round()} C',
                  style:
                      OutAboutTypography.labelMedium(colors),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrecipitationSection extends StatelessWidget {
  const _PrecipitationSection({
    required this.enabled,
    required this.level,
    required this.colors,
    required this.onToggle,
    required this.onChanged,
  });

  final bool enabled;
  final String level;
  final WeatherThemeColors colors;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ConditionSection(
      label: 'Precipitation',
      enabled: enabled,
      colors: colors,
      onToggle: onToggle,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'none',
            label: Text('No rain'),
          ),
          ButtonSegment(
            value: 'light',
            label: Text('Light OK'),
          ),
          ButtonSegment(
            value: 'any',
            label: Text('Any'),
          ),
        ],
        selected: {level},
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            colors.text,
          ),
          backgroundColor:
              WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.primary.withValues(alpha: 0.15);
            }
            return colors.surface;
          }),
        ),
      ),
    );
  }
}

class _WindSection extends StatelessWidget {
  const _WindSection({
    required this.enabled,
    required this.maxSpeed,
    required this.colors,
    required this.onToggle,
    required this.onChanged,
  });

  final bool enabled;
  final double maxSpeed;
  final WeatherThemeColors colors;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ConditionSection(
      label: 'Wind',
      enabled: enabled,
      colors: colors,
      onToggle: onToggle,
      child: Column(
        children: [
          Slider(
            value: maxSpeed,
            min: 0,
            max: 80,
            divisions: 80,
            activeColor: colors.primary,
            inactiveColor: colors.divider,
            label: 'Max ${maxSpeed.round()} km/h',
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Max ${maxSpeed.round()} km/h',
                style:
                    OutAboutTypography.labelMedium(colors),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UvSection extends StatelessWidget {
  const _UvSection({
    required this.enabled,
    required this.range,
    required this.colors,
    required this.onToggle,
    required this.onChanged,
  });

  final bool enabled;
  final RangeValues range;
  final WeatherThemeColors colors;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ConditionSection(
      label: 'UV Index',
      enabled: enabled,
      colors: colors,
      onToggle: onToggle,
      child: Column(
        children: [
          RangeSlider(
            values: range,
            min: 0,
            max: 11,
            divisions: 11,
            activeColor: colors.primary,
            inactiveColor: colors.divider,
            labels: RangeLabels(
              '${range.start.round()}',
              '${range.end.round()}',
            ),
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.md,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${range.start.round()}',
                  style:
                      OutAboutTypography.labelMedium(colors),
                ),
                Text(
                  '${range.end.round()}',
                  style:
                      OutAboutTypography.labelMedium(colors),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.canSave,
    required this.isSaving,
    required this.colors,
    required this.onPressed,
  });

  final bool canSave;
  final bool isSaving;
  final WeatherThemeColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: canSave ? onPressed : null,
        child: isSaving
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
    )
        .animate()
        .fadeIn(
          duration: OutAboutAnimations.standardDuration,
        );
  }
}
