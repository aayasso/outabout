import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/activity.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/schedule_day.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/outcome_prompt_provider.dart';
import 'package:outabout/features/activity_detail/widgets/condition_suggestion_card.dart';
import 'package:outabout/features/home/tabs/schedule_tab.dart';
import 'package:outabout/features/onboarding/widgets/onboarding_button.dart';
import 'package:outabout/features/onboarding/widgets/progress_dots.dart';
import 'package:outabout/features/shared/condition_profile_form.dart';
import 'package:outabout/features/suggestions/condition_suggestion.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/widgets/outcome_prompt.dart';

class _MockEventService extends Mock implements BehavioralEventService {}

/// Every node in the rendered semantics tree, in traversal order.
///
/// `tester.getSemantics(finder)` returns the node nearest the widget, which
/// for a Switch or a Slider is the inner action node — the label and the
/// state sit on its parent. Walking the tree asks the question the way
/// VoiceOver does: is there *a* node that says this?
List<SemanticsData> _allSemantics(WidgetTester tester) {
  final out = <SemanticsData>[];
  void visit(SemanticsNode node) {
    out.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.binding.rootElement!.renderObject!.debugSemantics!);
  return out;
}

_MockEventService _silentEvents() {
  final mock = _MockEventService();
  when(
    () => mock.log(
      any(),
      extra: any(named: 'extra'),
      conditions: any(named: 'conditions'),
    ),
  ).thenAnswer((_) async {});
  return mock;
}

final _day = DateTime(2026, 8, 23, 21);

DailyForecast _forecast() => DailyForecast(
  date: DateTime(2026, 8, 23),
  temperatureMax: 24,
  temperatureMin: 12,
  precipitationProbability: 20,
  windSpeedMax: 10,
  weatherCode: 1000,
);

Activity _activity() =>
    const Activity(id: 'a1', userId: 'u1', name: 'Morning run');

