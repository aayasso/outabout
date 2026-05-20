import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/category.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/tabs/activities_tab.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class _MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

final _testCategories = [
  Category(
    id: 'cat-running',
    userId: 'user-1',
    name: 'Running',
  ),
  Category(
    id: 'cat-hiking',
    userId: 'user-1',
    name: 'Hiking',
  ),
];

final _testActivities = [
  Activity(
    id: 'act-1',
    userId: 'user-1',
    name: 'Morning Run',
    categoryIds: ['cat-running'],
  ),
  Activity(
    id: 'act-2',
    userId: 'user-1',
    name: 'Trail Hike',
    categoryIds: ['cat-hiking'],
  ),
  Activity(
    id: 'act-3',
    userId: 'user-1',
    name: 'Free Play',
    categoryIds: [],
  ),
];

Widget _buildTab({
  List<Category>? categories,
  List<Activity>? activities,
  AsyncValue<List<Category>>? categoriesOverride,
}) {
  final mockEventService =
      _MockBehavioralEventService();
  when(() => mockEventService.log(
        any(),
        extra: any(named: 'extra'),
      )).thenAnswer((_) async {});
  return ProviderScope(
    overrides: [
      weatherThemeProvider.overrideWith(
        (ref) =>
            WeatherThemeNotifier(WeatherTheme.sunny),
      ),
      weatherThemeColorsProvider.overrideWithValue(
        WeatherThemeColors.sunny,
      ),
      behavioralEventServiceProvider
          .overrideWithValue(mockEventService),
      activitiesProvider.overrideWith(
        (ref) async =>
            activities ?? _testActivities,
      ),
      profileProvider.overrideWith(
        (ref) async => null,
      ),
      if (categoriesOverride != null)
        categoriesProvider.overrideWith(
          (ref) => categoriesOverride.when(
            data: (d) async => d,
            loading: () =>
                Future<List<Category>>.delayed(
              const Duration(days: 1),
            ),
            error: (e, st) async => throw e,
          ),
        )
      else
        categoriesProvider.overrideWith(
          (ref) async =>
              categories ?? _testCategories,
        ),
    ],
    child: const MaterialApp(
      home: ActivitiesTab(),
    ),
  );
}

/// Pump long enough for providers to resolve and
/// flutter_animate animations to advance past their
/// durations. Avoids pumpAndSettle which hangs on
/// flutter_animate's repeating timers.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Category filter chip row', () {
    testWidgets(
      'renders "All" + category chips from mocked '
      'categoriesProvider',
      (tester) async {
        await tester.pumpWidget(_buildTab());
        await _settle(tester);

        expect(find.text('All'), findsOneWidget);
        expect(
          find.text('Running'),
          findsOneWidget,
        );
        expect(
          find.text('Hiking'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping a category chip adds it to selection',
      (tester) async {
        await tester.pumpWidget(_buildTab());
        await _settle(tester);

        await tester.tap(find.text('Running'));
        await _settle(tester);

        final colors = WeatherThemeColors.sunny;
        final expectedColor =
            colors.primary.withValues(alpha: 0.15);
        var foundSelected = false;

        final containers =
            find.byType(Container).evaluate();
        for (final element in containers) {
          final widget = element.widget as Container;
          final decoration = widget.decoration;
          if (decoration is BoxDecoration &&
              decoration.color == expectedColor) {
            foundSelected = true;
            break;
          }
        }
        expect(foundSelected, isTrue);
      },
    );

    testWidgets(
      'tapping "All" clears selection',
      (tester) async {
        await tester.pumpWidget(_buildTab());
        await _settle(tester);

        // Select a category first
        await tester.tap(find.text('Hiking'));
        await _settle(tester);

        // Now tap "All"
        await tester.tap(find.text('All'));
        await _settle(tester);

        // All three activities should be visible
        expect(
          find.text('Morning Run'),
          findsOneWidget,
        );
        expect(
          find.text('Trail Hike'),
          findsOneWidget,
        );
        expect(
          find.text('Free Play'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'chip row hidden when categories list is empty',
      (tester) async {
        await tester.pumpWidget(
          _buildTab(categories: []),
        );
        await _settle(tester);

        expect(find.text('All'), findsNothing);
      },
    );

    testWidgets(
      'chip row hidden when categoriesProvider errors',
      (tester) async {
        await tester.pumpWidget(
          _buildTab(
            categoriesOverride: AsyncError(
              Exception('network error'),
              StackTrace.current,
            ),
          ),
        );
        await _settle(tester);

        expect(find.text('All'), findsNothing);
        // Activities still render without filtering
        expect(
          find.text('Morning Run'),
          findsOneWidget,
        );
      },
    );
  });

  group('Filtered empty state', () {
    testWidgets(
      'appears when filter yields zero results',
      (tester) async {
        await tester.pumpWidget(
          _buildTab(
            activities: [
              Activity(
                id: 'act-1',
                userId: 'user-1',
                name: 'Morning Run',
                categoryIds: ['cat-running'],
              ),
            ],
          ),
        );
        await _settle(tester);

        await tester.tap(find.text('Hiking'));
        await _settle(tester);

        expect(
          find.text(
            'No activities in these categories',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Clear filters'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '"Clear filters" resets to unfiltered list',
      (tester) async {
        await tester.pumpWidget(
          _buildTab(
            activities: [
              Activity(
                id: 'act-1',
                userId: 'user-1',
                name: 'Morning Run',
                categoryIds: ['cat-running'],
              ),
            ],
          ),
        );
        await _settle(tester);

        // Select "Hiking" — filters out everything
        await tester.tap(find.text('Hiking'));
        await _settle(tester);

        expect(
          find.text(
            'No activities in these categories',
          ),
          findsOneWidget,
        );

        // Tap "Clear filters"
        await tester.tap(find.text('Clear filters'));
        await _settle(tester);

        // Activity list returns
        expect(
          find.text('Morning Run'),
          findsOneWidget,
        );
        expect(
          find.text(
            'No activities in these categories',
          ),
          findsNothing,
        );
      },
    );
  });
}
