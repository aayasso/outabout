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

  /// Sets up the notification click handler.
  ///
  /// When a notification with an `activity_id` in its data is tapped,
  /// [onActivityTap] is called with that ID.
  void setupClickHandler({
    required void Function(String activityId) onActivityTap,
    required BehavioralEventService eventService,
  }) {
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      final activityId = data?['activity_id'] as String?;
      if (activityId != null) {
        eventService.log('notification_opened', extra: {
          'activity_id': activityId,
        });
        onActivityTap(activityId);
      } else {
        log(
          'Notification tapped without activity_id',
          name: 'OutAbout',
        );
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
