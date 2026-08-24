import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion.dart';
import '../../../core/theme.dart';
import '../../../core/units.dart';
import '../../../core/weather_theme_provider.dart';
import '../../suggestions/condition_suggestion.dart';
import '../../suggestions/suggestion_providers.dart';

/// What the card says, as one sentence.
///
/// Two clauses, always in this order: the observation, then the offer. The
/// observation has to come first because it is the permission — an app that
/// proposes changing a setting without saying why is guessing out loud, and
/// the user has no way to judge whether to trust it.
///
/// Public so the wording is asserted directly. It is the part of this feature
/// a user actually experiences, and it makes a factual claim about their own
/// behaviour that has to stay true to what the rule measured.
String suggestionSentence(
  ConditionSuggestion suggestion,
  String temperatureUnit,
) {
  final skips = suggestion.qualifyingSkips;
  final target = _formatValue(
    suggestion.dimension,
    suggestion.suggestedValue,
    temperatureUnit,
  );

  return switch (suggestion.dimension) {
    SuggestionDimension.windMax =>
      "You've skipped $skips of your windiest matches. "
          'Lower the wind limit to $target?',
    SuggestionDimension.tempMax =>
      "You've skipped $skips of your warmest matches. "
          'Lower the top of the range to $target?',
    SuggestionDimension.tempMin =>
      "You've skipped $skips of your coldest matches. "
          'Raise the bottom of the range to $target?',
  };
}

/// A stored value in the units the rest of this screen is already using.
///
/// `profiles.temperature_unit` governs both scales, matching
/// [WindSection] and [TemperatureSection]: a profile set to Fahrenheit shows
/// wind in mph. Suggesting "20 km/h" to someone whose slider reads "12 mph"
/// would be an instruction they cannot follow.
String _formatValue(
  SuggestionDimension dimension,
  double value,
  String temperatureUnit,
) {
  final imperial = temperatureUnit == 'F';
  return switch (dimension) {
    SuggestionDimension.windMax =>
      imperial ? '${kmhToMph(value)} mph' : '${value.round()} km/h',
    SuggestionDimension.tempMax || SuggestionDimension.tempMin =>
      imperial ? '${celsiusToFahrenheit(value)}°F' : '${value.round()}°C',
  };
}

/// A quiet offer to tighten one condition, sitting under the record it was
/// inferred from.
///
/// Deliberately not styled as a peer of the record card: no shadow, a hairline
/// border, the flat surface colour. It is an annotation on the history above
/// it, and a card with the same weight would read as a second, competing
/// subject on a screen that already has two.
///
/// Mounted only when there is something to say, so it has no empty state. The
/// parent owns accept and decline — accepting has to move the slider further
/// down this same screen, and only the screen's own state can do that.
class ConditionSuggestionCard extends ConsumerStatefulWidget {
  const ConditionSuggestionCard({
    super.key,
    required this.activityId,
    required this.activityName,
    required this.suggestion,
    required this.temperatureUnit,
    required this.onAccept,
    required this.onDecline,
  });

  final String activityId;
  final String activityName;
  final ConditionSuggestion suggestion;
  final String temperatureUnit;

  /// Applies the change. Allowed to throw — the card shows the failure.
  final Future<void> Function(ConditionSuggestion) onAccept;

  final Future<void> Function(ConditionSuggestion) onDecline;

  @override
  ConsumerState<ConditionSuggestionCard> createState() =>
      _ConditionSuggestionCardState();
}

class _ConditionSuggestionCardState
    extends ConsumerState<ConditionSuggestionCard> {
  bool _isApplying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _logShown();
  }

  @override
  void didUpdateWidget(ConditionSuggestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different offer is a different impression. The same one re-rendering
    // is not, and the controller drops it.
    if (oldWidget.suggestion != widget.suggestion) _logShown();
  }

  /// Deferred, because this runs during a build and logging synchronously
  /// would mutate providers mid-build — the same reason `activity_viewed`
  /// defers on this screen.
  void _logShown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(suggestionControllerProvider)
          .markShown(widget.activityId, widget.suggestion);
    });
  }

  Future<void> _accept() async {
    OutAboutHaptics.onActivitySave();
    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });
    try {
      await widget.onAccept(widget.suggestion);
    } catch (e) {
      // Unlike a history write, this is the thing the user asked for. Silence
      // would leave them believing a limit had moved when it had not.
      if (!mounted) return;
      setState(() {
        _isApplying = false;
        _errorMessage = 'Could not apply that change. Please try again.';
      });
      return;
    }
    // No success state and no confirmation line: the card is unmounted by the
    // rebuild that follows, and the slider below now reads the new number.
    // The change showing itself is a better acknowledgement than a sentence
    // saying it happened.
    if (mounted) setState(() => _isApplying = false);
  }

  Future<void> _decline() async {
    OutAboutHaptics.onConditionToggle();
    await widget.onDecline(widget.suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final sentence = suggestionSentence(
      widget.suggestion,
      widget.temperatureUnit,
    );

    return Semantics(
      container: true,
      label: 'Suggestion for ${widget.activityName}. $sentence',
      child: Container(
        margin: const EdgeInsets.only(bottom: OutAboutSpacing.lg),
        padding: const EdgeInsets.all(OutAboutSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(OutAboutRadius.cards),
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: colors.primaryInteractive,
                  ),
                ),
                const SizedBox(width: OutAboutSpacing.sm),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      sentence,
                      style: OutAboutTypography.bodyMedium(colors),
                    ),
                  ),
                ),
              ],
            ),
            if (_errorMessage case final message?) ...[
              const SizedBox(height: OutAboutSpacing.sm),
              Text(
                message,
                style: OutAboutTypography.bodySmall(
                  colors,
                ).copyWith(color: OutAboutColors.errorColor),
              ),
            ],
            const SizedBox(height: OutAboutSpacing.md),
            // Wrap rather than Row: at large text scales two 48pt buttons and
            // their labels no longer fit one line, and a Row would overflow.
            Wrap(
              spacing: OutAboutSpacing.sm,
              runSpacing: OutAboutSpacing.xs,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                  ),
                  onPressed: _isApplying ? null : _accept,
                  child: Text(_isApplying ? 'Applying…' : 'Apply'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(88, 48),
                    foregroundColor: colors.textSecondary,
                  ),
                  onPressed: _isApplying ? null : _decline,
                  child: const Text('Not for me'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animateSafely(context).fadeIn(duration: OutAboutAnimations.standardDuration);
  }
}
