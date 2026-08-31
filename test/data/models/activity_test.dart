import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/condition_profile.dart';

void main() {
  group('Activity', () {
    final json = <String, dynamic>{
      'id': 'act-1',
      'user_id': 'user-1',
      'name': 'Morning Run',
      'notes': 'At the park',
      'url': 'https://example.com',
      'location': 'Central Park',
      'category_ids': ['cat-1', 'cat-2'],
      'is_archived': false,
      'created_at': '2026-05-01T10:00:00.000Z',
      'updated_at': '2026-05-02T12:00:00.000Z',
      'geographic_context': {'region': 'northeast'},
      'condition_profiles': {
        'id': 'cp-1',
        'activity_id': 'act-1',
        'temp_enabled': true,
        'temp_min': 15.0,
        'temp_max': 30.0,
      },
    };

    test('fromJson parses all fields correctly', () {
      final activity = Activity.fromJson(json);

      expect(activity.id, 'act-1');
      expect(activity.userId, 'user-1');
      expect(activity.name, 'Morning Run');
      expect(activity.notes, 'At the park');
      expect(activity.url, 'https://example.com');
      expect(activity.location, 'Central Park');
      expect(activity.categoryIds, ['cat-1', 'cat-2']);
      expect(activity.isArchived, false);
      expect(activity.createdAt, isNotNull);
      expect(activity.updatedAt, isNotNull);
      expect(
        activity.geographicContext,
        {'region': 'northeast'},
      );
      expect(activity.conditionProfile, isNotNull);
      expect(activity.conditionProfile!.id, 'cp-1');
    });

    test('toJson produces snake_case keys', () {
      final activity = Activity.fromJson(json);
      final output = activity.toJson();

      expect(output['user_id'], 'user-1');
      expect(output['name'], 'Morning Run');
      expect(output['category_ids'], ['cat-1', 'cat-2']);
      expect(output['is_archived'], false);
      expect(output['geographic_context'], isA<Map>());
    });

    test('toJson has no category field', () {
      final activity = Activity.fromJson(json);
      final output = activity.toJson();

      expect(output.containsKey('category'), false);
    });

    test('categoryIds parses from list correctly', () {
      final activity = Activity.fromJson({
        'user_id': 'u1',
        'name': 'Test',
        'category_ids': ['a', 'b', 'c'],
      });

      expect(activity.categoryIds, ['a', 'b', 'c']);
    });

    test('categoryIds defaults to empty list when null', () {
      final activity = Activity.fromJson({
        'user_id': 'u1',
        'name': 'Test',
      });

      expect(activity.categoryIds, isEmpty);
    });

    test(
      'conditionProfile parses from nested map',
      () {
        final activity = Activity.fromJson(json);
        expect(activity.conditionProfile, isNotNull);
        expect(
          activity.conditionProfile!.tempEnabled,
          true,
        );
        expect(activity.conditionProfile!.tempMin, 15.0);
        expect(activity.conditionProfile!.tempMax, 30.0);
      },
    );

    test(
      'conditionProfile is null when not a map',
      () {
        final activity = Activity.fromJson({
          'user_id': 'u1',
          'name': 'Test',
          'condition_profiles': null,
        });
        expect(activity.conditionProfile, isNull);
      },
    );
  });

  group('copyWith', () {
    final full = Activity(
      id: 'a1',
      userId: 'u1',
      name: 'Morning Run',
      notes: 'notes',
      url: 'https://example.com',
      location: 'Dolores Park',
      categoryIds: const ['c1'],
      isArchived: true,
      geographicContext: const {'metro': 'SF'},
      conditionProfile: const ConditionProfile(
        id: 'p1',
        activityId: 'a1',
        windEnabled: true,
        windMax: 25,
      ),
    );

    test('carries every field through an empty copy', () {
      // The reason this exists: insertWithConditions hand-rebuilt an Activity
      // field by field and silently dropped url, location and isArchived. A
      // hand-written constructor call is a list that can be incomplete; a
      // copyWith cannot be.
      final copy = full.copyWith();

      expect(copy.id, full.id);
      expect(copy.userId, full.userId);
      expect(copy.name, full.name);
      expect(copy.notes, full.notes);
      expect(copy.url, full.url);
      expect(copy.location, full.location);
      expect(copy.categoryIds, full.categoryIds);
      expect(copy.isArchived, full.isArchived);
      expect(copy.geographicContext, full.geographicContext);
      expect(copy.conditionProfile, full.conditionProfile);
    });

    test('replaces only what it is given', () {
      final copy = full.copyWith(name: 'Evening Walk');
      expect(copy.name, 'Evening Walk');
      expect(copy.url, full.url);
      expect(copy.location, full.location);
    });

    test('attaches a condition profile without disturbing the rest', () {
      // Exactly what insertWithConditions needs to do.
      const profile = ConditionProfile(
        id: 'p2',
        activityId: 'a1',
        tempEnabled: true,
        tempMin: 10,
      );
      final copy = full.copyWith(conditionProfile: profile);

      expect(copy.conditionProfile, profile);
      expect(copy.url, 'https://example.com');
      expect(copy.location, 'Dolores Park');
      expect(copy.isArchived, isTrue);
    });
  });
}
