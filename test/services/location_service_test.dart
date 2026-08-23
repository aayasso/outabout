import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:outabout/data/models/behavioral_event.dart';
import 'package:outabout/services/location_service.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Coordinate bucketing — pure function, no mocking required.
  // -------------------------------------------------------------------------

  group('bucket() coordinate bucketing', () {
    test('37.7749 buckets to 37.77', () {
      expect(bucket(37.7749), 37.77);
    });

    test('-122.4194 buckets to -122.42', () {
      expect(bucket(-122.4194), -122.42);
    });

    test('0.0 buckets to 0.0', () {
      expect(bucket(0.0), 0.0);
    });

    test('negative coordinate near zero', () {
      expect(bucket(-0.005), -0.01);
    });

    test('positive value with more than 2 decimal places is truncated', () {
      expect(bucket(51.5074), 51.51);
    });

    test('already-bucketed value is unchanged', () {
      expect(bucket(40.71), 40.71);
    });
  });

  // -------------------------------------------------------------------------
  // Permission mapping — the real LocationService.mapPermission.
  //
  // This group used to assert against `_TestableLocationService`, a subclass
  // declared in this file that re-implemented the switch. Every one of these
  // tests passed no matter what lib/ did.
  // -------------------------------------------------------------------------

  group('LocationService.mapPermission', () {
    final service = LocationService();

    test('always maps to granted', () {
      expect(
        service.mapPermission(LocationPermission.always),
        LocationPermissionResult.granted,
      );
    });

    test('whileInUse maps to granted', () {
      expect(
        service.mapPermission(LocationPermission.whileInUse),
        LocationPermissionResult.granted,
      );
    });

    test('denied maps to denied', () {
      expect(
        service.mapPermission(LocationPermission.denied),
        LocationPermissionResult.denied,
      );
    });

    test('deniedForever maps to permanentlyDenied, not denied', () {
      // The distinction drives whether the app offers a retry or sends the
      // user to Settings, so collapsing the two is a real behaviour change.
      expect(
        service.mapPermission(LocationPermission.deniedForever),
        LocationPermissionResult.permanentlyDenied,
      );
    });

    test('unableToDetermine maps to denied', () {
      expect(
        service.mapPermission(LocationPermission.unableToDetermine),
        LocationPermissionResult.denied,
      );
    });

    test('every plugin permission is mapped', () {
      // Guards the switch against a new enum value being added upstream and
      // silently falling through.
      for (final permission in LocationPermission.values) {
        expect(
          () => service.mapPermission(permission),
          returnsNormally,
          reason: '$permission',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // Placemark mapping — the real LocationService.mapPlacemark.
  //
  // Previously asserted against an @override in this file that replaced the
  // production method wholesale.
  // -------------------------------------------------------------------------

  group('LocationService.mapPlacemark', () {
    final service = LocationService();

    test('no placemark fields yields empty values', () {
      final result = service.mapPlacemark();

      expect(result.city, '');
      expect(result.state, '');
      expect(result.metro, '');
      // Empty, not 'US' — an unknown country must not read as the States.
      expect(result.country, '');
    });

    test('locality wins over subAdministrativeArea for city', () {
      final result = service.mapPlacemark(
        locality: 'San Francisco',
        subAdministrativeArea: 'San Francisco County',
        administrativeArea: 'CA',
        isoCountryCode: 'US',
      );

      expect(result.city, 'San Francisco');
      expect(result.state, 'CA');
      expect(result.country, 'US');
    });

    test('subAdministrativeArea becomes metro when it differs from city', () {
      final result = service.mapPlacemark(
        locality: 'Oakland',
        subAdministrativeArea: 'Alameda County',
      );

      expect(result.metro, 'Alameda County');
      expect(result.city, 'Oakland');
    });

    test('metro falls back to city when the two are the same', () {
      final result = service.mapPlacemark(
        locality: 'Berlin',
        subAdministrativeArea: 'Berlin',
      );

      expect(result.metro, 'Berlin');
    });

    test('city falls back to subAdministrativeArea when locality is null', () {
      final result = service.mapPlacemark(
        subAdministrativeArea: 'Marin County',
      );

      expect(result.city, 'Marin County');
      // city and subAdministrativeArea now match, so metro collapses to it.
      expect(result.metro, 'Marin County');
    });

    test('a non-US placemark keeps its own country code', () {
      final result = service.mapPlacemark(
        locality: 'Sydney',
        administrativeArea: 'NSW',
        isoCountryCode: 'AU',
      );

      expect(result.country, 'AU');
      expect(result.state, 'NSW');
    });
  });
}
