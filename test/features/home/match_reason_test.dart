import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/features/home/home_providers.dart';

DailyForecast _day({
  double max = 20,
  double min = 10,
  double precip = 0,
  double wind = 10,
}) => DailyForecast(
  date: DateTime(2026, 8, 23),
  temperatureMax: max,
  temperatureMin: min,
  precipitationProbability: precip,
  windSpeedMax: wind,
  weatherCode: 1000,
);

ConditionProfile _profile({
  bool tempEnabled = false,
  double? tempMin,
  double? tempMax,
  bool precipEnabled = false,
  String? precipLevel,
  bool windEnabled = false,
  double? windMax,
}) => ConditionProfile(
  id: 'p1',
  activityId: 'a1',
  tempEnabled: tempEnabled,
  tempMin: tempMin,
  tempMax: tempMax,
  precipEnabled: precipEnabled,
  precipLevel: precipLevel,
  windEnabled: windEnabled,
  windMax: windMax,
);

void main() {
  group('ConditionProfile.isConstraining', () {
    test('a profile with nothing enabled constrains nothing', () {
      expect(_profile().isConstraining, isFalse);
    });

    test('temperature enabled with no bounds constrains nothing', () {
      // evaluateDayMatch returns true here — both its guards are null-gated —
      // so without this distinction the app claimed a weather match for an
      // activity whose temperature range was never set.
      expect(_profile(tempEnabled: true).isConstraining, isFalse);
    });

    test('temperature enabled with either bound does constrain', () {
      expect(_profile(tempEnabled: true, tempMin: 5).isConstraining, isTrue);
      expect(_profile(tempEnabled: true, tempMax: 30).isConstraining, isTrue);
    });

    test('precipitation enabled always constrains', () {
      // Unlike the other two it has no bound to be missing: the level
      // defaults to avoid_rain when absent.
      expect(_profile(precipEnabled: true).isConstraining, isTrue);
    });

    test('wind enabled with no max constrains nothing', () {
      expect(_profile(windEnabled: true).isConstraining, isFalse);
    });

    test('wind enabled with a max does constrain', () {
      expect(_profile(windEnabled: true, windMax: 20).isConstraining, isTrue);
    });
  });

  group('evaluateDayMatch — unconstrained profiles still match', () {
    test('a null profile matches every day', () {
      // Deliberate: nothing can rule it out. The UI must show it without
      // calling it a weather match.
      expect(evaluateDayMatch(null, _day()), isTrue);
      expect(evaluateDayMatch(null, _day(max: -40, precip: 100)), isTrue);
    });

    test('an all-disabled profile matches every day', () {
      expect(evaluateDayMatch(_profile(), _day(max: 45, wind: 90)), isTrue);
    });
  });

  group('evaluateDayMatch — temperature boundaries', () {
    test('a day whose high exactly meets tempMin matches', () {
      expect(
        evaluateDayMatch(
          _profile(tempEnabled: true, tempMin: 20),
          _day(max: 20),
        ),
        isTrue,
      );
    });

    test('a day whose high is just under tempMin does not', () {
      expect(
        evaluateDayMatch(
          _profile(tempEnabled: true, tempMin: 20),
          _day(max: 19.9),
        ),
        isFalse,
      );
    });

    test('a day whose low exactly meets tempMax matches', () {
      expect(
        evaluateDayMatch(
          _profile(tempEnabled: true, tempMax: 10),
          _day(min: 10),
        ),
        isTrue,
      );
    });

    test('a day whose low is just over tempMax does not', () {
      expect(
        evaluateDayMatch(
          _profile(tempEnabled: true, tempMax: 10),
          _day(min: 10.1),
        ),
        isFalse,
      );
    });
  });

  group('evaluateDayMatch — precipitation is bidirectional', () {
    test('avoid_rain matches a dry day and rejects a wet one', () {
      final profile = _profile(
        precipEnabled: true,
        precipLevel: PrecipLevel.avoidRain,
      );
      expect(evaluateDayMatch(profile, _day(precip: 0)), isTrue);
      expect(evaluateDayMatch(profile, _day(precip: 90)), isFalse);
    });

    test('rain_only matches a wet day and rejects a dry one', () {
      final profile = _profile(
        precipEnabled: true,
        precipLevel: PrecipLevel.rainOnly,
      );
      expect(evaluateDayMatch(profile, _day(precip: 90)), isTrue);
      expect(evaluateDayMatch(profile, _day(precip: 0)), isFalse);
    });

    test('the dry threshold itself counts as dry', () {
      final avoid = _profile(
        precipEnabled: true,
        precipLevel: PrecipLevel.avoidRain,
      );
      expect(
        evaluateDayMatch(
          avoid,
          _day(precip: PrecipLevel.dryThreshold.toDouble()),
        ),
        isTrue,
      );
      expect(
        evaluateDayMatch(avoid, _day(precip: PrecipLevel.dryThreshold + 0.1)),
        isFalse,
      );
    });

    test('a null level behaves as avoid_rain, matching normalize', () {
      // precip_enabled true with no level is reachable: insertWithConditions
      // omits the column when the level is null. The matcher compares the raw
      // string, so this pins it to the same answer normalize gives.
      final profile = _profile(precipEnabled: true);
      expect(PrecipLevel.normalize(null), PrecipLevel.avoidRain);
      expect(evaluateDayMatch(profile, _day(precip: 0)), isTrue);
      expect(evaluateDayMatch(profile, _day(precip: 90)), isFalse);
    });

    test('a legacy level behaves as avoid_rain, matching normalize', () {
      // Rows written before the bidirectional migration hold 'none', 'light'
      // or 'any'. normalize() collapses them; the matcher must agree.
      for (final legacy in ['none', 'light', 'any']) {
        final profile = _profile(precipEnabled: true, precipLevel: legacy);
        expect(PrecipLevel.normalize(legacy), PrecipLevel.avoidRain);
        expect(
          evaluateDayMatch(profile, _day(precip: 90)),
          isFalse,
          reason: legacy,
        );
      }
    });
  });

  group('evaluateDayMatch — wind and conjunction', () {
    test('wind exactly at the max matches, just over does not', () {
      final profile = _profile(windEnabled: true, windMax: 30);
      expect(evaluateDayMatch(profile, _day(wind: 30)), isTrue);
      expect(evaluateDayMatch(profile, _day(wind: 30.1)), isFalse);
    });

    test('every enabled condition must pass, not just one', () {
      final profile = _profile(
        tempEnabled: true,
        tempMin: 15,
        precipEnabled: true,
        precipLevel: PrecipLevel.avoidRain,
        windEnabled: true,
        windMax: 20,
      );

      expect(
        evaluateDayMatch(profile, _day(max: 20, precip: 0, wind: 10)),
        isTrue,
      );
      // Each of these fails exactly one condition.
      expect(
        evaluateDayMatch(profile, _day(max: 10, precip: 0, wind: 10)),
        isFalse,
        reason: 'temperature',
      );
      expect(
        evaluateDayMatch(profile, _day(max: 20, precip: 90, wind: 10)),
        isFalse,
        reason: 'precipitation',
      );
      expect(
        evaluateDayMatch(profile, _day(max: 20, precip: 0, wind: 50)),
        isFalse,
        reason: 'wind',
      );
    });
  });
}
