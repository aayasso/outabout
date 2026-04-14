import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

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
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
