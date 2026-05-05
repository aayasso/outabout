import 'package:flutter/material.dart';

class NotificationPreference {
  final String id;
  final String activityId;
  final bool notifyDaysBefore;
  final int daysBeforeCount;
  final bool notifySundayDigest;
  final bool notifyNightBefore;
  final bool notifyMorningOf;
  final TimeOfDay morningTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NotificationPreference({
    required this.id,
    required this.activityId,
    this.notifyDaysBefore = false,
    this.daysBeforeCount = 2,
    this.notifySundayDigest = false,
    this.notifyNightBefore = false,
    this.notifyMorningOf = false,
    this.morningTime = const TimeOfDay(hour: 7, minute: 0),
    this.createdAt,
    this.updatedAt,
  });

  factory NotificationPreference.fromJson(
    Map<String, dynamic> json,
  ) {
    TimeOfDay morningTime =
        const TimeOfDay(hour: 7, minute: 0);
    final timeStr = json['morning_time'] as String?;
    if (timeStr != null) {
      final parts = timeStr.split(':');
      morningTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return NotificationPreference(
      id: json['id'] as String,
      activityId: json['activity_id'] as String,
      notifyDaysBefore:
          json['notify_days_before'] as bool? ?? false,
      daysBeforeCount:
          json['days_before_count'] as int? ?? 2,
      notifySundayDigest:
          json['notify_sunday_digest'] as bool? ?? false,
      notifyNightBefore:
          json['notify_night_before'] as bool? ?? false,
      notifyMorningOf:
          json['notify_morning_of'] as bool? ?? false,
      morningTime: morningTime,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final hour =
        morningTime.hour.toString().padLeft(2, '0');
    final minute =
        morningTime.minute.toString().padLeft(2, '0');

    return {
      'id': id,
      'activity_id': activityId,
      'notify_days_before': notifyDaysBefore,
      'days_before_count': daysBeforeCount,
      'notify_sunday_digest': notifySundayDigest,
      'notify_night_before': notifyNightBefore,
      'notify_morning_of': notifyMorningOf,
      'morning_time': '$hour:$minute:00',
      if (createdAt != null)
        'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null)
        'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
