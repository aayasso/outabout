import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/home/home_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets(
      'renders 3 NavigationBar destinations',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, shell) =>
                  HomeScreen(navigationShell: shell),
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (context, state) =>
                          const Scaffold(
                        body: Text('Today'),
                      ),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/activities',
                      builder: (context, state) =>
                          const Scaffold(
                        body: Text('Activities'),
                      ),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/settings',
                      builder: (context, state) =>
                          const Scaffold(
                        body: Text('Settings'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              weatherThemeProvider.overrideWith(
                (ref) => WeatherThemeNotifier(
                  WeatherTheme.sunny,
                ),
              ),
              weatherThemeColorsProvider.overrideWithValue(
                WeatherThemeColors.sunny,
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byType(NavigationDestination),
          findsNWidgets(3),
        );
        // Was find.text('Today') — which matched only the stub route this
        // test declares, not anything HomeScreen renders. The real label is
        // 'Schedule'.
        expect(find.text('Schedule'), findsOneWidget);
        expect(find.text('Activities'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      },
    );
  });
}
