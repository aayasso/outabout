// "When should we tell you?" — the three nudge kinds, per activity.
//
// Sits directly under the condition sections on the activity detail screen,
// because it answers the next question: those decide *whether* a day counts,
// this decides *when you hear about it*.
//
// The server has honoured all three since scheduling.ts shipped. Until this
// widget there was no way for a user to ask for any of them, so every activity
// ran on the morning-of default and the lead-time paths were unreachable code.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/notification_preference.dart';
import '../../data/repositories/notification_preference_repository.dart';
import '../../services/behavioral_event_service.dart';
import '../shared/condition_profile_form.dart';

class NotificationTimingForm extends ConsumerStatefulWidget {
  const NotificationTimingForm({super.key, required this.activityId});

  final String activityId;

  @override
  ConsumerState<NotificationTimingForm> createState() =>
      _NotificationTimingFormState();
}

class _NotificationTimingFormState
    extends ConsumerState<NotificationTimingForm> {
  /// The value being edited. Held locally so a switch responds at once rather
  /// than after a round trip — the write is fired and forgotten, the way the
  /// condition toggles above already behave.
  NotificationPreference? _draft;

  Future<void> _apply(
    NotificationPreference next, {
    required String settingChanged,
    required String newValue,
  }) async {
    setState(() => _draft = next);
    OutAboutHaptics.onConditionToggle();

    try {
      await ref.read(notificationPreferenceRepositoryProvider).save(next);
    } catch (e) {
      if (!mounted) return;
      // Rolled back rather than left showing a state the server does not have.
      // A notification setting that silently fails to save is the worst kind
      // of failure here: the user believes they have turned something off.
      setState(() => _draft = null);
      ref.invalidate(notificationPreferenceProvider(widget.activityId));
      final colors = ref.read(weatherThemeColorsProvider);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          backgroundColor: colors.cardBackground,
          content: Text(
            'Could not save when to notify you.',
            style: OutAboutTypography.bodyMedium(colors),
          ),
        ),
      );
      return;
    }

    ref.read(behavioralEventServiceProvider).log(
      'settings_changed',
      extra: {
        'setting': settingChanged,
        'new_value': newValue,
        'activity_id': widget.activityId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final async = ref.watch(notificationPreferenceProvider(widget.activityId));
    final prefs = _draft ?? async.valueOrNull;

    // A skeleton, never a spinner — the standard the rest of the app holds to.
    if (prefs == null) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(OutAboutRadius.cards),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('When to tell you', style: OutAboutTypography.headingSmall(colors)),
        const SizedBox(height: OutAboutSpacing.sm),

        ConditionSection(
          title: 'Morning of',
          icon: Icons.wb_twilight,
          enabled: prefs.notifyMorningOf,
          onToggled: (value) => _apply(
            prefs.copyWith(notifyMorningOf: value),
            settingChanged: 'notify_morning_of',
            newValue: value.toString(),
          ),
          child: _MorningTimeRow(
            preference: prefs,
            colors: colors,
            onChanged: (time) => _apply(
              prefs.copyWith(morningTime: time),
              settingChanged: 'morning_time',
              newValue: time,
            ),
          ),
        ),
        const SizedBox(height: OutAboutSpacing.sm),

        ConditionSection(
          title: 'The night before',
          icon: Icons.nightlight_outlined,
          enabled: prefs.notifyNightBefore,
          onToggled: (value) => _apply(
            prefs.copyWith(notifyNightBefore: value),
            settingChanged: 'notify_night_before',
            newValue: value.toString(),
          ),
          child: Text(
            'Around 6pm the evening before, so you can make a plan.',
            style: OutAboutTypography.bodySmall(colors)
                .copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: OutAboutSpacing.sm),

        ConditionSection(
          title: 'Further ahead',
          icon: Icons.event_available_outlined,
          enabled: prefs.notifyDaysBefore,
          onToggled: (value) => _apply(
            prefs.copyWith(notifyDaysBefore: value),
            settingChanged: 'notify_days_before',
            newValue: value.toString(),
          ),
          child: _DaysBeforeStepper(
            preference: prefs,
            colors: colors,
            onChanged: (count) => _apply(
              prefs.copyWith(daysBeforeCount: count),
              settingChanged: 'days_before_count',
              newValue: count.toString(),
            ),
          ),
        ),

        // Said plainly rather than left to be inferred from three switches
        // that all happen to be off.
        if (prefs.isSilent) ...[
          const SizedBox(height: OutAboutSpacing.sm),
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.notifications_off_outlined,
                    size: 16, color: colors.textSecondary),
              ),
              const SizedBox(width: OutAboutSpacing.xs),
              Expanded(
                child: Text(
                  "You won't be notified about this one.",
                  style: OutAboutTypography.bodySmall(colors)
                      .copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: OutAboutSpacing.sm),
        Text(
          'At most two notifications a day across everything, and never twice '
          'about the same day.',
          style: OutAboutTypography.bodySmall(colors)
              .copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _MorningTimeRow
// ---------------------------------------------------------------------------

class _MorningTimeRow extends StatelessWidget {
  const _MorningTimeRow({
    required this.preference,
    required this.colors,
    required this.onChanged,
  });

  final NotificationPreference preference;
  final WeatherThemeColors colors;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final (:hour, :minute) = preference.morningHourMinute;
    final label = TimeOfDay(hour: hour, minute: minute).format(context);

    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(
              'At',
              style: OutAboutTypography.bodyMedium(colors),
            ),
          ),
          Semantics(
            button: true,
            label: 'Notification time, $label',
            hint: 'Changes the time',
            child: TextButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: hour, minute: minute),
                );
                if (picked == null) return;
                onChanged(NotificationPreference.formatWallTime(
                  picked.hour,
                  picked.minute,
                ));
              },
              child: Text(
                label,
                style: OutAboutTypography.bodyMedium(colors)
                    .copyWith(color: colors.primaryInteractive),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DaysBeforeStepper
// ---------------------------------------------------------------------------

/// A stepper rather than a slider.
///
/// The range is one to seven. A slider over seven discrete values is harder to
/// land precisely than two buttons, and it reads as continuous when it is not.
class _DaysBeforeStepper extends StatelessWidget {
  const _DaysBeforeStepper({
    required this.preference,
    required this.colors,
    required this.onChanged,
  });

  final NotificationPreference preference;
  final WeatherThemeColors colors;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = preference.daysBeforeCount;
    final label = count == 1 ? '1 day ahead' : '$count days ahead';

    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: OutAboutTypography.bodyMedium(colors)),
          ),
          _StepButton(
            icon: Icons.remove,
            semanticLabel: 'Fewer days ahead',
            colors: colors,
            // Disabled rather than hidden at the bounds, so the control does
            // not change shape as the value moves.
            onPressed: count > minDaysBeforeCount
                ? () => onChanged(count - 1)
                : null,
          ),
          const SizedBox(width: OutAboutSpacing.xs),
          _StepButton(
            icon: Icons.add,
            semanticLabel: 'More days ahead',
            colors: colors,
            onPressed: count < maxDaysBeforeCount
                ? () => onChanged(count + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.colors,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final WeatherThemeColors colors;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: SizedBox(
        // 48dp, the tap target the accessibility pass in 7cdcf85 holds every
        // interactive element to.
        width: 48,
        height: 48,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 20,
            color: onPressed == null
                ? colors.textSecondary.withValues(alpha: 0.4)
                : colors.primaryInteractive,
          ),
        ),
      ),
    );
  }
}
