import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/activity.dart';
import '../../data/models/condition_profile.dart';
import '../../features/home/home_providers.dart';
import '../../features/shared/condition_profile_form.dart';
import '../../services/behavioral_event_service.dart';
import '../../widgets/category_chip_picker.dart';

const int maxNameLength = 50;
const int maxNotesLength = 200;

class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key});

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
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
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        // The session can end while this form is open. A bang here reads as a
        // generic save failure and tells the user to retry, which can never
        // succeed.
        setState(() {
          _isSaving = false;
          _errorMessage = 'Your session ended. Sign in again to save.';
        });
        return;
      }

      final activity = Activity(
        userId: userId,
        name: name,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        categoryIds: _selectedCategoryIds.toList(),
      );

      // No conditions means no row, the same as the edit screen. Writing a
      // profile with all three flags false left the two screens disagreeing
      // about what "no conditions" is stored as.
      final hasConditions = _tempEnabled || _precipEnabled || _windEnabled;
      final profile = hasConditions
          ? ConditionProfile(
              id: '',
              activityId: '',
              tempEnabled: _tempEnabled,
              tempMin: _tempEnabled ? _tempRange.start : null,
              tempMax: _tempEnabled ? _tempRange.end : null,
              precipEnabled: _precipEnabled,
              precipLevel: _precipEnabled ? _precipLevel : null,
              windEnabled: _windEnabled,
              windMax: _windEnabled ? _windMax : null,
            )
          : null;

      final repo = ref.read(activityRepositoryProvider);
      if (profile != null) {
        await repo.insertWithConditions(activity: activity, profile: profile);
      } else {
        await repo.insert(activity);
      }

      ref
          .read(behavioralEventServiceProvider)
          .log('wishlist_added', extra: {'activity_name': name});

      OutAboutHaptics.onActivitySave();
      ref.invalidate(activitiesProvider);

      if (mounted) context.popOrGo();
    } catch (e, st) {
      log('Failed to save activity', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not save activity. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final profileAsync = ref.watch(profileProvider);
    final temperatureUnit = profileAsync.valueOrNull?.temperatureUnit ?? 'F';

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
            onPressed: _isSaving ? null : () => context.popOrGo(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                _ErrorBanner(message: _errorMessage!, colors: colors),
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
                        extra: {'category_id': id, 'activity_id': null},
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
              const SizedBox(height: OutAboutSpacing.sm),
              ConditionSection(
                title: 'Temperature',
                icon: Icons.thermostat,
                enabled: _tempEnabled,
                onToggled: (v) => setState(() => _tempEnabled = v),
                child: TemperatureSection(
                  colors: colors,
                  min: _tempRange.start,
                  max: _tempRange.end,
                  temperatureUnit: temperatureUnit,
                  onChanged: (v) => setState(() => _tempRange = v),
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
  const _ErrorBanner({required this.message, required this.colors});

  final String message;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: OutAboutSpacing.md),
      padding: const EdgeInsets.all(OutAboutSpacing.sm),
      decoration: BoxDecoration(
        color: OutAboutColors.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(OutAboutRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: OutAboutColors.errorColor, size: 20),
          const SizedBox(width: OutAboutSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: OutAboutTypography.bodyMedium(
                colors,
              ).copyWith(color: OutAboutColors.errorColor),
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
        labelStyle: OutAboutTypography.labelMedium(colors),
        hintStyle: OutAboutTypography.bodyLarge(
          colors,
        ).copyWith(color: colors.textSecondary),
        errorText: controller.text.trim().length > maxNameLength
            ? 'Name must be $maxNameLength characters'
                  ' or less'
            : null,
        errorStyle: OutAboutTypography.bodySmall(
          colors,
        ).copyWith(color: OutAboutColors.errorColor),
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
        hintStyle: OutAboutTypography.bodyMedium(
          colors,
        ).copyWith(color: colors.textSecondary),
      ),
      textCapitalization: TextCapitalization.sentences,
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
                padding: const EdgeInsets.only(top: OutAboutSpacing.sm),
                child: Text(
                  reason,
                  style: OutAboutTypography.bodySmall(
                    colors,
                  ).copyWith(color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        )
        .animateSafely(context)
        .fadeIn(duration: OutAboutAnimations.standardDuration);
  }
}
