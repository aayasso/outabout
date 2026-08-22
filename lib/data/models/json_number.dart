import 'package:flutter/foundation.dart' show debugPrint;

/// Returns the first numeric value present among [keys], or null.
///
/// A missing key and an explicit null both read as absent, which is what
/// makes this safe against Tomorrow.io responses whose field set varies by
/// endpoint and timestep.
num? firstNum(Map<String, dynamic> values, List<String> keys) {
  for (final key in keys) {
    final value = values[key];
    if (value is num) return value;
  }
  return null;
}

/// Reads a numeric field, logging and falling back when none of [keys] is
/// present. Never casts a nullable lookup directly.
///
/// [label] identifies the caller in the log line, so a shape change in the
/// upstream API surfaces as a named warning rather than a bare TypeError.
num numOr(
  Map<String, dynamic> values,
  List<String> keys,
  num fallback, {
  required String label,
}) {
  final value = firstNum(values, keys);
  if (value != null) return value;
  debugPrint(
    '$label: none of $keys present in values — defaulting to $fallback.',
  );
  return fallback;
}

/// Tomorrow.io reports wind in metres per second when `units=metric`.
///
/// OutAbout stores wind in km/h everywhere — the condition sliders, the
/// matcher and the UI all speak km/h — so the conversion happens once, at
/// parse time, in the model factories.
const double metersPerSecondToKmh = 3.6;
