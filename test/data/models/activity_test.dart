import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/models/activity.dart';

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
}
