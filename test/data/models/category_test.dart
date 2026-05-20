import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/category.dart';

void main() {
  group('Category', () {
    final json = <String, dynamic>{
      'id': 'cat-1',
      'user_id': 'user-1',
      'name': 'Running',
      'color': '#E55934',
      'icon': 'running',
      'created_at': '2026-05-01T10:00:00.000Z',
    };

    test('fromJson parses all fields correctly', () {
      final category = Category.fromJson(json);

      expect(category.id, 'cat-1');
      expect(category.userId, 'user-1');
      expect(category.name, 'Running');
      expect(category.color, '#E55934');
      expect(category.icon, 'running');
      expect(category.createdAt, isNotNull);
      expect(
        category.createdAt,
        DateTime.utc(2026, 5, 1, 10),
      );
    });

    test('toJson produces correct snake_case keys', () {
      final category = Category.fromJson(json);
      final output = category.toJson();

      expect(output['id'], 'cat-1');
      expect(output['user_id'], 'user-1');
      expect(output['name'], 'Running');
      expect(output['color'], '#E55934');
      expect(output['icon'], 'running');
      expect(output.containsKey('created_at'), true);
    });

    test(
      'fromJson to toJson round trip preserves values',
      () {
        final category = Category.fromJson(json);
        final output = category.toJson();
        final roundTripped = Category.fromJson(output);

        expect(roundTripped.id, category.id);
        expect(roundTripped.userId, category.userId);
        expect(roundTripped.name, category.name);
        expect(roundTripped.color, category.color);
        expect(roundTripped.icon, category.icon);
        expect(
          roundTripped.createdAt,
          category.createdAt,
        );
      },
    );

    test(
      'fromJson handles null color and icon gracefully',
      () {
        final minimal = <String, dynamic>{
          'user_id': 'user-1',
          'name': 'Custom',
        };
        final category = Category.fromJson(minimal);

        expect(category.id, isNull);
        expect(category.userId, 'user-1');
        expect(category.name, 'Custom');
        expect(category.color, isNull);
        expect(category.icon, isNull);
        expect(category.createdAt, isNull);
      },
    );

    test(
      'toJson omits null optional fields',
      () {
        const category = Category(
          userId: 'user-1',
          name: 'Custom',
        );
        final output = category.toJson();

        expect(output.containsKey('id'), false);
        expect(output.containsKey('color'), false);
        expect(output.containsKey('icon'), false);
        expect(output.containsKey('created_at'), false);
        expect(output['user_id'], 'user-1');
        expect(output['name'], 'Custom');
      },
    );
  });
}
