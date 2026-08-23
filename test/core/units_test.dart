import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/core/units.dart';

void main() {
  group('celsiusToFahrenheit', () {
    test('converts and rounds', () {
      expect(celsiusToFahrenheit(0), 32);
      expect(celsiusToFahrenheit(100), 212);
      expect(celsiusToFahrenheit(22.2), 72);
      expect(celsiusToFahrenheit(12.8), 55);
    });

    test('rounds rather than truncates', () {
      // 21.6C is 70.88F.
      expect(celsiusToFahrenheit(21.6), 71);
    });

    test('handles below freezing', () {
      expect(celsiusToFahrenheit(-40), -40);
      expect(celsiusToFahrenheit(-10), 14);
    });
  });

  group('kmhToMph', () {
    test('converts and rounds', () {
      expect(kmhToMph(0), 0);
      expect(kmhToMph(100), 62);
      expect(kmhToMph(24), 15);
    });
  });

  group('weatherConditionName', () {
    test('names every code the schedule renders an icon for', () {
      const expected = {
        1000: 'Clear',
        1100: 'Mostly Clear',
        1101: 'Partly Cloudy',
        1102: 'Mostly Cloudy',
        1001: 'Cloudy',
        2000: 'Fog',
        2100: 'Light Fog',
        4000: 'Drizzle',
        4001: 'Rain',
        4200: 'Light Rain',
        4201: 'Heavy Rain',
        5000: 'Snow',
        5001: 'Flurries',
        5100: 'Light Snow',
        5101: 'Heavy Snow',
        6000: 'Freezing Drizzle',
        6001: 'Freezing Rain',
        6200: 'Light Freezing Rain',
        6201: 'Heavy Freezing Rain',
        7000: 'Ice Pellets',
        7101: 'Heavy Ice Pellets',
        7102: 'Light Ice Pellets',
        8000: 'Thunderstorm',
      };

      expected.forEach((code, name) {
        expect(weatherConditionName(code), name, reason: '$code');
      });
    });

    test('an unknown code falls back to Clear, matching the icon', () {
      // The schedule draws a sun for an unmapped code. Two different answers
      // for the same code would be worse than one imperfect one.
      expect(weatherConditionName(99999), 'Clear');
      expect(weatherConditionName(0), 'Clear');
    });

    test('no two adjacent severities share a name', () {
      // Light/Heavy pairs exist precisely so a user can tell them apart.
      expect(weatherConditionName(4200), isNot(weatherConditionName(4201)));
      expect(weatherConditionName(5100), isNot(weatherConditionName(5101)));
      expect(weatherConditionName(6200), isNot(weatherConditionName(6201)));
      expect(weatherConditionName(7101), isNot(weatherConditionName(7102)));
    });
  });
}
