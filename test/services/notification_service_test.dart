import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    List<Permission> permissions,
  ) async {
    return {for (final p in permissions) p: statusToReturn};
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async => false;

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
  // The notification payload is the app's only untyped input from a server.
  // These used to be `isA<Function>` assertions on tear-offs, which cannot
  // fail; the parsing they were standing in for was never exercised at all.
  group('NotificationService.parseActivityId', () {
    test('reads a plain string id', () {
      expect(
        NotificationService.parseActivityId({'activity_id': 'abc-123'}),
        'abc-123',
      );
    });

    test('accepts a numeric id instead of throwing', () {
      // The regression: `data['activity_id'] as String?` threw a TypeError
      // inside the OneSignal click listener, so the tap did nothing at all.
      expect(NotificationService.parseActivityId({'activity_id': 42}), '42');
    });

    test('null payload yields null', () {
      expect(NotificationService.parseActivityId(null), isNull);
    });

    test('missing key yields null', () {
      expect(NotificationService.parseActivityId({'other': 'x'}), isNull);
    });

    test('explicit null id yields null', () {
      expect(
        NotificationService.parseActivityId({'activity_id': null}),
        isNull,
      );
    });

    test('empty and whitespace-only ids yield null, not a bad route', () {
      // '' would otherwise navigate to /activity/ and render "not found".
      expect(NotificationService.parseActivityId({'activity_id': ''}), isNull);
      expect(
        NotificationService.parseActivityId({'activity_id': '   '}),
        isNull,
      );
    });

    test('surrounding whitespace is trimmed', () {
      expect(
        NotificationService.parseActivityId({'activity_id': ' abc '}),
        'abc',
      );
    });

    test('a structured value yields null rather than "{...}"', () {
      expect(
        NotificationService.parseActivityId({
          'activity_id': {'nested': true},
        }),
        isNull,
      );
      expect(
        NotificationService.parseActivityId({
          'activity_id': ['a'],
        }),
        isNull,
      );
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
          statusToReturn: PermissionStatus.permanentlyDenied,
        ),
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
    test('resolves to a NotificationService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // `isNotNull` on a const provider could not fail. Reading it can.
      expect(
        container.read(notificationServiceProvider),
        isA<NotificationService>(),
      );
    });
  });
}
