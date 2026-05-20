import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/category.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/widgets/category_chip_picker.dart';

final _testCategories = [
  Category(
    id: 'cat-1',
    userId: 'user-1',
    name: 'Running',
    color: '#E55934',
  ),
  Category(
    id: 'cat-2',
    userId: 'user-1',
    name: 'Hiking',
    color: '#43A047',
  ),
  Category(
    id: 'cat-3',
    userId: 'user-1',
    name: 'Cycling',
    color: '#1E88E5',
  ),
];

void main() {
  Widget buildTestWidget({
    Set<String> selectedIds = const {},
    ValueChanged<String>? onToggle,
    VoidCallback? onCreateCategory,
    List<Category>? categories,
  }) {
    return ProviderScope(
      overrides: [
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(
          WeatherThemeColors.sunny,
        ),
        categoriesProvider.overrideWith(
          (ref) async => categories ?? _testCategories,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CategoryChipPicker(
            selectedIds: selectedIds,
            onToggle: onToggle ?? (_) {},
            onCreateCategory: onCreateCategory ?? () {},
          ),
        ),
      ),
    );
  }

  group('CategoryChipPicker', () {
    testWidgets(
      'renders chips from mocked categoriesProvider',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Running'), findsOneWidget);
        expect(find.text('Hiking'), findsOneWidget);
        expect(find.text('Cycling'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a chip calls onToggle with correct ID',
      (tester) async {
        String? toggledId;

        await tester.pumpWidget(
          buildTestWidget(
            onToggle: (id) => toggledId = id,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Hiking'));
        await tester.pump();

        expect(toggledId, equals('cat-2'));
      },
    );

    testWidgets(
      '"+" chip triggers onCreateCategory callback',
      (tester) async {
        var called = false;

        await tester.pumpWidget(
          buildTestWidget(
            onCreateCategory: () => called = true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(called, isTrue);
      },
    );

    testWidgets(
      'selected chips have primary-colored border',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(selectedIds: {'cat-1'}),
        );
        await tester.pumpAndSettle();

        // Find the Container wrapping "Running" chip
        // by looking for a decorated box with primary
        // border among all decorated containers.
        final colors = WeatherThemeColors.sunny;
        var foundSelectedBorder = false;

        final containers = find
            .descendant(
              of: find.byType(CategoryChipPicker),
              matching: find.byType(Container),
            )
            .evaluate();

        for (final element in containers) {
          final widget = element.widget as Container;
          final decoration = widget.decoration;
          if (decoration is BoxDecoration &&
              decoration.border is Border) {
            final border = decoration.border! as Border;
            if (border.top.color == colors.primary) {
              foundSelectedBorder = true;
              break;
            }
          }
        }

        expect(foundSelectedBorder, isTrue);
      },
    );

    testWidgets(
      'orphaned category ID is not rendered as a chip',
      (tester) async {
        // Give 2 selected IDs but only 1 matching category
        // in the provider response. The orphaned ID should
        // be silently skipped.
        await tester.pumpWidget(
          buildTestWidget(
            selectedIds: {'cat-1', 'deleted-id'},
            categories: [
              Category(
                id: 'cat-1',
                userId: 'user-1',
                name: 'Running',
                color: '#E55934',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Only 1 category chip renders (plus the "+" chip)
        expect(find.text('Running'), findsOneWidget);

        // No chip for the deleted category
        expect(find.text('deleted-id'), findsNothing);
      },
    );
  });
}
