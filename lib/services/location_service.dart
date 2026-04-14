import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/behavioral_event.dart';

// ---------------------------------------------------------------------------
// LocationPermissionResult
// ---------------------------------------------------------------------------

enum LocationPermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

// ---------------------------------------------------------------------------
// LocationService
// ---------------------------------------------------------------------------

class LocationService {
  /// Requests location permission and maps the result to [LocationPermissionResult].
  Future<LocationPermissionResult> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  /// Returns the current device position with coordinates bucketed to 2
  /// decimal places (~1 mile radius), per privacy requirements.
  Future<({double lat, double lng})> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return (
      lat: bucket(position.latitude),
      lng: bucket(position.longitude),
    );
  }

  /// Reverse geocodes bucketed coordinates into city/state/metro/country
  /// fields suitable for behavioral event geographic context.
  Future<({String metro, String city, String state, String country})>
      reverseGeocode(double lat, double lng) async {
    final placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) {
      return (metro: '', city: '', state: '', country: 'US');
    }

    final place = placemarks.first;

    final city = place.locality ?? place.subAdministrativeArea ?? '';
    final state = place.administrativeArea ?? '';
    final country = place.isoCountryCode ?? 'US';

    // Use subAdministrativeArea as metro when it differs from city,
    // otherwise fall back to city itself.
    final metro = (place.subAdministrativeArea?.isNotEmpty == true &&
            place.subAdministrativeArea != city)
        ? place.subAdministrativeArea!
        : city;

    return (metro: metro, city: city, state: state, country: country);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  LocationPermissionResult _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionResult.granted;
      case LocationPermission.denied:
        return LocationPermissionResult.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionResult.permanentlyDenied;
      case LocationPermission.unableToDetermine:
        return LocationPermissionResult.denied;
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
