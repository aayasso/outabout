import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/profile.dart';

void main() {
  group('Profile', () {
    final json = <String, dynamic>{
      'id': 'user-1',
      'display_name': 'Jane Doe',
      'avatar_url': 'https://example.com/avatar.jpg',
      'is_premium': true,
      'temperature_unit': 'C',
      'created_at': '2026-01-15T08:00:00.000Z',
      'updated_at': '2026-05-01T10:00:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Jane Doe');
      expect(
        profile.avatarUrl,
        'https://example.com/avatar.jpg',
      );
      expect(profile.isPremium, true);
      expect(profile.temperatureUnit, 'C');
      expect(profile.createdAt, isNotNull);
      expect(profile.updatedAt, isNotNull);
    });

    test('fromJson/toJson round-trip preserves data', () {
      final profile = Profile.fromJson(json);
      final output = profile.toJson();

      expect(output['id'], 'user-1');
      expect(output['display_name'], 'Jane Doe');
      expect(
        output['avatar_url'],
        'https://example.com/avatar.jpg',
      );
      expect(output['is_premium'], true);
      expect(output['temperature_unit'], 'C');
    });

    test('defaults when optional fields missing', () {
      final profile = Profile.fromJson({
        'id': 'user-2',
      });

      expect(profile.displayName, isNull);
      expect(profile.avatarUrl, isNull);
      expect(profile.isPremium, false);
      expect(profile.temperatureUnit, 'F');
      expect(profile.createdAt, isNull);
      expect(profile.updatedAt, isNull);
    });
  });
}
