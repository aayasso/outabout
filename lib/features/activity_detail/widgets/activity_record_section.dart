import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../data/models/activity_day_outcome.dart';
import '../../home/home_providers.dart';
import '../../outcomes/outcome_providers.dart';
import '../../outcomes/outcome_stats.dart';
import '../../../widgets/outcome_celebration.dart';

/// How much history the heat map shows.
///
/// Ten weeks is long enough for a seasonal habit to become visible and short
/// enough that every column still fits across a phone at large text sizes.
const int heatMapWeeks = 10;

/// The smallest a cell may get before the grid starts scrolling sideways.
///
/// Below this the cells stop reading as a calendar and start reading as noise,
/// and they fall under the tap target a pending day needs.
const double heatMapMinCellSize = 14.0;

/// Answers a still-answerable day and reports what the write changed.
///
/// Returns the milestone and refreshed stats rather than void, because the
/// sheet that calls it has to say something back. The write itself stays with
/// the screen — it owns the controller and the error handling — and only its
/// result travels down here.
typedef RetroAnswerHandler =
    Future<({OutcomeMilestone? milestone, OutcomeStats? stats})> Function(
      String localDate,
      String outcome,
    );

/// The activity's record: what it has amounted to, and when.
///
/// Sits above the edit form. The history is the reason to open this screen —
/// the form is what you do once you have seen it.
class ActivityRecordSection extends ConsumerWidget {
  const ActivityRecordSection({
    super.key,
    required this.activityId,
    required this.activityName,
    this.onAnswerDay,
  });

  final String activityId;
  final String activityName;

  /// Called when the user answers a still-answerable day from the grid.
  final RetroAnswerHandler? onAnswerDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = ref.watch(nowProvider)();
    final outcomesAsync = ref.watch(activityOutcomesProvider(activityId));

    return Container(
      margin: const EdgeInsets.only(bottom: OutAboutSpacing.lg),
      padding: const EdgeInsets.all(OutAboutSpacing.md),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(OutAboutRadius.cards),
        boxShadow: isDark ? OutAboutShadows.cardDark : OutAboutShadows.card,
      ),
      child: outcomesAsync.when(
        loading: () => _RecordShimmer(colors: colors),
        // A history that failed to load must not take the edit form down with
        // it — the user came here to change conditions at least as often as to
        // look back.
        error: (_, _) => _RecordUnavailable(colors: colors),
        data: (rows) => _RecordBody(
          rows: rows,
          now: now,
          colors: colors,
          activityName: activityName,
          onAnswerDay: onAnswerDay,
        ),
      ),
    );
  }
}

class _RecordBody extends StatelessWidget {
  const _RecordBody({
    required this.rows,
    required this.now,
    required this.colors,
    required this.activityName,
    required this.onAnswerDay,
  });

  final List<ActivityDayOutcome> rows;
  final DateTime now;
  final WeatherThemeColors colors;
  final String activityName;
  final RetroAnswerHandler? onAnswerDay;

  @override
  Widget build(BuildContext context) {
    final stats = computeOutcomeStats(rows, now: now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your record', style: OutAboutTypography.headingMedium(colors)),
        const SizedBox(height: OutAboutSpacing.md),
        _StatRow(stats: stats, colors: colors),
        const SizedBox(height: OutAboutSpacing.lg),
        HistoryHeatMap(
          rows: rows,
          now: now,
          colors: colors,
          activityName: activityName,
          onAnswerDay: onAnswerDay,
        ),
      ],
    );
  }
}

