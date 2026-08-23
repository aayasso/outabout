import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/activity_day_outcome.dart';

void main() {
  group('fromJson', () {
    test('reads the snake_case columns', () {
      final row = ActivityDayOutcome.fromJson({
        'id': 'row-1',
        'user_id': 'user-1',
        'activity_id': 'act-1',
        'local_date': '2026-08-23',
        'matched': true,
        'outcome': 'done',
        'reason': 'too_busy',
        'answered_at': '2026-08-23T18:04:00.000Z',
        'created_at': '2026-08-23T09:00:00.000Z',
      });

      expect(row.id, 'row-1');
      expect(row.userId, 'user-1');
      expect(row.activityId, 'act-1');
      expect(row.localDate, '2026-08-23');
      expect(row.matched, isTrue);
      expect(row.outcome, DayOutcome.done);
      expect(row.reason, 'too_busy');
      expect(row.answeredAt, DateTime.utc(2026, 8, 23, 18, 4));
      expect(row.createdAt, DateTime.utc(2026, 8, 23, 9));
    });

    test('tolerates an unanswered row', () {
      final row = ActivityDayOutcome.fromJson({
        'user_id': 'user-1',
        'activity_id': 'act-1',
        'local_date': '2026-08-23',
        'matched': true,
        'outcome': null,
        'reason': null,
        'answered_at': null,
      });

      expect(row.outcome, isNull);
      expect(row.answeredAt, isNull);
      expect(row.isAnswered, isFalse);
    });

    test('carries local_date as literal text rather than re-parsing it', () {
      // A Postgres `date` has no instant. Round-tripping it through a local
      // DateTime is how "today" silently becomes "yesterday" west of UTC.
      const raw = '2026-08-23';
      final row = ActivityDayOutcome.fromJson({
        'user_id': 'user-1',
        'activity_id': 'act-1',
        'local_date': raw,
        'matched': true,
      });

      expect(row.localDate, same(raw));
      expect(row.localDate, isA<String>());
    });
  });

  group('toJson', () {
    const unanswered = ActivityDayOutcome(
      userId: 'user-1',
      activityId: 'act-1',
      localDate: '2026-08-23',
    );

    test(
      'emits snake_case and omits a null id so the database assigns one',
      () {
        final json = unanswered.toJson();
        expect(json['user_id'], 'user-1');
        expect(json['activity_id'], 'act-1');
        expect(json['local_date'], '2026-08-23');
        expect(json['matched'], isTrue);
        expect(json.containsKey('id'), isFalse);
      },
    );

    test('omits outcome and answered_at when unanswered', () {
      // The opportunity upsert sends this payload with ignoreDuplicates off in
      // one direction and on in the other. If it carries `outcome: null`, a
      // re-observation of a day the user already answered blanks that answer
      // on conflict — the streak silently loses a completed day.
      final json = unanswered.toJson();
      expect(json.containsKey('outcome'), isFalse);
      expect(json.containsKey('answered_at'), isFalse);
      expect(json.containsKey('reason'), isFalse);
    });

    test('emits outcome and answered_at when answered', () {
      final json = ActivityDayOutcome(
        userId: 'user-1',
        activityId: 'act-1',
        localDate: '2026-08-23',
        outcome: DayOutcome.skipped,
        reason: 'too_busy',
        answeredAt: DateTime.utc(2026, 8, 23, 18),
      ).toJson();

      expect(json['outcome'], 'skipped');
      expect(json['reason'], 'too_busy');
      expect(json['answered_at'], '2026-08-23T18:00:00.000Z');
    });

    test('round-trips through fromJson', () {
      final original = ActivityDayOutcome(
        userId: 'user-1',
        activityId: 'act-1',
        localDate: '2026-08-23',
        outcome: DayOutcome.done,
        answeredAt: DateTime.utc(2026, 8, 23, 18),
      );
      final restored = ActivityDayOutcome.fromJson(original.toJson());

      expect(restored.userId, original.userId);
      expect(restored.activityId, original.activityId);
      expect(restored.localDate, original.localDate);
      expect(restored.outcome, original.outcome);
      expect(restored.answeredAt, original.answeredAt);
    });
  });

  group('DayOutcome', () {
    test('matches the values the database CHECK constraint allows', () {
      expect(DayOutcome.done, 'done');
      expect(DayOutcome.skipped, 'skipped');
    });

    test('isAnswered is true only for a recognised outcome', () {
      ActivityDayOutcome withOutcome(String? outcome) => ActivityDayOutcome(
        userId: 'u',
        activityId: 'a',
        localDate: '2026-08-23',
        outcome: outcome,
      );
      expect(withOutcome(DayOutcome.done).isAnswered, isTrue);
      expect(withOutcome(DayOutcome.skipped).isAnswered, isTrue);
      expect(withOutcome(null).isAnswered, isFalse);
      expect(withOutcome('deferred').isAnswered, isFalse);
    });
  });
}
