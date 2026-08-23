import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/services/calendar_service.dart';

DailyForecast _day({
  DateTime? date,
  double max = 22.2,
  double min = 12.8,
  int code = 1000,
}) => DailyForecast(
  date: date ?? DateTime(2026, 8, 24),
  temperatureMax: max,
  temperatureMin: min,
  precipitationProbability: 10,
  windSpeedMax: 12,
  weatherCode: code,
);

void main() {
  group('buildCalendarNotes', () {
    test('Fahrenheit reads the way the schedule header does', () {
      // 22.2C -> 72F, 12.8C -> 55F.
      expect(
        buildCalendarNotes(day: _day(), temperatureUnit: 'F'),
        'H 72°F / L 55°F, Clear — matched your conditions in OutAbout',
      );
    });

    test('Celsius keeps the stored values', () {
      expect(
        buildCalendarNotes(day: _day(), temperatureUnit: 'C'),
        'H 22°C / L 13°C, Clear — matched your conditions in OutAbout',
      );
    });

    test('an unknown unit is treated as Celsius, not as Fahrenheit', () {
      // Only the exact string 'F' means Fahrenheit — the same rule the rest
      // of the app uses after the wind-chip mismatch was fixed.
      final notes = buildCalendarNotes(day: _day(), temperatureUnit: 'K');
      expect(notes, contains('°C'));
    });

    test('names the condition, not the code', () {
      expect(
        buildCalendarNotes(day: _day(code: 4201), temperatureUnit: 'F'),
        contains('Heavy Rain'),
      );
      expect(
        buildCalendarNotes(day: _day(code: 8000), temperatureUnit: 'F'),
        contains('Thunderstorm'),
      );
      expect(
        buildCalendarNotes(day: _day(code: 5101), temperatureUnit: 'F'),
        contains('Heavy Snow'),
      );
    });

    test('an unrecognised code falls back the same way the icon does', () {
      expect(
        buildCalendarNotes(day: _day(code: 99999), temperatureUnit: 'F'),
        contains('Clear'),
      );
    });

    test('rounds rather than truncates', () {
      // 21.6C is 70.88F, which must read 71 and not 70.
      final notes = buildCalendarNotes(
        day: _day(max: 21.6),
        temperatureUnit: 'F',
      );
      expect(notes, contains('H 71°F'));
    });
  });

  group('calendarDayFor', () {
    test('keeps the calendar day the schedule heading names', () {
      // The rule is consistency with the screen, not correctness against UTC.
      // A forecast timestamp is a whole-day aggregate; converting it to local
      // can move it a day either way depending on the offset the API sent,
      // and an event that disagrees with the heading the user tapped under
      // reads as a bug however defensible the arithmetic.
      final forecast = _day(date: DateTime.utc(2026, 8, 24, 7));
      final day = calendarDayFor(forecast);

      expect(day.year, 2026);
      expect(day.month, 8);
      expect(day.day, 24);
    });

    test('strips the time so the event is anchored to the date alone', () {
      final day = calendarDayFor(_day(date: DateTime.utc(2026, 8, 24, 23, 59)));

      expect(day.hour, 0);
      expect(day.minute, 0);
      expect(day.second, 0);
    });

    test('produces a local DateTime, never a UTC one', () {
      // An all-day event is a date, and a UTC-flagged midnight would be
      // re-interpreted by the platform.
      expect(
        calendarDayFor(_day(date: DateTime.utc(2026, 8, 24))).isUtc,
        isFalse,
      );
    });
  });

  group('CalendarService.satisfiesWrite', () {
    test('write-only counts as success', () {
      // The package README's own example is
      // `if (status != CalendarPermissionStatus.granted) return;`, which
      // rejects the exact tier this feature requests.
      expect(
        CalendarService.satisfiesWrite(CalendarPermissionStatus.writeOnly),
        isTrue,
      );
    });

    test('full access counts too, because iOS 16 downgrades to it', () {
      // On iOS 16 and below there is no write-only tier and a write-only
      // request resolves to granted.
      expect(
        CalendarService.satisfiesWrite(CalendarPermissionStatus.granted),
        isTrue,
      );
    });

    test('nothing else counts', () {
      for (final status in [
        CalendarPermissionStatus.denied,
        CalendarPermissionStatus.restricted,
        CalendarPermissionStatus.notDetermined,
      ]) {
        expect(
          CalendarService.satisfiesWrite(status),
          isFalse,
          reason: '$status',
        );
      }
    });
  });

  group('CalendarService.mapRefusal', () {
    test('denied is terminal — only Settings can change it', () {
      // The plugin's `denied` means the system dialog can no longer be shown.
      expect(
        CalendarService.mapRefusal(CalendarPermissionStatus.denied),
        CalendarAddResult.permissionPermanentlyDenied,
      );
    });

    test('notDetermined is recoverable, so it must not be terminal', () {
      // Collapsing these two is how an app ends up telling a user to open
      // Settings when it could simply ask again.
      expect(
        CalendarService.mapRefusal(CalendarPermissionStatus.notDetermined),
        CalendarAddResult.permissionDenied,
      );
    });

    test('restricted is its own case, because Settings will not help', () {
      // Screen Time or MDM. The user cannot grant this even if willing, so
      // pointing them at Settings would be bad advice.
      expect(
        CalendarService.mapRefusal(CalendarPermissionStatus.restricted),
        CalendarAddResult.permissionRestricted,
      );
    });

    test('every status is mapped', () {
      for (final status in CalendarPermissionStatus.values) {
        expect(
          () => CalendarService.mapRefusal(status),
          returnsNormally,
          reason: '$status',
        );
      }
    });
  });
}
