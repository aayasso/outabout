import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/condition_profile.dart';

void main() {
  group('ConditionProfile', () {
    final json = <String, dynamic>{
      'id': 'cp-1',
      'activity_id': 'act-1',
      'temp_enabled': true,
      'temp_min': 10.0,
      'temp_max': 25.5,
      'precip_enabled': true,
      'precip_level': 'none',
      'wind_enabled': true,
      'wind_max': 20.0,
      'created_at': '2026-05-01T10:00:00.000Z',
      'updated_at': '2026-05-02T12:00:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final profile = ConditionProfile.fromJson(json);

      expect(profile.id, 'cp-1');
      expect(profile.activityId, 'act-1');
      expect(profile.tempEnabled, true);
      expect(profile.tempMin, 10.0);
      expect(profile.tempMax, 25.5);
      expect(profile.precipEnabled, true);
      expect(profile.precipLevel, 'none');
      expect(profile.windEnabled, true);
      expect(profile.windMax, 20.0);
      expect(profile.createdAt, isNotNull);
      expect(profile.updatedAt, isNotNull);
    });

    test('fromJson/toJson round-trip preserves data', () {
      final profile = ConditionProfile.fromJson(json);
      final output = profile.toJson();

      expect(output['id'], 'cp-1');
      expect(output['activity_id'], 'act-1');
      expect(output['temp_enabled'], true);
      expect(output['temp_min'], 10.0);
      expect(output['temp_max'], 25.5);
      expect(output['precip_enabled'], true);
      expect(output['precip_level'], 'none');
      expect(output['wind_enabled'], true);
      expect(output['wind_max'], 20.0);
    });

    test('defaults when fields are missing', () {
      final profile = ConditionProfile.fromJson({
        'id': 'cp-2',
        'activity_id': 'act-2',
      });

      expect(profile.tempEnabled, false);
      expect(profile.tempMin, isNull);
      expect(profile.tempMax, isNull);
      expect(profile.precipEnabled, false);
      expect(profile.precipLevel, isNull);
      expect(profile.windEnabled, false);
      expect(profile.windMax, isNull);
      expect(profile.createdAt, isNull);
      expect(profile.updatedAt, isNull);
    });
  });
}
