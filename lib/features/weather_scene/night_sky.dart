import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Star field and moon for the night scene.
///
/// The `weather_animation` package has no star or moon widget, and its sun is a
/// corner arc that does not read as a moon. This paints both directly.
///
/// Deliberately static — no controller, no ticker — so it is safe under Reduce
/// Motion by construction rather than by being switched off. Star positions come
/// from a fixed seed, so the sky is identical on every build and in every test.
class NightSky extends StatelessWidget {
  const NightSky({super.key, required this.colors});

  final WeatherThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _NightSkyPainter(
        starColor: colors.text,
        moonColor: colors.textSecondary,
        haloColor: colors.primary,
      ),
    );
  }
}

class _NightSkyPainter extends CustomPainter {
  const _NightSkyPainter({
    required this.starColor,
    required this.moonColor,
    required this.haloColor,
  });

  final Color starColor;
  final Color moonColor;
  final Color haloColor;

  static const int _starCount = 54;
  static const int _seed = 20260822;

  @override
  void paint(Canvas canvas, Size size) {
    _paintStars(canvas, size);
    _paintMoon(canvas, size);
  }

  void _paintStars(Canvas canvas, Size size) {
    final random = math.Random(_seed);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < _starCount; i++) {
      final dx = random.nextDouble() * size.width;
      // Weighted toward the top: the day list covers the lower half.
      final dy = random.nextDouble() * random.nextDouble() * size.height;
      final radius = 0.6 + random.nextDouble() * 1.3;
      final alpha = 0.25 + random.nextDouble() * 0.45;

      paint.color = starColor.withValues(alpha: alpha);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  void _paintMoon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.80, size.height * 0.055);
    final radius = size.width * 0.055;

    canvas.drawCircle(
      center,
      radius * 2.1,
      Paint()
        ..color = haloColor.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = moonColor.withValues(alpha: 0.85),
    );
    // Bite out a crescent by overdrawing an offset disc in the sky colour's
    // absence — a soft shadow disc reads as a gibbous moon without needing a
    // background-coloured cutout that would punch through the scene.
    canvas.drawCircle(
      center.translate(radius * 0.55, -radius * 0.35),
      radius * 0.92,
      Paint()..color = moonColor.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(_NightSkyPainter oldDelegate) =>
      oldDelegate.starColor != starColor ||
      oldDelegate.moonColor != moonColor ||
      oldDelegate.haloColor != haloColor;
}
