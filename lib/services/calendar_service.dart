import 'dart:developer';

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/units.dart';
import '../data/models/daily_forecast.dart';

/// What happened when the app tried to add an event.
///
/// Five cases, not four: `restricted` is a real state the plugin reports on
/// iOS when Screen Time or an MDM profile blocks calendar access, and the user
/// *cannot* grant it. Telling them to open Settings there is bad advice, so it
/// gets its own answer.
enum CalendarAddResult {
  added,

  /// Declined, but the system prompt can still be shown again.
  permissionDenied,

  /// Terminally denied — only Settings can change it.
  permissionPermanentlyDenied,

  /// Blocked by device policy. Settings will not help.
  permissionRestricted,

  failed,
}

/// Builds the note body attached to a calendar event.
///
/// Pure and top-level so it can be tested without EventKit, a device, or a
/// widget tree.
String buildCalendarNotes({
  required DailyForecast day,
  required String temperatureUnit,
}) {
  // One setting drives both dimensions — 'F' means Fahrenheit *and* mph.
  final isFahrenheit = temperatureUnit == 'F';
  final high = isFahrenheit
      ? celsiusToFahrenheit(day.temperatureMax)
      : day.temperatureMax.round();
  final low = isFahrenheit
      ? celsiusToFahrenheit(day.temperatureMin)
      : day.temperatureMin.round();
  final suffix = isFahrenheit ? '°F' : '°C';
  final condition = weatherConditionName(day.weatherCode);

  return 'H $high$suffix / L $low$suffix, $condition '
      '— matched your conditions in OutAbout';
}

/// The calendar day an all-day event should land on.
///
/// [DailyForecast.date] is a parsed Tomorrow.io timestamp for a whole-day
/// aggregate, not a local start time. Converting it to local can move it a day
/// either way depending on what offset the API sent.
///
/// The rule is **the same calendar day the schedule heading names**, and both
/// sides now resolve that the same way: `_isSameDay` in `schedule_tab`
/// normalises to local before comparing, so this does too. Consistency with
/// the day the user tapped under is the thing that matters — but the two must
/// reach it by the same route, and while this compared raw UTC fields a card
/// reading "Today" could produce an event dated yesterday.
DateTime calendarDayFor(DailyForecast forecast) {
  final local = forecast.date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Creates one-shot calendar events. Never reads, updates or deletes.
///
/// Wraps `device_calendar_plus` the way [LocationService] wraps geolocator:
/// the plugin stays behind this seam so it can be swapped, and so every test
/// asserts against this class rather than against EventKit.
class CalendarService {
  CalendarService({DeviceCalendar? plugin})
    : _plugin = plugin ?? DeviceCalendar.instance;

  final DeviceCalendar _plugin;

  /// Whether [status] is enough to add an event.
  ///
  /// `writeOnly` counts. The package's own README example is
  /// `if (status != CalendarPermissionStatus.granted) return;`, which rejects
  /// the very tier this feature asks for — and on iOS 16 and below a
  /// write-only request resolves to `granted` anyway, so both have to pass.
  @visibleForTesting
  static bool satisfiesWrite(CalendarPermissionStatus status) =>
      status == CalendarPermissionStatus.granted ||
      status == CalendarPermissionStatus.writeOnly;

  /// Maps a non-satisfying status onto the answer the UI gives the user.
  ///
  /// `denied` is the plugin's *terminal* state — its own docs say the system
  /// dialog can no longer be shown. `notDetermined` is the recoverable one.
  @visibleForTesting
  static CalendarAddResult mapRefusal(CalendarPermissionStatus status) =>
      switch (status) {
        CalendarPermissionStatus.denied =>
          CalendarAddResult.permissionPermanentlyDenied,
        CalendarPermissionStatus.restricted =>
          CalendarAddResult.permissionRestricted,
        CalendarPermissionStatus.notDetermined =>
          CalendarAddResult.permissionDenied,
        CalendarPermissionStatus.granted ||
        CalendarPermissionStatus.writeOnly => CalendarAddResult.added,
      };

  /// Adds a single all-day event to the device's default calendar.
  Future<CalendarAddResult> addAllDayEvent({
    required String title,
    required DateTime day,
    required String notes,
  }) async {
    try {
      var status = await _plugin.hasPermissions();
      if (status == CalendarPermissionStatus.notDetermined) {
        // Write-only: this feature only ever creates. Asking for full access
        // would buy the app the ability to read the user's whole calendar,
        // which it has no use for and no business holding.
        status = await _plugin.requestPermissions(
          level: CalendarAccessLevel.writeOnly,
        );
      }
      if (!satisfiesWrite(status)) return mapRefusal(status);

      // An all-day event spans [day, day+1); the plugin strips the time
      // components itself when isAllDay is set.
      await _plugin.createEvent(
        title: title,
        startDate: day,
        endDate: day.add(const Duration(days: 1)),
        isAllDay: true,
        description: notes,
      );
      return CalendarAddResult.added;
    } on DeviceCalendarException catch (e, st) {
      if (e.errorCode == DeviceCalendarError.permissionDenied) {
        return CalendarAddResult.permissionPermanentlyDenied;
      }
      log('Calendar add failed', error: e, stackTrace: st, name: 'Calendar');
      return CalendarAddResult.failed;
    } catch (e, st) {
      log('Calendar add failed', error: e, stackTrace: st, name: 'Calendar');
      return CalendarAddResult.failed;
    }
  }

  /// Sends the user to this app's settings page.
  Future<void> openSettings() => _plugin.openAppSettings();
}

final calendarServiceProvider = Provider<CalendarService>((ref) {
  return CalendarService();
});
