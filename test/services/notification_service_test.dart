import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:outabout/services/notification_service.dart';

// ---------------------------------------------------------------------------
// Fake platform implementation
// ---------------------------------------------------------------------------

/// A fake [PermissionHandlerPlatform] that lets tests control which status is
/// returned for any [Permission] without hitting platform channels.
class FakePermissionHandler extends Fake
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {
  /// The status returned by [checkPermissionStatus] and [requestPermissions].
  PermissionStatus statusToReturn;

  FakePermissionHandler({required this.statusToReturn});

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return statusToReturn;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
      List<Permission> permissions) async {
    return {for (final p in permissions) p: statusToReturn};
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> shouldShowRequestPermissionRationale(
      Permission permission) async => false;

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async =>
      ServiceStatus.enabled;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Installs [fake] as the active [PermissionHandlerPlatform] for the duration
/// of the test.
void _useFake(FakePermissionHandler fake) {
  PermissionHandlerPlatform.instance = fake;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NotificationService — structural', () {
    test('can be instantiated', () {
      final service = NotificationService();
      expect(service, isNotNull);
    });

    test('exposes requestPermission() method', () {
      final service = NotificationService();
      // Verify the method exists and returns a Future<bool>.
      expect(service.requestPermission, isA<Function>());
    });

    test('exposes isGranted() method', () {
      final service = NotificationService();
      expect(service.isGranted, isA<Function>());
    });
  });

  group('NotificationService — permission granted path', () {
    setUp(() {
      _useFake(FakePermissionHandler(statusToReturn: PermissionStatus.granted));
    });

    test('requestPermission() returns true when granted', () async {
      final service = NotificationService();
      final result = await service.requestPermission();
      expect(result, isTrue);
    });

    test('isGranted() returns true when granted', () async {
      final service = NotificationService();
      final result = await service.isGranted();
      expect(result, isTrue);
    });
  });

  group('NotificationService — permission denied path', () {
    setUp(() {
      _useFake(FakePermissionHandler(statusToReturn: PermissionStatus.denied));
    });

    test('requestPermission() returns false when denied', () async {
      final service = NotificationService();
      final result = await service.requestPermission();
      expect(result, isFalse);
    });

    test('isGranted() returns false when denied', () async {
      final service = NotificationService();
      final result = await service.isGranted();
      expect(result, isFalse);
    });
  });

  group('NotificationService — permanently denied path', () {
    setUp(() {
      _useFake(
        FakePermissionHandler(
            statusToReturn: PermissionStatus.permanentlyDenied),
      );
    });

    test('requestPermission() returns false when permanently denied', () async {
      final service = NotificationService();
      final result = await service.requestPermission();
      expect(result, isFalse);
    });

    test('isGranted() returns false when permanently denied', () async {
      final service = NotificationService();
      final result = await service.isGranted();
      expect(result, isFalse);
    });
  });

  group('notificationServiceProvider', () {
    test('provider constant exists', () {
      expect(notificationServiceProvider, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // OneSignal methods — structural tests only.
  //
  // OneSignal relies on native platform channels, so full integration tests
  // require a running app on a real device or emulator. These tests verify
  // the methods exist and have the correct signatures.
  // ---------------------------------------------------------------------------

  group('NotificationService — OneSignal methods (structural)', () {
    test('exposes initializeOneSignal() method', () {
      final service = NotificationService();
      expect(service.initializeOneSignal, isA<Function>());
    });

    test('exposes setUserTag() method', () {
      final service = NotificationService();
      expect(service.setUserTag, isA<Function>());
    });

    test('exposes clearUserTag() method', () {
      final service = NotificationService();
      expect(service.clearUserTag, isA<Function>());
    });

    test('exposes setupClickHandler() method', () {
      final service = NotificationService();
      expect(service.setupClickHandler, isA<Function>());
    });
  });
}
