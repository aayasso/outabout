// What the home-screen widget is told, and nothing more.
//
// Pure, on the model of `outcome_stats.dart` and `condition_suggestion.dart`:
// no Flutter bindings beyond `Color`, no platform channel, no `DateTime.now()`.
// The clock arrives as a parameter, so "which day is this payload about" is
// testable without a simulator — which matters here more than usual, because
// the widget is the one surface whose bugs are invisible until someone looks
// at their home screen.
//
// ---------------------------------------------------------------------------
// Why the payload is finished data rather than raw data
// ---------------------------------------------------------------------------
//
// The widget cannot compute. It has no API key, no location permission of its
// own, no Supabase session, and no Dart. Anything it would have to work out
// for itself is something that can silently disagree with the app:
//
//   * temperatures arrive already converted, because the unit lives on
//     `profiles.temperature_unit` — server-side, deliberately not in
//     SharedPreferences — so a widget reading the shared store could never
//     know Celsius from Fahrenheit;
//   * the condition is named here, so Swift needs no copy of the Tomorrow.io
//     code table;
//   * the colours are resolved here as hex, so Swift needs no copy of the five
//     palettes. That is the important one: CLAUDE.md's central rule is that
//     nothing hardcodes a palette, and a transcription into a second language
//     would drift the first time a single value changed.
//
// What the widget does decide for itself is staleness, by comparing
// [localDate] against the device's own today. That has to happen at render
// time, because a payload written this morning is still correct at noon and
// wrong at midnight, and nothing writes to the widget in between.

import 'dart:convert';

import 'package:flutter/painting.dart' show Color;

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../core/weather_theme_provider.dart';
import '../../data/models/schedule_day.dart';
import '../outcomes/outcome_stats.dart' show localDateKeyOf;

/// Bumped when the payload's shape changes incompatibly.
///
/// The widget bundle updates with the app, so the two are normally in step —
/// but not during an App Store phased release, where a widget from the old
/// build can read a payload from the new one. The Swift side treats every
/// field as optional and checks this before trusting anything.
const int widgetPayloadSchema = 1;

/// How many activity names the medium widget can show without crowding.
///
/// The count is reported separately and in full, so anything beyond this
/// becomes "+N more" rather than disappearing.
const int widgetMatchNameLimit = 4;

/// `#RRGGBB` for [color], alpha discarded.
///
/// Alpha is dropped rather than encoded: every palette colour is fully opaque,
/// and an eight-digit string would be read by SwiftUI's initialiser as ARGB or
/// RGBA depending on who wrote it. Six digits cannot be misread.
String hexOf(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
}

/// Everything the widget draws, or null if today cannot be described.
///
/// Null is a real answer and the caller must not paper over it: it means the
/// forecast in hand has no entry for the device's today, which happens when a
/// cache written yesterday is served after midnight. Writing that day's
/// weather under today's date would make the widget confidently wrong, and
/// unlike every other surface in the app there is nobody looking at it who
/// could notice. Leaving the previous payload in place lets the widget say
/// "As of yesterday" instead, which is the honest version.
Map<String, dynamic>? buildWidgetPayload({
  required List<ScheduleDay> days,
  required DateTime now,
  required String temperatureUnit,
}) {
  final today = localDateKeyOf(now);

  ScheduleDay? todaysDay;
  for (final day in days) {
    if (localDateKeyOf(day.forecast.date) == today) {
      todaysDay = day;
      break;
    }
  }
  if (todaysDay == null) return null;

  final forecast = todaysDay.forecast;
  final imperial = temperatureUnit == 'F';

  // Named, not filtered on `id`: an activity with no name would render as an
  // empty row, which reads as a rendering bug rather than as missing data.
  final names = [
    for (final activity in todaysDay.matchedActivities)
      if (activity.name.trim().isNotEmpty) activity.name.trim(),
  ];

  final theme = WeatherThemeNotifier.mapWeatherCode(forecast.weatherCode);
  final colors = WeatherThemeColors.forTheme(theme);

  return <String, dynamic>{
    'schema': widgetPayloadSchema,
    'local_date': today,
    'weather_code': forecast.weatherCode,
    'condition': weatherConditionName(forecast.weatherCode),
    'temp_high': _temperature(forecast.temperatureMax, imperial),
    'temp_low': _temperature(forecast.temperatureMin, imperial),
    'unit': imperial ? 'F' : 'C',
    'match_count': names.length,
    'matches': names.take(widgetMatchNameLimit).toList(),
    'theme': theme.name,
    'colors': <String, String>{
      'background': hexOf(colors.background),
      'surface': hexOf(colors.surface),
      'text': hexOf(colors.text),
      'textSecondary': hexOf(colors.textSecondary),
      'primary': hexOf(colors.primaryInteractive),
    },
  };
}

int _temperature(double celsius, bool imperial) =>
    imperial ? celsiusToFahrenheit(celsius) : celsius.round();

/// The payload as the single string that crosses the bridge.
///
/// One string rather than a key per field: `saveWidgetData` is one channel
/// round trip each, and a half-written widget — new temperature, yesterday's
/// activity names — is worse than a stale one.
String encodeWidgetPayload(Map<String, dynamic> payload) => jsonEncode(payload);
