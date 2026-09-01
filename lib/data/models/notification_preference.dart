// One activity's answer to "when should we tell you?".
//
// The row this maps to has existed since the first schema and has never been
// read or written by anything — not the app, not the edge function. It is
// listed in CLAUDE.md as a core table. The scheduler now honours every field
// here (see scheduling.ts), so this model is the last piece: without it the
// server can offer lead time that no user is able to ask for.
//
// Lead time is the booking lever. A nudge that arrives the morning conditions
// are good tells you to go outside; a nudge that arrives on Thursday about
// Saturday is the one you can act on — book the court, reserve the table, tell
// the friend. The partner links in the Find & book sheet are worth
// meaningfully more against the second than the first.

/// Bounds on [NotificationPreference.daysBeforeCount].
///
/// One at the bottom because zero is what `notifyMorningOf` already means, and
/// seven at the top because the forecast window does not reach past it — a
/// larger number would schedule a nudge for a day the matcher never evaluated.
/// Mirrors the clamp in scheduling.ts; the two must agree, or the app offers a
/// setting the server quietly refuses.
const int minDaysBeforeCount = 1;
const int maxDaysBeforeCount = 7;

/// The default morning time, matching `defaultNotifyPrefs` in scheduling.ts.
const String defaultMorningTime = '07:00:00';

class NotificationPreference {
  const NotificationPreference({
    this.id,
    required this.activityId,
    this.notifyMorningOf = true,
    this.notifyNightBefore = false,
    this.notifyDaysBefore = false,
    this.daysBeforeCount = 2,
    this.morningTime = defaultMorningTime,
  });

  final String? id;
  final String activityId;

  /// Defaults true here and in the column default, deliberately.
  ///
  /// The table shipped with every notify_* column defaulting to false, which
  /// meant the act of creating a row switched the activity off. An activity
  /// with no row at all is treated as this same default by
  /// `effectiveNotifyPrefs` server-side, so the two agree: silence is only ever
  /// something the user chose.
  final bool notifyMorningOf;

  final bool notifyNightBefore;
  final bool notifyDaysBefore;

  /// How many days ahead the days-before nudge lands. Clamped on read.
  final int daysBeforeCount;

  /// Local wall-clock time, "HH:MM:SS". The server reads it in the user's own
  /// zone, which is why `user_locations.timezone` had to exist first.
  final String morningTime;

  /// True when nothing will ever be sent for this activity.
  ///
  /// Surfaced so the UI can say so plainly rather than leaving the user to
  /// infer it from three separate switches all being off.
  bool get isSilent =>
      !notifyMorningOf && !notifyNightBefore && !notifyDaysBefore;

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    final rawCount = (json['days_before_count'] as num?)?.toInt() ?? 2;
    final rawTime = json['morning_time'] as String?;
    return NotificationPreference(
      id: json['id'] as String?,
      activityId: json['activity_id'] as String,
      notifyMorningOf: json['notify_morning_of'] as bool? ?? true,
      notifyNightBefore: json['notify_night_before'] as bool? ?? false,
      notifyDaysBefore: json['notify_days_before'] as bool? ?? false,
      // Clamped on the way in, not just on the way out: a row written by an
      // older build, or by hand, must not be able to render a stepper outside
      // its own bounds.
      daysBeforeCount:
          rawCount.clamp(minDaysBeforeCount, maxDaysBeforeCount).toInt(),
      morningTime: (rawTime != null && rawTime.length >= 4)
          ? rawTime
          : defaultMorningTime,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'activity_id': activityId,
        // Every flag is written explicitly, never omitted. An upsert that
        // dropped a false would leave the previous true standing, so turning a
        // nudge off would silently not take.
        'notify_morning_of': notifyMorningOf,
        'notify_night_before': notifyNightBefore,
        'notify_days_before': notifyDaysBefore,
        'days_before_count': daysBeforeCount,
        'morning_time': morningTime,
      };

  NotificationPreference copyWith({
    bool? notifyMorningOf,
    bool? notifyNightBefore,
    bool? notifyDaysBefore,
    int? daysBeforeCount,
    String? morningTime,
  }) =>
      NotificationPreference(
        id: id,
        activityId: activityId,
        notifyMorningOf: notifyMorningOf ?? this.notifyMorningOf,
        notifyNightBefore: notifyNightBefore ?? this.notifyNightBefore,
        notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
        daysBeforeCount: (daysBeforeCount ?? this.daysBeforeCount)
            .clamp(minDaysBeforeCount, maxDaysBeforeCount)
            .toInt(),
        morningTime: morningTime ?? this.morningTime,
      );

  /// "07:00:00" as (7, 0). A malformed stored value reads as the default
  /// morning rather than throwing inside a build().
  ({int hour, int minute}) get morningHourMinute {
    final parts = morningTime.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '');
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '');
    if (hour == null || minute == null) return (hour: 7, minute: 0);
    return (hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  /// Formats [hour]/[minute] as the "HH:MM:SS" Postgres `time` wants.
  static String formatWallTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:00';
}
