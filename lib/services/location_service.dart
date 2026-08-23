import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../data/models/behavioral_event.dart';

// ---------------------------------------------------------------------------
// LocationPermissionResult
// ---------------------------------------------------------------------------

enum LocationPermissionResult { granted, denied, permanentlyDenied }

// ---------------------------------------------------------------------------
// LocationService
// ---------------------------------------------------------------------------

class LocationService {
  /// Requests location permission and maps the result to [LocationPermissionResult].
  Future<LocationPermissionResult> requestPermission() async {
    final permission = await Geolocator.requestPermission();
    return mapPermission(permission);
  }

  /// Returns the current device position with coordinates bucketed to 2
  /// decimal places (~1 mile radius), per privacy requirements.
  Future<({double lat, double lng})> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return (lat: bucket(position.latitude), lng: bucket(position.longitude));
  }

  /// Reverse geocodes bucketed coordinates into city/state/metro/country
  /// fields suitable for behavioral event geographic context.
  Future<({String metro, String city, String state, String country})>
  reverseGeocode(double lat, double lng) async {
    final placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return mapPlacemark();

    final place = placemarks.first;
    return mapPlacemark(
      locality: place.locality,
      subAdministrativeArea: place.subAdministrativeArea,
      administrativeArea: place.administrativeArea,
      isoCountryCode: place.isoCountryCode,
    );
  }

  /// The pure part of [reverseGeocode]: placemark fields in, our fields out.
  ///
  /// Split out because [reverseGeocode] itself calls a platform channel, which
  /// is what drove the test suite to `@override` the whole method and assert
  /// against its own copy of this logic instead of against this.
  ///
  /// An unknown country reports as empty rather than 'US' — "not collected"
  /// and "United States" must not be the same value.
  @visibleForTesting
  ({String metro, String city, String state, String country}) mapPlacemark({
    String? locality,
    String? subAdministrativeArea,
    String? administrativeArea,
    String? isoCountryCode,
  }) {
    final city = locality ?? subAdministrativeArea ?? '';
    final state = administrativeArea ?? '';
    final country = isoCountryCode ?? '';

    // subAdministrativeArea is the metro when it differs from the city;
    // otherwise the city stands in for it.
    final metro =
        (subAdministrativeArea?.isNotEmpty == true &&
            subAdministrativeArea != city)
        ? subAdministrativeArea!
        : city;

    return (metro: metro, city: city, state: state, country: country);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Maps a plugin permission to ours.
  ///
  /// Public and annotated rather than private: while it was `_mapPermission`
  /// the suite could not reach it, so the tests declared a subclass that
  /// re-implemented this switch and asserted on that. Five tests passed
  /// regardless of what this method did.
  @visibleForTesting
  LocationPermissionResult mapPermission(LocationPermission permission) {
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