/// Completion rate, streaks and total, as a wrap so nothing clips.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats, required this.colors});

  final OutcomeStats stats;
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final rate = stats.completionRate;
    return Wrap(
      spacing: OutAboutSpacing.lg,
      runSpacing: OutAboutSpacing.md,
      children: [
        _Stat(
          // An em dash, not "0%". Nothing has been decided yet, and a zero
          // would be the app inventing a verdict it has no basis for.
          value: rate == null ? '—' : '${(rate * 100).round()}%',
          label: rate == null
              ? 'No days decided yet'
              : 'of ${stats.decidedDays} '
                    '${stats.decidedDays == 1 ? 'chance' : 'chances'} taken',
          semanticValue: rate == null
              ? 'No days decided yet'
              : '${(rate * 100).round()} percent of '
                    '${stats.decidedDays} chances taken',
          colors: colors,
          animateTo: rate == null ? null : (rate * 100).round(),
        ),
        _Stat(
          value: '${stats.currentStreak}',
          label: 'Current streak',
          semanticValue:
              'Current streak, ${stats.currentStreak} '
              '${stats.currentStreak == 1 ? 'day' : 'days'}',
          colors: colors,
          animateTo: stats.currentStreak,
          emphasised: true,
        ),
        _Stat(
          value: '${stats.bestStreak}',
          label: 'Best streak',
          semanticValue:
              'Best streak, ${stats.bestStreak} '
              '${stats.bestStreak == 1 ? 'day' : 'days'}',
          colors: colors,
          animateTo: stats.bestStreak,
        ),
        _Stat(
          value: '${stats.totalCompleted}',
          label: 'Times out',
          semanticValue:
              'Been out ${stats.totalCompleted} '
              '${stats.totalCompleted == 1 ? 'time' : 'times'}',
          colors: colors,
          animateTo: stats.totalCompleted,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.semanticValue,
    required this.colors,
    required this.animateTo,
    this.emphasised = false,
  });

  final String value;
  final String label;
  final String semanticValue;
  final WeatherThemeColors colors;

  /// Counted up to on first render. Null when there is no number to count.
  final int? animateTo;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final style = OutAboutTypography.displayMedium(
      colors,
    ).copyWith(color: emphasised ? colors.primaryInteractive : colors.text);

    return Semantics(
      label: semanticValue,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (animateTo == null)
            Text(value, style: style)
          else
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: animateTo),
              // Zero under Reduce Motion, so the final number is simply there.
              duration: motionDuration(
                context,
                OutAboutAnimations.standardDuration,
              ),
              curve: Curves.easeOutCubic,
              builder: (context, count, _) => Text(
                value.endsWith('%') ? '$count%' : '$count',
                style: style,
              ),
            ),
          Text(label, style: OutAboutTypography.labelSmall(colors)),
        ],
      ),
    );
  }
}

/// Ten weeks of days, one square each.
///
/// Columns are weeks, rows are weekdays — the shape people already read as a
/// calendar. Only days the app recorded as opportunities carry any colour;
/// everything else is deliberately blank, because a day that did not match is
/// not a day the user missed.
class HistoryHeatMap extends StatelessWidget {
  const HistoryHeatMap({
    super.key,
    required this.rows,
    required this.now,
    required this.colors,
    required this.activityName,
    this.onAnswerDay,
  });

  final List<ActivityDayOutcome> rows;
  final DateTime now;
  final WeatherThemeColors colors;
  final String activityName;
  final RetroAnswerHandler? onAnswerDay;

  @override
  Widget build(BuildContext context) {
    final states = {
      for (final cell in classifyOutcomeDays(rows, now: now))
        cell.localDate: cell.state,
    };
    final days = heatMapDays(now: now, weeks: heatMapWeeks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last $heatMapWeeks weeks',
          style: OutAboutTypography.labelMedium(colors),
        ),
        const SizedBox(height: OutAboutSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = OutAboutSpacing.xs;
            final available = constraints.maxWidth;
            final raw = (available - gap * (heatMapWeeks - 1)) / heatMapWeeks;
            final size = raw < heatMapMinCellSize ? heatMapMinCellSize : raw;

            final grid = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var week = 0; week < heatMapWeeks; week++) ...[
                  if (week > 0) const SizedBox(width: gap),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var weekday = 0; weekday < 7; weekday++) ...[
                        if (weekday > 0) const SizedBox(height: gap),
                        _cellAt(
                          context,
                          days: days,
                          states: states,
                          index: week * 7 + weekday,
                          size: size,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            );

            // Scrolls rather than shrinking below the minimum. At AX5 the
            // labels above grow but the grid keeps its shape, and a squashed
            // grid would be both unreadable and untappable.
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: grid,
            );
          },
        ),
        const SizedBox(height: OutAboutSpacing.sm),
        _HeatMapLegend(colors: colors),
      ],
    );
  }

  Widget _cellAt(
    BuildContext context, {
    required List<String> days,
    required Map<String, OutcomeDayState> states,
    required int index,
    required double size,
  }) {
    final date = days[index];
    final state = states[date] ?? OutcomeDayState.notMatched;
    return _HeatMapCell(
      localDate: date,
      state: state,
      size: size,
      index: index,
      colors: colors,
      activityName: activityName,
      onAnswer: state == OutcomeDayState.pending ? onAnswerDay : null,
    );
  }
}

