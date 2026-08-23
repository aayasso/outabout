import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/repositories/activity_repository.dart';

/// A terminal builder that records nothing and completes with [_result].
///
/// Hand-written rather than mocked: postgrest's builders are themselves
/// Futures, and stubbing `then` through mocktail obscures more than it proves.
class _FakeFilter<T> extends Fake implements PostgrestFilterBuilder<T> {
  _FakeFilter(this._result, [Map<String, dynamic>? row])
    : _row = row ?? const <String, dynamic>{};
  final T _result;

  /// What `.single()` resolves to, when the chain asks for one row back.
  final Map<String, dynamic> _row;

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() =>
      _FakeFilter<Map<String, dynamic>>(_row);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) async => onValue(_result);
}

/// Records which operations each table received.
class _FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  _FakeQueryBuilder(this.table, this.log, this.selectResult);

  final String table;
  final List<String> log;
  final Map<String, dynamic> selectResult;

  @override
  PostgrestFilterBuilder<dynamic> update(Map value, {bool? defaultToNull}) {
    log.add('$table.update');
    return _FakeFilter<dynamic>(null);
  }

  @override
  PostgrestFilterBuilder<dynamic> upsert(
    Object values, {
    String? onConflict,
    bool? ignoreDuplicates,
    bool? defaultToNull,
  }) {
    log.add('$table.upsert');
    return _FakeFilter<dynamic>(null);
  }

  @override
  PostgrestFilterBuilder<dynamic> delete() {
    log.add('$table.delete');
    return _FakeFilter<dynamic>(null);
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([
    String columns = '*',
  ]) {
    log.add('$table.select');
    return _FakeFilter<List<Map<String, dynamic>>>([
      selectResult,
    ], selectResult);
  }
}

class _FakeClient extends Fake implements SupabaseClient {
  _FakeClient(this.log, this.selectResult);

  final List<String> log;
  final Map<String, dynamic> selectResult;

  @override
  SupabaseQueryBuilder from(String table) =>
      _FakeQueryBuilder(table, log, selectResult);
}

void main() {
  const activity = Activity(id: 'act-1', userId: 'user-1', name: 'Running');

  late List<String> log;
  late ActivityRepository repo;

  setUp(() {
    log = [];
    repo = ActivityRepository(
      _FakeClient(log, {
        'id': 'act-1',
        'user_id': 'user-1',
        'name': 'Running',
        'category_ids': <String>[],
        'is_archived': false,
      }),
    );
  });

  group('updateWithConditions', () {
    test('clearing every condition deletes the profile row', () async {
      // The bug: `if (profile != null) { upsert }` with no else branch. The
      // row survived, fetchForUser's join handed it back, and the app kept
      // matching on constraints the user had explicitly cleared — after
      // reporting the save as successful and firing a success haptic.
      await repo.updateWithConditions(activity, null);

      expect(
        log,
        contains('condition_profiles.delete'),
        reason: 'a cleared profile must be removed, not skipped',
      );
      expect(log, isNot(contains('condition_profiles.upsert')));
    });

    test('a profile with conditions is upserted, never deleted', () async {
      const profile = ConditionProfile(
        id: 'p1',
        activityId: 'act-1',
        tempEnabled: true,
        tempMin: 10,
        tempMax: 25,
      );

      await repo.updateWithConditions(activity, profile);

      expect(log, contains('condition_profiles.upsert'));
      expect(log, isNot(contains('condition_profiles.delete')));
    });

    test('the activity row itself is always updated', () async {
      await repo.updateWithConditions(activity, null);
      expect(log.first, 'activities.update');
    });
  });
}
