import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

/// Whether the platform is asking for less motion.
///
/// Three flags, not one. iOS reports Reduce Motion as its own `reduceMotion`
/// accessibility feature; `MediaQuery.disableAnimations` carries only Android's
/// "Remove animations" and stays false on iOS however the setting is set.
/// Reading just the MediaQuery flag — the obvious choice — silently does
/// nothing on the platform this app ships to first.
///
/// Reading it through [MediaQuery.disableAnimationsOf] also registers a
/// dependency, so a widget that calls this rebuilds when the user changes the
/// setting with the app already open.
bool prefersReducedMotion(BuildContext context) {
  final features =
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
  return features.reduceMotion ||
      features.disableAnimations ||
      MediaQuery.disableAnimationsOf(context);
}

/// [duration], or [Duration.zero] when the platform asks for less motion.
///
/// For animations that cannot simply be dropped because they carry a layout
/// change — a cross-fade between two heights, a route swap. The end state still
/// arrives; it just arrives at once.
Duration motionDuration(BuildContext context, Duration duration) =>
    prefersReducedMotion(context) ? Duration.zero : duration;

/// A [Shimmer]-style sweep, or a still block when motion is reduced.
///
/// Loading skeletons are the one animation a user cannot escape by not
/// scrolling — they run for as long as the fetch takes, in the middle of the
/// screen. The still block keeps the skeleton's shape and its "not ready yet"
/// meaning without the travelling highlight.
class MotionSafeShimmer extends StatelessWidget {
  const MotionSafeShimmer({
    super.key,
    required this.baseColor,
    required this.highlightColor,
    required this.child,
  });

  final Color baseColor;
  final Color highlightColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      // Nothing wrapping the child: the skeleton's own boxes carry the shape,
      // and a static gradient sweep would just be a stripe.
      return child;
    }
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

/// Motion-aware entrance animations.
extension MotionSafeAnimate on Widget {
  /// `.animate()`, but held at its end state when motion is reduced.
  ///
  /// Entrance effects start a widget at zero opacity or off its resting
  /// offset, so they cannot simply be stopped — a stopped `fadeIn` is an
  /// invisible widget. `value: 1` with `autoPlay: false` pins the chain at
  /// completion instead: the widget is exactly where the animation would have
  /// left it, without ever having travelled.
  ///
  /// Use in place of `.animate()` for every entrance in the app; the effect
  /// chain that follows needs no changes.
  Animate animateSafely(BuildContext context) {
    final still = prefersReducedMotion(context);
    return animate(value: still ? 1.0 : null, autoPlay: !still);
  }
}
