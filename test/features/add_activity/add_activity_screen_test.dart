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
        categoriesProvider.overrideWith(
          (ref) async => [],
        ),
        ...overrides,
      ],
      child: const MaterialApp(
        home: AddActivityScreen(),
      ),
    );
  }

  Finder findNameField() =>
      find.widgetWithText(TextField, 'Activity name *');

  Finder findNotesField() =>
      find.widgetWithText(TextField, 'Notes (optional)');

  group('AddActivityScreen', () {
    testWidgets(
      'renders name field and Save button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Activity name *'), findsOneWidget);
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

        await tester.enterText(findNameField(), 'Hiking');
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

        // The shared ConditionSection collapses with an AnimatedCrossFade,
        // which keeps the hidden body in the tree but wraps it in
        // ExcludeSemantics and ExcludeFocus. So "hidden" is a question about
        // the semantics tree, not the widget tree.
        final handle = tester.ensureSemantics();
        Finder rangeSliderSemantics() => find.descendant(
              of: find.byType(RangeSlider),
              matching: find.byType(Semantics),
            );

        expect(find.byType(RangeSlider), findsOneWidget);
        expect(
          tester
              .widget<ExcludeSemantics>(
                find
                    .ancestor(
                      of: find.byType(RangeSlider),
                      matching: find.byType(ExcludeSemantics),
                    )
                    .first,
              )
              .excluding,
          isTrue,
          reason: 'a collapsed condition must not be reachable',
        );

        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(3));

        await tester.tap(switches.first);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<ExcludeSemantics>(
                find
                    .ancestor(
                      of: find.byType(RangeSlider),
                      matching: find.byType(ExcludeSemantics),
                    )
                    .first,
              )
              .excluding,
          isFalse,
          reason: 'an expanded condition must be reachable',
        );
        expect(rangeSliderSemantics(), findsWidgets);

        handle.dispose();
      },
    );

    // -- Form validation tests --

    testWidgets(
      'empty name disables save with no reason text',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNull);
        expect(
          find.text('Name is too long'),
          findsNothing,
        );
        expect(
          find.text('Notes exceed 200 characters'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'whitespace-only name disables save with no reason text',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(findNameField(), '   ');
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNull);
        expect(
          find.text('Name is too long'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'name over 50 chars shows inline error and reason text',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final longName = 'A' * 51;
        await tester.enterText(findNameField(), longName);
        await tester.pump();

        expect(
          find.text('Name must be 50 characters or less'),
          findsOneWidget,
        );
        expect(
          find.text('Name is too long'),
          findsOneWidget,
        );

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'notes at 201 chars shows error counter and reason text',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Enter a valid name first
        await tester.enterText(findNameField(), 'Hiking');
        await tester.pump();

        final longNotes = 'A' * 201;
        await tester.enterText(findNotesField(), longNotes);
        await tester.pump();

        expect(find.text('201 / 200'), findsOneWidget);
        expect(
          find.text('Notes exceed 200 characters'),
          findsOneWidget,
        );

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'valid name and notes enables save with no reason text',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(findNameField(), 'Hiking');
        await tester.pump();

        await tester.enterText(
          findNotesField(),
          'Some notes',
        );
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Save'),
        );
        expect(button.onPressed, isNotNull);
        expect(
          find.text('Name is too long'),
          findsNothing,
        );
        expect(
          find.text('Notes exceed 200 characters'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'empty notes field shows no counter',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('/ 200'), findsNothing);
      },
    );

    testWidgets(
      'non-empty notes field shows counter',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(findNotesField(), 'Hello');
        await tester.pump();

        expect(find.text('5 / 200'), findsOneWidget);
      },
    );
  });
}
