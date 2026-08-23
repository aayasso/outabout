import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:outabout/core/motion.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/activity_day_outcome.dart';
import 'package:outabout/features/activity_detail/widgets/activity_record_section.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/onboarding/widgets/progress_dots.dart';
import 'package:outabout/features/outcomes/outcome_providers.dart';

void main() {
  Widget host({required bool reduceMotion, required Widget child}) {
    return ProviderScope(
      overrides: [
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('prefersReducedMotion', () {
    testWidgets('follows the MediaQuery flag', (tester) async {
      late bool seen;
      await tester.pumpWidget(
        host(
          reduceMotion: true,
          child: Builder(
            builder: (context) {
              seen = prefersReducedMotion(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, isTrue);

      await tester.pumpWidget(
        host(
          reduceMotion: false,
          child: Builder(
            builder: (context) {
              seen = prefersReducedMotion(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, isFalse);
    });

    testWidgets('motionDuration collapses to zero', (tester) async {
      late Duration still;
      late Duration moving;
      await tester.pumpWidget(
        host(
          reduceMotion: true,
          child: Builder(
            builder: (context) {
              still = motionDuration(context, const Duration(seconds: 1));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        host(
          reduceMotion: false,
          child: Builder(
            builder: (context) {
              moving = motionDuration(context, const Duration(seconds: 1));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(still, Duration.zero);
      expect(moving, const Duration(seconds: 1));
    });
  });

  group('entrance animations', () {
    Widget subject(bool reduceMotion) => host(
      reduceMotion: reduceMotion,
      child: Builder(
        builder: (context) => const Text(
          'Hello',
        ).animateSafely(context).fadeIn(duration: const Duration(seconds: 1)),
      ),
    );

    // Scoped to the Text: MaterialApp puts its own FadeTransition on the
    // route, and it is already complete by the first frame.
    double opacityOf(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('Hello'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('are fully visible on the first frame when reduced', (
      tester,
    ) async {
      await tester.pumpWidget(subject(true));
      await tester.pump();

      // The honest response to Reduce Motion is the end state, not a faster
      // fade — a stopped fadeIn would leave the text invisible forever.
      expect(opacityOf(tester), 1.0);

      await tester.pumpAndSettle();
    });

    testWidgets('still animate when motion is allowed', (tester) async {
      await tester.pumpWidget(subject(false));
      await tester.pump();

      expect(
        opacityOf(tester),
        lessThan(1.0),
        reason: 'the entrance starts from transparent',
      );

      await tester.pumpAndSettle();
      expect(opacityOf(tester), 1.0, reason: 'and finishes opaque');
    });
  });

  group('the activity record', () {
    final rows = [
      for (final day in ['21', '22', '23'])
        ActivityDayOutcome(
          userId: 'u',
          activityId: 'act-1',
          localDate: '2026-08-$day',
          outcome: DayOutcome.done,
          answeredAt: DateTime.utc(2026, 8, int.parse(day), 18),
        ),
    ];

    Widget recordHost({required bool reduceMotion}) => ProviderScope(
      overrides: [
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
        nowProvider.overrideWithValue(() => DateTime(2026, 8, 23, 12)),
        activityOutcomesProvider('act-1').overrideWith((ref) async => rows),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: ActivityRecordSection(
                activityId: 'act-1',
                activityName: 'Morning trail run',
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('shows its final numbers on the first frame when reduced', (
      tester,
    ) async {
      await tester.pumpWidget(recordHost(reduceMotion: true));
      // Enough pumps to resolve the history, and not one more: the counters
      // must already be at their end value rather than counting up to it.
      await tester.pump();
      await tester.pump();

      expect(find.text('3'), findsNWidgets(3)); // streak, best, total
      expect(find.text('100%'), findsOneWidget);

      // Drained after the assertions, not before: flutter_animate leaves a
      // zero-duration timer even when it is pinned at its end state, and the
      // binding fails the test on a pending one.
      await tester.pumpAndSettle();
    });

    testWidgets('counts up when motion is allowed', (tester) async {
      await tester.pumpWidget(recordHost(reduceMotion: false));
      await tester.pump();
      await tester.pump();

      // Mid-tween, so the end value is not on screen yet.
      expect(find.text('100%'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('heat map cells are all present on the first frame when '
        'reduced', (tester) async {
      await tester.pumpWidget(recordHost(reduceMotion: true));
      await tester.pump();
      await tester.pump();

      // The staggered settle-in must not leave cells invisible for a user who
      // asked for less motion — animateSafely pins the chain at its end.
      expect(
        find.bySemanticsLabel(RegExp('conditions matched, you went')),
        findsNWidgets(3),
      );

      await tester.pumpAndSettle();
    });
  });

  group('MotionSafeShimmer', () {
    Widget subject(bool reduceMotion) => host(
      reduceMotion: reduceMotion,
      child: MotionSafeShimmer(
        baseColor: WeatherThemeColors.sunny.surface,
        highlightColor: WeatherThemeColors.sunny.divider,
        child: const SizedBox(width: 100, height: 20),
      ),
    );

    testWidgets('drops the sweep when motion is reduced', (tester) async {
      await tester.pumpWidget(subject(true));
      await tester.pump();

      // A loading skeleton runs for as long as the fetch takes, in the middle
      // of the screen. It is the one animation a user cannot escape.
      expect(find.byType(Shimmer), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('sweeps normally otherwise', (tester) async {
      await tester.pumpWidget(subject(false));
      await tester.pump();
      expect(find.byType(Shimmer), findsOneWidget);
    });
  });

  group('ProgressDots', () {
    testWidgets('announces the step and holds still when reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(reduceMotion: true, child: const ProgressDots(currentPage: 2)),
      );
      await tester.pump();
      final handle = tester.ensureSemantics();

      // Six unlabelled dots are the only sense of progress through
      // onboarding, and they said nothing at all to a screen reader.
      expect(find.bySemanticsLabel('Step 3 of 6'), findsOneWidget);

      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
            .duration,
        Duration.zero,
      );

      handle.dispose();
    });
  });
}
