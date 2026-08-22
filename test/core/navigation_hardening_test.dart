import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:outabout/core/router.dart';

/// Regression tests for the navigation defects found during stabilization:
///
///  * `/activity/add` resolved to `/activity/:id` with id='add', so the add
///    screen was unreachable.
///  * Sub-screens entered with `go()` are the only page on the stack, so a
///    bare `pop()` threw `GoError: There is nothing to pop`.
void main() {
  group('AppRoutes', () {
    test('addActivity cannot be captured by the /activity/:id pattern', () {
      // go_router matches top-level routes in declaration order and returns
      // the first hit, so any '/activity/<x>' path is claimed by the
      // parameterised route regardless of where it is declared.
      expect(AppRoutes.addActivity.startsWith('/activity/'), isFalse);
      expect(AppRoutes.addActivity, '/add-activity');
    });
  });

  group('route resolution', () {
    /// A miniature router with the same two colliding shapes as the app.
    GoRouter buildRouter() => GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Text('home'),
            ),
            GoRoute(
              path: AppRoutes.activity,
              builder: (_, state) =>
                  Text('detail:${state.pathParameters['id']}'),
            ),
            GoRoute(
              path: AppRoutes.addActivity,
              builder: (_, _) => const Text('add'),
            ),
          ],
        );

    testWidgets('addActivity resolves to the add screen, not detail',
        (tester) async {
      final router = buildRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go(AppRoutes.addActivity);
      await tester.pumpAndSettle();

      expect(find.text('add'), findsOneWidget);
      expect(find.text('detail:add'), findsNothing);
    });

    testWidgets('activity detail still resolves with its id', (tester) async {
      final router = buildRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/activity/abc-123');
      await tester.pumpAndSettle();

      expect(find.text('detail:abc-123'), findsOneWidget);
    });
  });

  group('popOrGo', () {
    late GoRouter router;

    Widget popper(String label) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.popOrGo(),
              child: Text(label),
            ),
          ),
        );

    setUp(() {
      router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: AppRoutes.activity,
            builder: (_, _) => popper('back'),
          ),
        ],
      );
    });

    testWidgets('falls back to home when the screen is the stack root',
        (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // go() replaces the stack — this is the deep-link / notification case.
      router.go('/activity/abc');
      await tester.pumpAndSettle();
      expect(find.text('back'), findsOneWidget);

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      // Previously threw GoError: There is nothing to pop.
      expect(tester.takeException(), isNull);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('pops normally when there is a stack', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.push('/activity/abc');
      await tester.pumpAndSettle();
      expect(find.text('back'), findsOneWidget);

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
