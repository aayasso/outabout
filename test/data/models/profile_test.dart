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

    test('notifications_paused defaults to false when the column is absent', () {
      // The column was added after launch, so a row read from a client that
      // has not migrated, or a cached row, will not carry it. Defaulting to
      // true would silence a user who never asked for silence.
      expect(Profile.fromJson(json).notificationsPaused, false);
    });

    test('notifications_paused round-trips when set', () {
      final paused = Profile.fromJson({...json, 'notifications_paused': true});
      expect(paused.notificationsPaused, true);
      expect(paused.toJson()['notifications_paused'], true);
    });

    test('notifications_paused is always written, never omitted', () {
      // Unlike the nullable columns, this one is sent even when false: an
      // update that dropped the key would leave a resumed user paused.
      const resumed = Profile(id: 'user-1');
      expect(resumed.toJson().containsKey('notifications_paused'), true);
      expect(resumed.toJson()['notifications_paused'], false);
    });

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
