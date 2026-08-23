import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/weather_theme_provider.dart';
import '../data/models/daily_forecast.dart';
import '../features/home/home_providers.dart';
import '../services/behavioral_event_service.dart';
import '../services/calendar_service.dart';

/// Adds [activityName]'s matched day to the device calendar, once.
///
/// Shared by the schedule card and the activity detail screen so the two can
/// never drift on wording, event shape, or how a refusal is handled.
///
/// One-shot by design: nothing is stored about the created event, so there is
/// nothing to sync, update or delete later — and the app never needs read
/// access to a calendar.
Future<void> addActivityToCalendar(
  BuildContext context,
  WidgetRef ref, {
  required String activityName,
  String? activityId,
  required DailyForecast forecast,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final colors = ref.read(weatherThemeColorsProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final temperatureUnit =
      ref.read(profileProvider).valueOrNull?.temperatureUnit ?? 'F';

  final day = calendarDayFor(forecast);
  final result = await ref
      .read(calendarServiceProvider)
      .addAllDayEvent(
        title: activityName,
        day: day,
        notes: buildCalendarNotes(
          day: forecast,
          temperatureUnit: temperatureUnit,
        ),
      );

  void snack(String message) {
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: colors.cardBackground,
        content: Text(message, style: OutAboutTypography.bodyMedium(colors)),
      ),
    );
  }

  switch (result) {
    case CalendarAddResult.added:
      OutAboutHaptics.onActivitySave();
      final extra = <String, dynamic>{'matched_day': _isoDate(day)};
      if (activityId != null) extra['activity_id'] = activityId;
      ref
          .read(behavioralEventServiceProvider)
          .log(
            'calendar_event_added',
            extra: extra,
            conditions: ref.read(conditionsSnapshotProvider)(
              forecastDay: forecast,
            ),
          );
      snack('Added to your calendar on ${_friendlyDate(day)}.');

    case CalendarAddResult.permissionDenied:
      // Declined the system prompt, which can still be shown again. Say
      // nothing further — the refusal was just made and repeating it back is
      // the nagging this path exists to avoid.
      break;

    case CalendarAddResult.permissionPermanentlyDenied:
      // Explained exactly once, ever. After that a one-line note, because the
      // user has already been told where the switch is.
      final explained = prefs.getBool(calendarPermissionExplainedKey) ?? false;
      if (explained) {
        snack('Calendar access is off for OutAbout.');
        return;
      }
      await prefs.setBool(calendarPermissionExplainedKey, true);
      if (!context.mounted) return;
      await _showExplainer(context, ref, colors);

    case CalendarAddResult.permissionRestricted:
      // Screen Time or an MDM profile. Settings will not help, so this must
      // not send them there.
      snack('Calendar access is blocked on this device.');

    case CalendarAddResult.failed:
      snack('Could not add to your calendar.');
  }
}

Future<void> _showExplainer(
  BuildContext context,
  WidgetRef ref,
  WeatherThemeColors colors,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: colors.cardBackground,
      scrollable: true,
      title: Text(
        'Calendar access is off',
        style: OutAboutTypography.headingMedium(colors),
      ),
      content: Text(
        'OutAbout can add an activity to your calendar when you ask it to. '
        'It only ever adds — it never reads your calendar.\n\n'
        'You can turn this on in Settings.',
        style: OutAboutTypography.bodyMedium(colors),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: Text(
            'Not now',
            style: OutAboutTypography.labelLarge(
              colors,
            ).copyWith(color: colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            ref.read(calendarServiceProvider).openSettings();
          },
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: Text(
            'Open Settings',
            style: OutAboutTypography.labelLarge(
              colors,
            ).copyWith(color: colors.primaryInteractive),
          ),
        ),
      ],
    ),
  );
}

String _isoDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

String _friendlyDate(DateTime day) {
  const months = [
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
  ];
  return '${months[day.month - 1]} ${day.day}';
}
