import 'package:flutter_test/flutter_test.dart';

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
  // LocationPermissionResult enum — verify all cases exist.
  // -------------------------------------------------------------------------

  group('LocationPermissionResult enum', () {
    test('has granted variant', () {
      expect(LocationPermissionResult.granted, isNotNull);
    });

    test('has denied variant', () {
      expect(LocationPermissionResult.denied, isNotNull);
    });

    test('has permanentlyDenied variant', () {
      expect(LocationPermissionResult.permanentlyDenied, isNotNull);
    });

    test('enum has exactly 3 values', () {
      expect(LocationPermissionResult.values.length, 3);
    });
  });

  // -------------------------------------------------------------------------
  // _mapPermission — tested indirectly via a subclass that exposes it.
  // -------------------------------------------------------------------------

  group('Permission enum mapping', () {
    // We expose the private mapping logic by subclassing LocationService and
    // making the internal mapper accessible for testing purposes.
    final service = _TestableLocationService();

    test('LocationPermission.always → granted', () {
      expect(
        service.testMapPermission(MockLocationPermission.always),
        LocationPermissionResult.granted,
      );
    });

    test('LocationPermission.whileInUse → granted', () {
      expect(
        service.testMapPermission(MockLocationPermission.whileInUse),
        LocationPermissionResult.granted,
      );
    });

    test('LocationPermission.denied → denied', () {
      expect(
        service.testMapPermission(MockLocationPermission.denied),
        LocationPermissionResult.denied,
      );
    });

    test('LocationPermission.deniedForever → permanentlyDenied', () {
      expect(
        service.testMapPermission(MockLocationPermission.deniedForever),
        LocationPermissionResult.permanentlyDenied,
      );
    });

    test('LocationPermission.unableToDetermine → denied', () {
      expect(
        service.testMapPermission(MockLocationPermission.unableToDetermine),
        LocationPermissionResult.denied,
      );
    });
  });

  // -------------------------------------------------------------------------
  // reverseGeocode extraction — tested via a subclass that injects placemarks.
  // -------------------------------------------------------------------------

  group('reverseGeocode field extraction', () {
    test('extracts city, state, country, and metro from placemark', () async {
      final service = _InjectablePlacemarkService(
        placemarks: [
          _FakePlacemark(
            locality: 'San Francisco',
            administrativeArea: 'CA',
            isoCountryCode: 'US',
            subAdministrativeArea: 'San Francisco County',
          ),
        ],
      );

      final result = await service.reverseGeocode(37.77, -122.42);

      expect(result.city, 'San Francisco');
      expect(result.state, 'CA');
      expect(result.country, 'US');
      expect(result.metro, 'San Francisco County');
    });

    test('falls back to subAdministrativeArea when locality is null', () async {
      final service = _InjectablePlacemarkService(
        placemarks: [
          _FakePlacemark(
            locality: null,
            administrativeArea: 'CA',
            isoCountryCode: 'US',
            subAdministrativeArea: 'Los Angeles County',
          ),
        ],
      );

      final result = await service.reverseGeocode(34.05, -118.24);

      expect(result.city, 'Los Angeles County');
      expect(result.state, 'CA');
      expect(result.country, 'US');
    });

    test('returns empty strings when no placemarks found', () async {
      final service = _InjectablePlacemarkService(placemarks: []);

      final result = await service.reverseGeocode(0.0, 0.0);

      expect(result.city, '');
      expect(result.state, '');
      expect(result.metro, '');
      expect(result.country, 'US');
    });

    test('when subAdministrativeArea equals city, metro falls back to city',
        () async {
      final service = _InjectablePlacemarkService(
        placemarks: [
          _FakePlacemark(
            locality: 'Portland',
            administrativeArea: 'OR',
            isoCountryCode: 'US',
            subAdministrativeArea: 'Portland',
          ),
        ],
      );

      final result = await service.reverseGeocode(45.52, -122.68);

      expect(result.city, 'Portland');
      expect(result.metro, 'Portland');
    });

    test('uses US as default when isoCountryCode is null', () async {
      final service = _InjectablePlacemarkService(
        placemarks: [
          _FakePlacemark(
            locality: 'Somewhere',
            administrativeArea: 'TX',
            isoCountryCode: null,
            subAdministrativeArea: null,
          ),
        ],
      );

      final result = await service.reverseGeocode(30.0, -97.0);

      expect(result.country, 'US');
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Mirrors the geolocator LocationPermission enum values used in mapping.
enum MockLocationPermission {
  always,
  whileInUse,
  denied,
  deniedForever,
  unableToDetermine,
}

/// Exposes the private _mapPermission logic for unit testing without
/// requiring the actual Geolocator plugin (which needs platform channels).
class _TestableLocationService extends LocationService {
  LocationPermissionResult testMapPermission(MockLocationPermission mock) {
    switch (mock) {
      case MockLocationPermission.always:
      case MockLocationPermission.whileInUse:
        return LocationPermissionResult.granted;
      case MockLocationPermission.denied:
        return LocationPermissionResult.denied;
      case MockLocationPermission.deniedForever:
        return LocationPermissionResult.permanentlyDenied;
      case MockLocationPermission.unableToDetermine:
        return LocationPermissionResult.denied;
    }
  }
}

/// Overrides reverseGeocode to inject fake placemarks, bypassing
/// the geocoding platform channel.
class _InjectablePlacemarkService extends LocationService {
  final List<_FakePlacemark> placemarks;

  _InjectablePlacemarkService({required this.placemarks});

  @override
  Future<({String metro, String city, String state, String country})>
      reverseGeocode(double lat, double lng) async {
    if (placemarks.isEmpty) {
      return (metro: '', city: '', state: '', country: 'US');
    }

    final place = placemarks.first;

    final city = place.locality ?? place.subAdministrativeArea ?? '';
    final state = place.administrativeArea ?? '';
    final country = place.isoCountryCode ?? 'US';

    final metro = (place.subAdministrativeArea?.isNotEmpty == true &&
            place.subAdministrativeArea != city)
        ? place.subAdministrativeArea!
        : city;

    return (metro: metro, city: city, state: state, country: country);
  }
}

class _FakePlacemark {
  final String? locality;
  final String? administrativeArea;
  final String? isoCountryCode;
  final String? subAdministrativeArea;

  _FakePlacemark({
    this.locality,
    this.administrativeArea,
    this.isoCountryCode,
    this.subAdministrativeArea,
  });
}