/// The `heatMapWeeks * 7` local dates ending with today, oldest first.
///
/// Aligned so the last column ends on today's weekday, which is why the grid
/// reads as "recent" rather than "this calendar quarter". Built in the civil
/// date domain for the reason [daysBetweenIsoDates] documents.
List<String> heatMapDays({required DateTime now, required int weeks}) {
  final total = weeks * 7;
  final today = DateTime.utc(now.year, now.month, now.day);
  return [
    for (var offset = total - 1; offset >= 0; offset--)
      _isoOf(today.subtract(Duration(days: offset))),
  ];
}

String _isoOf(DateTime utcDay) {
  final month = utcDay.month.toString().padLeft(2, '0');
  final day = utcDay.day.toString().padLeft(2, '0');
  return '${utcDay.year}-$month-$day';
}

class _HeatMapCell extends StatelessWidget {
  const _HeatMapCell({
    required this.localDate,
    required this.state,
    required this.size,
    required this.index,
    required this.colors,
    required this.activityName,
    required this.onAnswer,
  });

  final String localDate;
  final OutcomeDayState state;
  final double size;
  final int index;
  final WeatherThemeColors colors;
  final String activityName;
  final RetroAnswerHandler? onAnswer;

  @override
  Widget build(BuildContext context) {
    final answerable = onAnswer != null;

    final cell = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: heatMapFill(state, colors),
        borderRadius: BorderRadius.circular(OutAboutRadius.sm / 2),
        border: heatMapNeedsOutline(state)
            ? Border.all(color: heatMapOutline(colors))
            : null,
      ),
    );

    return Semantics(
          label: heatMapCellLabel(
            localDate: localDate,
            state: state,
            activityName: activityName,
          ),
          button: answerable,
          excludeSemantics: true,
          onTap: answerable ? () => _answer(context) : null,
          child: GestureDetector(
            excludeFromSemantics: true,
            onTap: answerable ? () => _answer(context) : null,
            child: cell,
          ),
        )
        .animateSafely(context)
        // Cells settle in rather than appearing all at once. Capped so the
        // last cell of seventy is not still arriving a second later.
        .fadeIn(
          delay: Duration(milliseconds: (index * 6).clamp(0, 400)),
          duration: OutAboutAnimations.standardDuration,
        );
  }

  /// Opens the sheet, which now owns the answer from tap to acknowledgement.
  ///
  /// It used to pop a bare outcome string and let the caller do the write,
  /// which is why the retroactive path had no confirmation: by the time the
  /// result existed, the only thing that could have shown it was gone.
  void _answer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      // Not dismissible by dragging mid-write: the sheet is briefly showing
      // the outcome of something it is still doing.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OutAboutRadius.bottomSheet),
        ),
      ),
      builder: (sheetContext) => _RetroAnswerSheet(
        localDate: localDate,
        activityName: activityName,
        colors: colors,
        onAnswer: onAnswer!,
      ),
    );
  }
}

/// Answering a day that has not expired yet.
///
/// The prompt is a same-day affordance and an unanswered day counts against
/// the user once its grace window runs out. Without a way back in, that would
/// be a penalty with no recourse — this is what makes expiry fair.
///
/// The sheet performs the answer rather than popping a value for someone else
/// to act on. That is what lets it acknowledge the result: an answer from here
/// can cross a milestone exactly as an answer from the prompt can, and the
/// beat has to happen somewhere the user is still looking.
class _RetroAnswerSheet extends StatefulWidget {
  const _RetroAnswerSheet({
    required this.localDate,
    required this.activityName,
    required this.colors,
    required this.onAnswer,
  });

  final String localDate;
  final String activityName;
  final WeatherThemeColors colors;
  final RetroAnswerHandler onAnswer;

