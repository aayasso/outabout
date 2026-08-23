import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/data/repositories/activity_day_outcome_repository.dart';

/// One recorded write, with the arguments that decide whether it is safe.
///
/// The sibling fake in activity_repository_test.dart records only the table
/// and verb, which is enough there. It is not enough here: the whole
/// correctness of this repository is in `onConflict` and `ignoreDuplicates`,
/// so those are what this fake captures.
class _Call {
  _Call(this.verb, {this.payload, this.onConflict, this.ignoreDuplicates});
  final String verb;
  final Object? payload;
  final String? onConflict;
  final bool? ignoreDuplicates;

  @override
  String toString() =>
      '$verb(onConflict: $onConflict, ignoreDuplicates: $ignoreDuplicates)';
}

class _FakeFilter<T> extends Fake implements PostgrestFilterBuilder<T> {
  _FakeFilter(this._result, this._filters);
  final T _result;
  final List<String> _filters;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    _filters.add('$column=$value');
    return this;
  }

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    _filters.add('order:$column:${ascending ? 'asc' : 'desc'}');
    return this;
  }

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) async => onValue(_result);
}

class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this.calls, this.filters, this.selectResult);

  final List<_Call> calls;
  final List<String> filters;
  final List<Map<String, dynamic>> selectResult;

  @override
  PostgrestFilterBuilder<dynamic> upsert(
    Object values, {
    String? onConflict,
    bool? ignoreDuplicates,
    bool? defaultToNull,
  }) {
    calls.add(
      _Call(
        'upsert',
        payload: values,
        onConflict: onConflict,
        ignoreDuplicates: ignoreDuplicates,
      ),
    );
    return _FakeFilter<dynamic>(null, filters);
  }

  @override
  PostgrestFilterBuilder<dynamic> update(Map value, {bool? defaultToNull}) {
    calls.add(_Call('update', payload: value));
    return _FakeFilter<dynamic>(null, filters);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    calls.add(_Call('select'));
    return _FakeFilter<List<Map<String, dynamic>>>(selectResult, filters);
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient({this.selectResult = const []});

  final List<Map<String, dynamic>> selectResult;
  final List<_Call> calls = [];
  final List<String> filters = [];
  final List<String> tables = [];

  @override
  SupabaseQueryBuilder from(String table) {
    tables.add(table);
    return _FakeQueryBuilder(calls, filters, selectResult);
  }
}

void main() {
  const opportunity = ActivityDayOutcome(
    userId: 'user-1',
    activityId: 'act-1',
    localDate: '2026-08-23',
  );

  group('fetchForActivity', () {
    test('filters by user and activity and orders oldest first', () async {
      final client = _FakeClient(
        selectResult: [
          {
            'id': 'row-1',
            'user_id': 'user-1',
            'activity_id': 'act-1',
            'local_date': '2026-08-23',
            'matched': true,
            'outcome': 'done',
          },
        ],
      );

      final rows = await ActivityDayOutcomeRepository(
        client,
      ).fetchForActivity('user-1', 'act-1');

      expect(client.tables, ['activity_day_outcomes']);
      expect(
        client.filters,
        containsAll(['user_id=user-1', 'activity_id=act-1']),
      );
      expect(client.filters, contains('order:local_date:asc'));
      expect(rows.single.outcome, DayOutcome.done);
    });
  });

  group('recordMatchedDays', () {
    test('sets ignoreDuplicates so re-observing a day is a no-op', () async {
      // Without this, re-observing a day the user already answered rewrites
      // the row and destroys the answer. The app re-observes on every resume.
      final client = _FakeClient();
      await ActivityDayOutcomeRepository(
        client,
      ).recordMatchedDays([opportunity]);

      expect(client.calls.single.verb, 'upsert');
      expect(client.calls.single.ignoreDuplicates, isTrue);
    });

    test('targets the user, activity and day conflict key', () async {
      final client = _FakeClient();
      await ActivityDayOutcomeRepository(
        client,
      ).recordMatchedDays([opportunity]);

      expect(client.calls.single.onConflict, 'user_id,activity_id,local_date');
    });

    test('sends one payload per day', () async {
      final client = _FakeClient();
      await ActivityDayOutcomeRepository(client).recordMatchedDays([
        opportunity,
        const ActivityDayOutcome(
          userId: 'user-1',
          activityId: 'act-2',
          localDate: '2026-08-23',
        ),
      ]);

      expect(client.calls.single.payload, isA<List<dynamic>>());
      expect(client.calls.single.payload as List, hasLength(2));
    });

    test('issues no request at all for an empty list', () async {
      final client = _FakeClient();
      await ActivityDayOutcomeRepository(client).recordMatchedDays([]);

      expect(client.calls, isEmpty);
      expect(client.tables, isEmpty);
    });
  });

  group('answer', () {
    Future<_FakeClient> submit({String? reason}) async {
      final client = _FakeClient();
      await ActivityDayOutcomeRepository(client).answer(
        userId: 'user-1',
        activityId: 'act-1',
        localDate: '2026-08-23',
        outcome: DayOutcome.done,
        answeredAt: DateTime.utc(2026, 8, 23, 18, 30),
        reason: reason,
      );
      return client;
    }

    test('upserts rather than updates so a missing row is created', () async {
      // The opportunity row may not exist: the app can be offline the day a
      // match happens and online only that evening. An .update() matching no
      // row succeeds while writing nothing, so the answer vanishes with no
      // error — the same silent loss updateWithConditions had to be fixed for.
      final client = await submit();

      expect(client.calls.single.verb, 'upsert');
    });

    test(
      'does not set ignoreDuplicates, because this write must win',
      () async {
        // With it set, every answer for a day that already has an opportunity
        // row — which is every answer — would be silently discarded.
        final client = await submit();

        expect(client.calls.single.ignoreDuplicates, isNot(isTrue));
      },
    );

    test('targets the same conflict key as the opportunity write', () async {
      final client = await submit();

      expect(client.calls.single.onConflict, 'user_id,activity_id,local_date');
    });

    test('writes the outcome, the day and the injected timestamp', () async {
      final client = await submit();
      final payload = client.calls.single.payload! as Map<String, dynamic>;

      expect(payload['user_id'], 'user-1');
      expect(payload['activity_id'], 'act-1');
      expect(payload['local_date'], '2026-08-23');
      expect(payload['outcome'], 'done');
      expect(payload['answered_at'], '2026-08-23T18:30:00.000Z');
    });

    test(
      'marks the day matched so a self-healing insert is an opportunity',
      () async {
        // If the row is being created here, it must still count in the
        // denominator — otherwise answering a day the app never observed would
        // add a completion with no opportunity behind it.
        final client = await submit();
        final payload = client.calls.single.payload! as Map<String, dynamic>;

        expect(payload['matched'], isTrue);
      },
    );

    test('omits reason when the user skipped the chips', () async {
      final client = await submit();
      final payload = client.calls.single.payload! as Map<String, dynamic>;

      expect(payload.containsKey('reason'), isFalse);
    });

    test('includes reason when the user picked one', () async {
      final client = await submit(reason: 'too_busy');
      final payload = client.calls.single.payload! as Map<String, dynamic>;

      expect(payload['reason'], 'too_busy');
    });
  });
}
