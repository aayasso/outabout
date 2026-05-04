import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/add_activity/add_activity_screen.dart';
import 'package:outabout/features/home/home_providers.dart';

void main() {
  Widget buildTestWidget({
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(
          WeatherThemeColors.sunny,
        ),
        activitiesProvider.overrideWith(
          (ref) async => [],
        ),
        ...overrides,
      ],
      child: const MaterialApp(
        home: AddActivityScreen(),
      ),
    );
  }

  group('AddActivityScreen', () {
    testWidgets(
      'renders name field and Save button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Activity name'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
      },
    );

    testWidgets(
      'Save button is disabled when name is empty',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'Save button is enabled when name is entered',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Activity name'),
          'Hiking',
        );
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'condition toggles show/hide sliders',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Temperature section should not show slider initially
        expect(find.byType(RangeSlider), findsNothing);

        // Toggle temperature on
        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(4));

        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        // Now the RangeSlider should be visible
        expect(
          find.byType(RangeSlider),
          findsOneWidget,
        );
      },
    );
  });
}
