import 'package:flutter/foundation.dart';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'behavioral_event_service.dart';

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

class NotificationService {
  /// Requests notification permission from the OS.
  ///
  /// Returns `true` if the permission is granted, `false` otherwise.
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Returns `true` if notification permission is currently granted.
  Future<bool> isGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Initializes OneSignal with the given [appId].
  Future<void> initializeOneSignal(String appId) async {
    OneSignal.initialize(appId);
  }

  /// Sets the `user_id` tag on the OneSignal user for targeting.
  Future<void> setUserTag(String userId) async {
    OneSignal.User.addTagWithKey('user_id', userId);
  }

  /// Clears the `user_id` tag from the OneSignal user.
  Future<void> clearUserTag() async {
    OneSignal.User.removeTag('user_id');
  }

  /// Reads `activity_id` out of a notification payload.
  ///
  /// `additionalData` is `Map<String, dynamic>` straight off the wire, so the
  /// shape is the server's promise, not the type system's. A hard
  /// `as String?` cast threw inside the OneSignal callback the moment the id
  /// arrived as a JSON number — the tap did nothing, no event was logged, and
  /// the failure surfaced only as an unhandled zone error.
  ///
  /// Returns null when there is nothing usable, so the caller can say so.
  @visibleForTesting
  static String? parseActivityId(Map<String, dynamic>? data) {
    final raw = data?['activity_id'];
    if (raw == null) return null;
    if (raw is String) return raw.trim().isEmpty ? null : raw.trim();
    // Numbers and anything else with a sensible toString: the id is a uuid
    // in practice, but a numeric id must open the screen rather than crash.
    if (raw is num || raw is bool) return raw.toString();
    return null;
  }

  /// Sets up the notification click handler.
  ///
  /// When a notification with an `activity_id` in its data is tapped,
  /// [onActivityTap] is called with that ID.
  void setupClickHandler({
    required void Function(String activityId) onActivityTap,
    required BehavioralEventService eventService,
  }) {
    OneSignal.Notifications.addClickListener((event) {
      final activityId = parseActivityId(event.notification.additionalData);
      if (activityId != null) {
        eventService.log(
          'notification_opened',
          extra: {'activity_id': activityId},
        );
        onActivityTap(activityId);
      } else {
        log('Notification tapped without activity_id', name: 'OutAbout');
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
