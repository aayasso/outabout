import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/repositories/category_repository.dart';

void main() {
  group('defaultCategories', () {
    test('contains exactly 8 categories', () {
      expect(defaultCategories.length, 8);
    });

    test('names match locked spec values', () {
      final names =
          defaultCategories.map((d) => d.$1).toList();
      expect(names, [
        'Running',
        'Hiking',
        'Cycling',
        'Photography',
        'Beach',
        'Skiing',
        'Camping',
        'Picnic',
      ]);
    });

    test('colors match locked spec values', () {
      final colors =
          defaultCategories.map((d) => d.$2).toList();
      expect(colors, [
        '#E55934',
        '#43A047',
        '#1E88E5',
        '#8E24AA',
        '#F4B942',
        '#039BE5',
        '#8D6E63',
        '#FB8C00',
      ]);
    });

    test('all colors are valid hex format', () {
      final hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
      for (final (name, color) in defaultCategories) {
        expect(
          hexPattern.hasMatch(color),
          true,
          reason: '$name color $color is not valid hex',
        );
      }
    });

    test('all names are non-empty', () {
      for (final (name, _) in defaultCategories) {
        expect(name.isNotEmpty, true);
      }
    });
  });
}
