import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/features/home/category_filter.dart';

Activity _activity({
  required String name,
  List<String> categoryIds = const [],
}) {
  return Activity(
    userId: 'user-1',
    name: name,
    categoryIds: categoryIds,
  );
}

void main() {
  group('filterActivitiesByCategories', () {
    final running = _activity(
      name: 'Morning Run',
      categoryIds: ['cat-running'],
    );
    final hiking = _activity(
      name: 'Trail Hike',
      categoryIds: ['cat-hiking'],
    );
    final multisport = _activity(
      name: 'Triathlon Training',
      categoryIds: ['cat-running', 'cat-cycling'],
    );
    final uncategorized = _activity(name: 'Free Play');

    final allActivities = [
      running,
      hiking,
      multisport,
      uncategorized,
    ];

    test(
      'empty selectedCategoryIds returns all activities',
      () {
        final result = filterActivitiesByCategories(
          allActivities,
          {},
        );
        expect(result, allActivities);
      },
    );

    test(
      'one selected category returns only matching activities',
      () {
        final result = filterActivitiesByCategories(
          allActivities,
          {'cat-hiking'},
        );
        expect(result, [hiking]);
      },
    );

    test(
      'multiple selected categories uses OR logic',
      () {
        final result = filterActivitiesByCategories(
          allActivities,
          {'cat-hiking', 'cat-cycling'},
        );
        expect(result, [hiking, multisport]);
      },
    );

    test(
      'activity with empty categoryIds excluded when '
      'filter active',
      () {
        final result = filterActivitiesByCategories(
          allActivities,
          {'cat-running'},
        );
        expect(result, isNot(contains(uncategorized)));
      },
    );

    test(
      'activity with multiple categoryIds matches if any '
      'one is in set',
      () {
        final result = filterActivitiesByCategories(
          allActivities,
          {'cat-cycling'},
        );
        expect(result, [multisport]);
      },
    );

    test(
      'single activity matching multiple selected '
      'categories appears once',
      () {
        final result = filterActivitiesByCategories(
          allActivities,
          {'cat-running', 'cat-cycling'},
        );
        expect(
          result.where((a) => a.name == 'Triathlon Training'),
          hasLength(1),
        );
      },
    );
  });
}