/// The same activity, but with a condition that actually constrains a day.
Activity _constrainedActivity() => const Activity(
  id: 'a1',
  userId: 'u1',
  name: 'Morning run',
  conditionProfile: ConditionProfile(
    id: 'p1',
    activityId: 'a1',
    tempEnabled: true,
    tempMin: 5,
    tempMax: 30,
  ),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  List<Override> baseOverrides() => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    weatherThemeProvider.overrideWith(
      (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
    ),
    weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
    behavioralEventServiceProvider.overrideWithValue(_silentEvents()),
    categoriesProvider.overrideWith((ref) async => []),
    profileProvider.overrideWith((ref) async => null),
    nowProvider.overrideWithValue(() => _day),
  ];

  Widget scheduleHost({bool constrained = true}) {
    final activity = constrained ? _constrainedActivity() : _activity();
    return ProviderScope(
      overrides: [
        ...baseOverrides(),
        activitiesProvider.overrideWith((ref) async => [activity]),
        scheduleMatchProvider.overrideWith(
          (ref) => AsyncValue.data([
            ScheduleDay(forecast: _forecast(), matchedActivities: [activity]),
          ]),
        ),
      ],
      child: const MaterialApp(
        home: MediaQuery(
          // Stills the weather scene so pumpAndSettle can return.
          data: MediaQueryData(disableAnimations: true),
          child: ScheduleTab(),
        ),
      ),
    );
  }

  group('schedule activity card', () {
    testWidgets(
      'says "no weather conditions set" when nothing is constrained',
      (tester) async {
        await tester.pumpWidget(scheduleHost(constrained: false));
        await tester.pumpAndSettle();
        final handle = tester.ensureSemantics();

        // An activity with no conditions is shown on every day — nothing can
        // rule it out — but the app must not claim its weather matched.
        expect(
          find.bySemanticsLabel(
            RegExp('Activity: Morning run, no weather conditions set'),
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('conditions match')), findsNothing);

        handle.dispose();
      },
    );

    testWidgets('names the activity and the day its conditions match', (
      tester,
    ) async {
      await tester.pumpWidget(scheduleHost());
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      expect(
        find.bySemanticsLabel(
          RegExp('Activity: Morning run, conditions match Today'),
        ),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('the card is its own node, not the whole day section', (
      tester,
    ) async {
      await tester.pumpWidget(scheduleHost());
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      // The regression this guards. `Semantics(button: true)` without
      // `container: true` does not create a node — it annotates whichever
      // node the parent chain already provides. That was the sliver item
      // covering the entire day section, so VoiceOver announced one button
      // labelled with the day, the forecast, the activity name twice and
      // the outcome question twice: nine lines, one swipe stop.
      final cards = _allSemantics(
        tester,
      ).where((d) => d.label.startsWith('Activity: Morning run')).toList();
      expect(cards, hasLength(1));

      final label = cards.single.label;
      expect(
        label,
        isNot(contains('H:')),
        reason: 'the day forecast belongs to the header, not to the card',
      );
      expect(
        label,
        isNot(contains('Did you go')),
        reason: 'the outcome prompt is a separate control',
      );
      expect(
        'x${label}x'.split('Morning run').length - 1,
        1,
        reason: 'the activity name must be announced once',
      );

      // Every control inside the card keeps a node of its own. A tooltip
      // lands in SemanticsData.tooltip, not in the label; iOS composes the
      // two when it speaks the element.
      expect(find.byTooltip('Find & book'), findsOneWidget);
      expect(
        _allSemantics(
          tester,
        ).where((d) => '${d.label} ${d.tooltip}'.contains('Find & book')),
        isNotEmpty,
      );

      handle.dispose();
    });

    testWidgets(
      'the day header is a node of its own, and reads before the card',
      (tester) async {
        await tester.pumpWidget(scheduleHost());
        await tester.pumpAndSettle();
        final handle = tester.ensureSemantics();

        final all = _allSemantics(tester);
        final headerIndex = all.indexWhere((d) => d.flagsCollection.isHeader);
        final cardIndex = all.indexWhere(
          (d) => d.label.startsWith('Activity: Morning run'),
        );

        expect(headerIndex, isNonNegative, reason: 'the day needs a header');
        expect(
          headerIndex,
          lessThan(cardIndex),
          reason: 'the day is announced before the activities under it',
        );
        expect(all[headerIndex].label, contains('Today'));
        // The icon tints sit at 1.7-2.8:1, so the numbers carry their own
        // names rather than leaning on the glyph beside them.
        expect(all[headerIndex].label, contains('Chance of precipitation'));
        expect(all[headerIndex].label, contains('Wind up to'));

        handle.dispose();
      },
    );
  });

  group('outcome prompt', () {
    Widget promptHost() => ProviderScope(
      overrides: [
        ...baseOverrides(),
        outcomePromptProvider.overrideWith(
          (ref) => OutcomePromptNotifier(prefs, () => _day),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OutcomePrompt(
            activityId: 'a1',
            activityName: 'Morning run',
            matchedDay: DateTime(2026, 8, 23),
            matchIsConstrained: true,
            forecastDay: _forecast(),
          ),
        ),
      ),
    );

    testWidgets('each answer names the activity it answers for', (
      tester,
    ) async {
      await tester.pumpWidget(promptHost());
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      // A bare "Yes" on its own node says nothing about what is being
      // answered, which is all a screen reader gets once the chips are
      // individually focusable.
      expect(
        find.bySemanticsLabel('Yes, I went to Morning run'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('No, I did not go to Morning run'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('chips and dismiss meet the 44pt minimum', (tester) async {
      await tester.pumpWidget(promptHost());
      await tester.pumpAndSettle();

      for (final label in ['Yes', 'Not today']) {
        final size = tester.getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        );
        expect(size.height, greaterThanOrEqualTo(44.0), reason: label);
        expect(size.width, greaterThanOrEqualTo(44.0), reason: label);
      }

      final dismiss = tester.getSize(find.byTooltip(RegExp('^Dismiss')));
      expect(dismiss.height, greaterThanOrEqualTo(44.0));
      expect(dismiss.width, greaterThanOrEqualTo(44.0));
    });
  });

  group('condition suggestion card', () {
    const suggestion = (
      dimension: SuggestionDimension.windMax,
      currentValue: 25.0,
      suggestedValue: 20.0,
      qualifyingSkips: 3,
      eligibleDays: 9,
    );

    Widget suggestionHost() => ProviderScope(
      overrides: baseOverrides(),
      child: MaterialApp(
        home: Scaffold(
          body: ConditionSuggestionCard(
            activityId: 'a1',
            activityName: 'Morning run',
            suggestion: suggestion,
            temperatureUnit: 'C',
            onAccept: (_) async {},
            onDecline: (_) async {},
          ),
        ),
      ),
    );

    testWidgets('is one node that names the activity and the change', (
      tester,
    ) async {
      // The card proposes editing a setting. A screen reader user who hears
      // only "You've skipped 3 of your windiest matches" has no idea which
      // activity is about to change, and the two buttons below it say even
      // less on their own.
      await tester.pumpWidget(suggestionHost());
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      final cards = _allSemantics(
        tester,
      ).where((d) => d.label.startsWith('Suggestion for Morning run')).toList();
      expect(cards, hasLength(1));
      expect(cards.single.label, contains('Lower the wind limit to 20 km/h'));

      handle.dispose();
    });

    testWidgets('the two actions are distinct, labelled buttons', (
      tester,
    ) async {
      await tester.pumpWidget(suggestionHost());
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      final buttons = _allSemantics(tester)
          .where((d) => d.flagsCollection.isButton)
          .map((d) => d.label)
          .toList();
      expect(buttons, contains('Apply'));
      expect(buttons, contains('Not for me'));

      handle.dispose();
    });

    testWidgets('the sentence is not announced twice', (tester) async {
      // The container carries it as its label, so the Text beneath must not
      // also be its own node.
      await tester.pumpWidget(suggestionHost());
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      final echoes = _allSemantics(
        tester,
      ).where((d) => d.label.startsWith("You've skipped 3")).toList();
      expect(echoes, isEmpty);

      handle.dispose();
    });

    testWidgets('both actions meet the 44pt minimum', (tester) async {
      await tester.pumpWidget(suggestionHost());
      await tester.pumpAndSettle();

      // Measured on the buttons themselves: the 48pt floor comes from their
      // `minimumSize` style, so there is no wrapping SizedBox to look at.
      for (final finder in [
        find.widgetWithText(ElevatedButton, 'Apply'),
        find.widgetWithText(TextButton, 'Not for me'),
      ]) {
        final size = tester.getSize(finder);
        expect(size.height, greaterThanOrEqualTo(44.0));
        expect(size.width, greaterThanOrEqualTo(44.0));
      }
    });
  });

  group('condition form', () {
    testWidgets('the switch carries its state as a flag, not as text', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: ConditionSection(
                title: 'Temperature',
                icon: Icons.thermostat,
                enabled: true,
                onToggled: (_) {},
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      final toggles = _allSemantics(
        tester,
      ).where((d) => d.flagsCollection.isToggled != Tristate.none);
      expect(toggles, isNotEmpty, reason: 'the switch must expose its state');
      final labelled = toggles
          .where((d) => d.label.contains('Temperature'))
          .toList();
      expect(labelled, isNotEmpty);
      expect(
        labelled.every((d) => d.flagsCollection.isToggled == Tristate.isTrue),
        isTrue,
      );
      // The label is the condition, nothing else. Spelling the control type
      // into it ("Temperature condition toggle") makes VoiceOver say
      // "toggle" twice — once from the label, once from the switch trait it
      // announces in the user's own language.
      expect(
        labelled.every((d) => !d.label.toLowerCase().contains('toggle')),
        isTrue,
        reason: 'the control type comes from the trait, not the label',
      );

      handle.dispose();
    });

    testWidgets('sliders announce the unit shown on screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: TemperatureSection(
                colors: WeatherThemeColors.sunny,
                min: 10,
                max: 30,
                // Fahrenheit on screen; Celsius in the model.
                temperatureUnit: 'F',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      final sliders = _allSemantics(
        tester,
      ).where((d) => d.flagsCollection.isSlider).toList();
      expect(sliders, hasLength(2), reason: 'a range slider has two thumbs');

      // 10 °C is 50 °F and 30 °C is 86 °F. Announcing the stored "10" and
      // "30" is the bug this guards.
      expect(sliders.map((d) => d.value), containsAll(['50 °F', '86 °F']));

      handle.dispose();
    });

    testWidgets('the precipitation picker is a named group', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: PrecipitationSection(
                colors: WeatherThemeColors.sunny,
                level: PrecipLevel.avoidRain,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      expect(find.bySemanticsLabel('Precipitation preference'), findsOneWidget);
      // Both options must stay individually selectable inside the group.
      expect(find.text('Avoid rain'), findsOneWidget);
      expect(find.text('Only when raining'), findsOneWidget);

      handle.dispose();
    });
  });

  // On-device traversal of onboarding needs a signed-out session; these
  // assert the same semantics tree iOS turns into VoiceOver elements.
  group('onboarding', () {
    Widget onboardingHost(Widget child) => ProviderScope(
      overrides: baseOverrides(),
      child: MaterialApp(home: Scaffold(body: child)),
    );

    testWidgets('progress dots say where you are', (tester) async {
      await tester.pumpWidget(
        onboardingHost(const ProgressDots(currentPage: 0)),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      expect(find.bySemanticsLabel('Step 1 of 6'), findsOneWidget);
      // The dots themselves are decoration; six unlabelled stops would be
      // six swipes that say nothing.
      expect(_allSemantics(tester).where((d) => d.label == ''), isNotEmpty);

      handle.dispose();
    });

    testWidgets('the CTA reports its disabled state', (tester) async {
      await tester.pumpWidget(
        onboardingHost(
          const OnboardingButton(label: 'Get Started', onPressed: null),
        ),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      final cta = _allSemantics(
        tester,
      ).where((d) => d.label.contains('Get Started')).toList();
      expect(cta, isNotEmpty);
      expect(
        cta.any((d) => d.flagsCollection.isEnabled == Tristate.isFalse),
        isTrue,
        reason: 'a dimmed CTA must announce that it is dimmed',
      );

      handle.dispose();
    });
  });
}
