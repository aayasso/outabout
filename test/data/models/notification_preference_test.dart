// Tests for the per-activity notification preference.
//
// Two properties carry the weight here, and both are about silence:
//
//   1. An absent or partial row must read as "morning of, on". The table
//      shipped with every notify_* column defaulting to false, so reading
//      those defaults as intent would mean an activity that never notifies —
//      and nothing would surface it.
//   2. Turning a nudge OFF must actually persist. toJson writes every flag
//      explicitly for that reason; an upsert that omitted a false would leave
//      the previous true standing, and the user would believe they had turned
//      something off when they had not.

import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/notification_preference.dart';

void main() {
  group('NotificationPreference.fromJson', () {
    test('a row with only its key reads as the morning-of default', () {
      final p = NotificationPreference.fromJson({'activity_id': 'a1'});
      expect(p.notifyMorningOf, true);
      expect(p.notifyNightBefore, false);
      expect(p.notifyDaysBefore, false);
      expect(p.daysBeforeCount, 2);
      expect(p.morningTime, defaultMorningTime);
    });

    test('an explicit false is obeyed, not overridden by the default', () {
      final p = NotificationPreference.fromJson({
        'activity_id': 'a1',
        'notify_morning_of': false,
      });
      expect(p.notifyMorningOf, false);
      expect(p.isSilent, true);
    });

    test('days_before_count is clamped to what the forecast can serve', () {
      // Must agree with the clamp in scheduling.ts, or the app offers a
      // setting the server quietly refuses.
      expect(
        NotificationPreference.fromJson(
                {'activity_id': 'a1', 'days_before_count': 0})
            .daysBeforeCount,
        minDaysBeforeCount,
      );
      expect(
        NotificationPreference.fromJson(
                {'activity_id': 'a1', 'days_before_count': 99})
            .daysBeforeCount,
        maxDaysBeforeCount,
      );
    });

    test('a malformed morning_time falls back rather than propagating', () {
      for (final bad in [null, '', 'x']) {
        final p = NotificationPreference.fromJson({
          'activity_id': 'a1',
          'morning_time': ?bad,
        });
        expect(p.morningTime, defaultMorningTime, reason: 'for "$bad"');
      }
    });
  });

  group('toJson', () {
    test('every flag is written, including the false ones', () {
      const p = NotificationPreference(
        activityId: 'a1',
        notifyMorningOf: false,
        notifyNightBefore: false,
        notifyDaysBefore: false,
      );
      final json = p.toJson();
      expect(json['notify_morning_of'], false);
      expect(json['notify_night_before'], false);
      expect(json['notify_days_before'], false);
    });

    test('round-trips through fromJson unchanged', () {
      const original = NotificationPreference(
        activityId: 'a1',
        notifyMorningOf: false,
        notifyNightBefore: true,
        notifyDaysBefore: true,
        daysBeforeCount: 4,
        morningTime: '08:30:00',
      );
      final back = NotificationPreference.fromJson(original.toJson());
      expect(back.notifyMorningOf, false);
      expect(back.notifyNightBefore, true);
      expect(back.daysBeforeCount, 4);
      expect(back.morningTime, '08:30:00');
    });
  });

  group('isSilent', () {
    test('true only when nothing at all will be sent', () {
      const allOff = NotificationPreference(
        activityId: 'a1',
        notifyMorningOf: false,
      );
      expect(allOff.isSilent, true);

      expect(
        const NotificationPreference(
          activityId: 'a1',
          notifyMorningOf: false,
          notifyNightBefore: true,
        ).isSilent,
        false,
      );
    });
  });

  group('copyWith', () {
    test('clamps the count rather than trusting the caller', () {
      const p = NotificationPreference(activityId: 'a1');
      expect(p.copyWith(daysBeforeCount: 40).daysBeforeCount, maxDaysBeforeCount);
      expect(p.copyWith(daysBeforeCount: -1).daysBeforeCount, minDaysBeforeCount);
    });

    test('leaves untouched fields alone', () {
      const p = NotificationPreference(activityId: 'a1', morningTime: '06:15:00');
      final next = p.copyWith(notifyNightBefore: true);
      expect(next.morningTime, '06:15:00');
      expect(next.notifyMorningOf, true);
      expect(next.activityId, 'a1');
    });
  });

  group('wall time', () {
    test('parses to hour and minute', () {
      const p = NotificationPreference(activityId: 'a1', morningTime: '07:45:00');
      expect(p.morningHourMinute, (hour: 7, minute: 45));
    });

    test('an unparseable value reads as the default morning, never throws', () {
      const p = NotificationPreference(activityId: 'a1', morningTime: 'ab:cd');
      expect(p.morningHourMinute, (hour: 7, minute: 0));
    });

    test('formats back into the shape a Postgres time column wants', () {
      expect(NotificationPreference.formatWallTime(7, 5), '07:05:00');
      expect(NotificationPreference.formatWallTime(19, 30), '19:30:00');
    });
  });
}