  @override
  State<_RetroAnswerSheet> createState() => _RetroAnswerSheetState();
}

class _RetroAnswerSheetState extends State<_RetroAnswerSheet> {
  /// The confirmation line, once there is one. Null while asking.
  String? _celebration;
  Timer? _close;

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  /// Yes: write, then say what it came to, then leave.
  ///
  /// Only a Yes gets a beat. `OutcomePrompt` makes the same call, and for the
  /// same reason — a congratulatory line after "I did not go" reads as
  /// sarcasm.
  Future<void> _onYes() async {
    OutAboutHaptics.onActivitySave();
    setState(() => _celebration = 'Logged.');

    // Caught here even though the handler already swallows its own failures.
    // "This sheet always closes" is the sheet's invariant to keep, not a
    // property to inherit from whoever supplied the callback: the close timer
    // is set *after* this await, so a throw escaping would strand the modal
    // open over the record with no control to dismiss it. A stuck sheet is a
    // far worse outcome than a missing streak line.
    OutcomeMilestone? milestone;
    OutcomeStats? stats;
    try {
      final result = await widget.onAnswer(widget.localDate, DayOutcome.done);
      milestone = result.milestone;
      stats = result.stats;
    } catch (e) {
      debugPrint('_RetroAnswerSheet: could not record the day — $e');
    }
    if (!mounted) return;

    // 'Logged.' is the honest fallback: the answer reached behavioral_events
    // regardless, and claiming a streak the app could not read back would be
    // worse than saying little.
    final line = celebrationLine(
      milestone: milestone,
      currentStreak: stats?.currentStreak ?? 0,
    );
    setState(() => _celebration = line);

    // VoiceOver gets the reaction too. Without this the sheet simply closes
    // and the answer appears to have done nothing.
    SemanticsService.sendAnnouncement(
      View.of(context),
      line,
      Directionality.of(context),
    );

    _close = Timer(outcomeCelebrationDuration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  /// No: recorded, and out of the way immediately.
  ///
  /// Popped first so the sheet does not sit there during the write. Nothing is
  /// waiting on the result — there is no line to show — and holding a modal
  /// open over a network round trip for an answer that needs no reply would be
  /// the app taking longer than the user did.
  void _onNo() {
    OutAboutHaptics.onConditionToggle();
    unawaited(_recordSkip());
    Navigator.of(context).pop();
  }

  /// The skip write, detached from the sheet that started it.
  ///
  /// Its own method so the failure has somewhere to be caught. An unawaited
  /// future that throws becomes an unhandled async error with no owner — the
  /// sheet is gone by then and cannot show anything — and in a test that is a
  /// failure attributed to whatever happens to run next.
  Future<void> _recordSkip() async {
    try {
      await widget.onAnswer(widget.localDate, DayOutcome.skipped);
    } catch (e) {
      debugPrint('_RetroAnswerSheet: could not record the skip — $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(OutAboutSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_celebration case final line?)
              OutcomeCelebration(text: line, colors: colors)
            else ...[
              Text(
                'Did you go on ${readableDate(widget.localDate)}?',
                style: OutAboutTypography.headingSmall(colors),
              ),
              const SizedBox(height: OutAboutSpacing.lg),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _onYes,
                child: const Text('Yes, I went'),
              ),
              const SizedBox(height: OutAboutSpacing.sm),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _onNo,
                child: const Text("No, I didn't"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeatMapLegend extends StatelessWidget {
  const _HeatMapLegend({required this.colors});

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Key: a filled square is a day you went, a muted square a day '
          'you did not, an outlined square a matched day with no answer.',
      excludeSemantics: true,
      child: Wrap(
        spacing: OutAboutSpacing.md,
        runSpacing: OutAboutSpacing.xs,
        children: [
          for (final entry in const [
            (OutcomeDayState.done, 'Went'),
            (OutcomeDayState.skipped, 'Did not'),
            (OutcomeDayState.pending, 'No answer'),
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: heatMapFill(entry.$1, colors),
                    borderRadius: BorderRadius.circular(2),
                    border: heatMapNeedsOutline(entry.$1)
                        ? Border.all(color: heatMapOutline(colors))
                        : null,
                  ),
                ),
                const SizedBox(width: OutAboutSpacing.xs),
                Text(entry.$2, style: OutAboutTypography.labelSmall(colors)),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cell presentation — top level so the tests can assert on it directly.
// ---------------------------------------------------------------------------

/// The fill for a cell in [state].
///
/// A day that did not match is barely drawn at all: it is not a gap in the
/// record, it is a day that was never on offer. Only `done` gets the theme's
/// accent weight, and `skipped` a muted wash, so a miss is legible without
/// being a reproach.
///
/// `done` uses `primaryInteractive`, not `primary`. A cell is a graphical
/// object read against the card it sits on, not a fill with ink on top, and
/// `primary` is only ever guaranteed to contrast with `onPrimary`: as a cell
/// it manages 2.0:1 on sunny and 2.8:1 on overcast, both short of the 3:1
/// WCAG asks for non-text. `primaryInteractive` is the token that carries
/// that guarantee — the contrast suite asserts it for every palette.
Color heatMapFill(OutcomeDayState state, WeatherThemeColors colors) {
  switch (state) {
    case OutcomeDayState.done:
      return colors.primaryInteractive;
    case OutcomeDayState.skipped:
      return colors.textSecondary.withValues(alpha: 0.35);
    case OutcomeDayState.pending:
    case OutcomeDayState.expired:
    case OutcomeDayState.future:
      return Colors.transparent;
    case OutcomeDayState.notMatched:
      return colors.divider.withValues(alpha: 0.25);
  }
}

/// Whether the cell needs a border to be visible at all.
bool heatMapNeedsOutline(OutcomeDayState state) =>
    state == OutcomeDayState.pending ||
    state == OutcomeDayState.expired ||
    state == OutcomeDayState.future;

/// The border for an unfilled cell.
///
/// Deliberately not `divider`, which is tuned for hairlines between rows and
/// manages only 1.1:1 against the card on the two dark palettes. An unanswered
/// day is drawn as outline alone, and it is the one cell the user may still
/// need to find and tap — invisible is the wrong outcome for the only state
/// that is still actionable.
Color heatMapOutline(WeatherThemeColors colors) =>
    colors.textSecondary.withValues(alpha: 0.6);

/// What VoiceOver says for one cell.
String heatMapCellLabel({
  required String localDate,
  required OutcomeDayState state,
  required String activityName,
}) {
  final date = readableDate(localDate);
  switch (state) {
    case OutcomeDayState.done:
      return '$date, conditions matched, you went';
    case OutcomeDayState.skipped:
      return '$date, conditions matched, you did not go';
    case OutcomeDayState.pending:
      return '$date, conditions matched, no answer yet. '
          'Tap to answer for $activityName.';
    case OutcomeDayState.expired:
      return '$date, conditions matched, never answered';
    case OutcomeDayState.future:
      return '$date, upcoming';
    case OutcomeDayState.notMatched:
      return '$date, no match';
  }
}

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// `'2026-08-23'` as `'Sunday 23 August'`.
///
/// Formatted here rather than through `intl`, which the project does not
/// depend on, and from the civil date rather than a DateTime the value does
/// not actually have.
String readableDate(String localDate) {
  final parts = localDate.split('-').map(int.parse).toList();
  final utc = DateTime.utc(parts[0], parts[1], parts[2]);
  return '${_weekdayNames[utc.weekday - 1]} ${parts[2]} '
      '${_monthNames[parts[1] - 1]}';
}

class _RecordShimmer extends StatelessWidget {
  const _RecordShimmer({required this.colors});
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return MotionSafeShimmer(
      baseColor: colors.divider,
      highlightColor: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 120, height: 20, color: colors.divider),
          const SizedBox(height: OutAboutSpacing.md),
          Container(width: double.infinity, height: 56, color: colors.divider),
          const SizedBox(height: OutAboutSpacing.md),
          Container(width: double.infinity, height: 96, color: colors.divider),
        ],
      ),
    );
  }
}

class _RecordUnavailable extends StatelessWidget {
  const _RecordUnavailable({required this.colors});
  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your record for this activity could not be loaded.',
      style: OutAboutTypography.bodySmall(colors),
    );
  }
}
