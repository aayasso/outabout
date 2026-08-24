import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/router.dart';
import 'package:outabout/features/widget/widget_launch.dart';

void main() {
  group('routeForWidgetUri', () {
    test('sends the schedule link to the schedule tab', () {
      expect(
        routeForWidgetUri(Uri.parse('outabout://schedule')),
        AppRoutes.home,
      );
    });

    test('ignores a null uri — the ordinary cold start', () {
      expect(routeForWidgetUri(null), isNull);
    });

    test('ignores another app\'s scheme', () {
      expect(routeForWidgetUri(Uri.parse('https://schedule')), isNull);
    });

    test('still routes when a newer widget adds a query it cannot read', () {
      // An unknown *host* is a different destination and is refused. An
      // unknown *query* on a known destination is additive — a later widget
      // linking to `?day=2` should still open the schedule on this build
      // rather than doing nothing at all.
      expect(
        routeForWidgetUri(Uri.parse('outabout://schedule?day=2')),
        AppRoutes.home,
      );
    });

    test('ignores a host this build does not know', () {
      // A newer widget linking somewhere this app cannot render. Guessing it
      // meant the schedule would land the user on a screen they did not ask
      // for, which is worse than doing nothing.
      expect(routeForWidgetUri(Uri.parse('outabout://activity/42')), isNull);
      expect(routeForWidgetUri(Uri.parse('outabout://')), isNull);
    });
  });

  group('WidgetLaunchCoordinator', () {
    late List<String> routed;
    late int opens;
    late WidgetLaunchCoordinator coordinator;

    setUp(() {
      routed = [];
      opens = 0;
      coordinator = WidgetLaunchCoordinator(
        onRoute: routed.add,
        onOpened: () => opens += 1,
      );
    });

    final schedule = Uri.parse('outabout://schedule');

    test('a cold launch routes and counts once', () {
      expect(coordinator.handleLaunch(schedule), isTrue);
      expect(routed, [AppRoutes.home]);
      expect(opens, 1);
    });

    test('an ordinary launch does nothing', () {
      expect(coordinator.handleLaunch(null), isFalse);
      expect(routed, isEmpty);
      expect(opens, 0);
    });

    test('the same tap arriving twice is counted once', () {
      // iOS can deliver a cold-start tap through both the launch check and
      // the click stream. Two rows for one tap would inflate the only number
      // this feature is measured by.
      coordinator.handleLaunch(schedule);
      expect(coordinator.handleClick(schedule), isFalse);

      expect(routed, [AppRoutes.home]);
      expect(opens, 1);
    });

    test('a real second tap still counts', () {
      // Identical URL, different tap. Suppressing it would make the widget
      // stop working after one use per launch.
      coordinator.handleLaunch(schedule);
      coordinator.handleClick(schedule); // the echo
      expect(coordinator.handleClick(schedule), isTrue);

      expect(routed, [AppRoutes.home, AppRoutes.home]);
      expect(opens, 2);
    });

    test('a warm tap with no cold launch behind it counts', () {
      expect(coordinator.handleClick(schedule), isTrue);
      expect(opens, 1);
    });

    test('the echo guard does not swallow a genuinely different url', () {
      // Only an exact repeat of the launch url is an echo. A different one
      // arriving first means the echo never came, and the guard must spend
      // itself on it rather than eating the next real tap.
      coordinator.handleLaunch(schedule);
      expect(
        coordinator.handleClick(Uri.parse('outabout://schedule?day=2')),
        isTrue,
      );
      expect(coordinator.handleClick(schedule), isTrue);
      expect(opens, 3);
    });

    test('an unroutable launch never marks a launch uri', () {
      coordinator.handleLaunch(null);
      expect(coordinator.handleClick(schedule), isTrue);
      expect(opens, 1);
    });
  });
}
