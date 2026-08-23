import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/activity.dart';
import '../../data/models/condition_profile.dart';
import '../../features/home/home_providers.dart';
import '../../services/behavioral_event_service.dart';
import '../../widgets/category_chip_picker.dart';

const int maxNameLength = 50;
const int maxNotesLength = 200;

int _celsiusToFahrenheit(double c) => (c * 9 / 5 + 32).round();
int _kmhToMph(double kmh) => (kmh * 0.621371).round();

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

  final Set<String> _selectedCategoryIds = {};
  bool _isSaving = false;
  String? _errorMessage;

  // Condition toggles
  bool _tempEnabled = false;
  bool _precipEnabled = false;
  bool _windEnabled = false;
  // Condition values
  RangeValues _tempRange = const RangeValues(15, 30);
  String _precipLevel = PrecipLevel.avoidRain;
  double _windMax = 25;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
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
        categoryIds: _selectedCategoryIds.toList(),
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

      if (mounted) context.popOrGo();
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
    final profileAsync = ref.watch(profileProvider);
    final temperatureUnit =
        profileAsync.valueOrNull?.temperatureUnit ?? 'F';

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
                _isSaving ? null : () => context.popOrGo(),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _NotesField(
                    controller: _notesController,
                    colors: colors,
                    onChanged: (_) => setState(() {}),
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
                        color: _notesController.text.length >
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
                          'activity_id': null,
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
              const SizedBox(height: OutAboutSpacing.sm),
              _TemperatureSection(
                enabled: _tempEnabled,
                range: _tempRange,
                colors: colors,
                temperatureUnit: temperatureUnit,
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
                temperatureUnit: temperatureUnit,
                onToggle: (v) {
                  OutAboutHaptics.onConditionToggle();
                  setState(() => _windEnabled = v);
                },
                onChanged: (v) =>
                    setState(() => _windMax = v),
              ),
              const SizedBox(height: OutAboutSpacing.lg),
              _SaveButton(
                canSave: _canSave,
                isSaving: _isSaving,
                colors: colors,
                onPressed: _save,
                disabledReason: _disabledReason,
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
        labelText: 'Activity name *',
        labelStyle:
            OutAboutTypography.labelMedium(colors),
        hintStyle: OutAboutTypography.bodyLarge(colors)
            .copyWith(color: colors.textSecondary),
        errorText:
            controller.text.trim().length > maxNameLength
                ? 'Name must be $maxNameLength characters'
                    ' or less'
                : null,
        errorStyle:
            OutAboutTypography.bodySmall(colors).copyWith(
          color: OutAboutColors.errorColor,
        ),
      ),
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({
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
    required this.temperatureUnit,
    required this.onToggle,
    required this.onChanged,
  });

  final bool enabled;
  final RangeValues range;
  final WeatherThemeColors colors;
  final String temperatureUnit;
  final ValueChanged<bool> onToggle;
  final ValueChanged<RangeValues> onChanged;

  String _formatTemp(double celsius) {
    if (temperatureUnit == 'F') {
      return '${_celsiusToFahrenheit(celsius)}°F';
    }
    return '${celsius.round()}°C';
  }

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
              _formatTemp(range.start),
              _formatTemp(range.end),
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
                  _formatTemp(range.start),
                  style: OutAboutTypography.labelMedium(
                    colors,
                  ),
                ),
                Text(
                  _formatTemp(range.end),
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
            value: PrecipLevel.avoidRain,
            label: Text('Avoid rain'),
          ),
          ButtonSegment(
            value: PrecipLevel.rainOnly,
            label: Text('Only when raining'),
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
    required this.temperatureUnit,
    required this.onToggle,
    required this.onChanged,
  });

  final bool enabled;
  final double maxSpeed;
  final WeatherThemeColors colors;
  final String temperatureUnit;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onChanged;

  String _formatWind(double kmh) {
    if (temperatureUnit == 'F') {
      return 'Max ${_kmhToMph(kmh)} mph';
    }
    return 'Max ${kmh.round()} km/h';
  }

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
            label: _formatWind(maxSpeed),
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OutAboutSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatWind(maxSpeed),
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

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.canSave,
    required this.isSaving,
    required this.colors,
    required this.onPressed,
    this.disabledReason,
  });

  final bool canSave;
  final bool isSaving;
  final WeatherThemeColors colors;
  final VoidCallback onPressed;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
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
        ),
        if (disabledReason case final reason?)
          Padding(
            padding: const EdgeInsets.only(
              top: OutAboutSpacing.sm,
            ),
            child: Text(
              reason,
              style: OutAboutTypography.bodySmall(colors)
                  .copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    )
        .animate()
        .fadeIn(
          duration: OutAboutAnimations.standardDuration,
        );
  }
}
