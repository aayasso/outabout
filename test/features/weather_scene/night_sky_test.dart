import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/features/weather_scene/night_sky.dart';

void main() {
  group('moonGeometry', () {
    test('clears the top inset on notched devices', () {
      final g = moonGeometry(
        const Size(440, 956),
        topInset: 62,
      );
      expect(
        g.center.dy - g.radius,
        greaterThanOrEqualTo(62),
        reason: 'Moon top edge must clear '
            'the 62dp top inset',
      );
    });

    test('preserves original position with no inset', () {
      final g = moonGeometry(
        const Size(440, 956),
        topInset: 0,
      );
      expect(
        g.center.dy,
        closeTo(956 * 0.055, 0.1),
        reason: 'With topInset 0, moon must not '
            'shift from original position',
      );
    });

    test('clears a large inset on iPad-like size', () {
      final g = moonGeometry(
        const Size(834, 1194),
        topInset: 24,
      );
      expect(
        g.center.dy - g.radius,
        greaterThanOrEqualTo(24),
      );
    });
  });
}
