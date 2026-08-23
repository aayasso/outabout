import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/condition_profile.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/tabs/settings_tab.dart';
import 'package:outabout/features/shared/condition_profile_form.dart';
import 'package:outabout/services/auth_service.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class _MockAuth extends Mock implements AuthService {}

class _MockEvents extends Mock implements BehavioralEventService {}

void main() {
  late SharedPreferences prefs;
  late _MockEvents events;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    events = _MockEvents();
    when(
      () => events.log(
        any(),
        extra: any(named: 'extra'),
        conditions: any(named: 'conditions'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget host(Widget child) => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          packageInfoProvider.overrideWith(
            (ref) async => PackageInfo(
              appName: 'OutAbout',
              packageName: 'com.outabout.outabout',
              version: '1.0.0',
              buildNumber: '1',
            ),
          ),
          weatherThemeProvider.overrideWith(
            (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
          ),
          weatherThemeColorsProvider.overrideWithValue(
            WeatherThemeColors.sunny,
          ),
          profileProvider.overrideWith((ref) async => null),
          userLocationProvider.overrideWith((ref) async => null),
          authServiceProvider.overrideWithValue(_MockAuth()),
          behavioralEventServiceProvider.overrideWithValue(events),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  /// Apple's HIG minimum. The project standard is 48dp, which satisfies it;
  /// this is the floor below which a control is a defect.
  const minimum = 44.0;

  group('theme override chips', () {
    testWidgets('every chip meets the minimum tap target', (tester) async {
      await tester.pumpWidget(host(const SettingsTab()));
      await tester.pumpAndSettle();

      // The visible pill is an 11pt label with 4pt of vertical padding —
      // about 24pt tall. The tap target is declared around it.
      for (final label in ['Adaptive', 'Sunny', 'Overcast', 'Night']) {
        final target = find
            .ancestor(
              of: find.text(label),
              matching: find.byType(ConstrainedBox),
            )
            .first;
        expect(
          tester.getSize(target).height,
          greaterThanOrEqualTo(minimum),
          reason: 'theme chip "$label"',
        );
      }
    });
  });

  // Measured at 48pt before any change was made; asserted so it stays that
  // way, not because it was ever a defect.
  group('precipitation segments', () {
    testWidgets('both segments meet the minimum tap target', (tester) async {
      await tester.pumpWidget(
        host(
          PrecipitationSection(
            colors: WeatherThemeColors.sunny,
            level: PrecipLevel.avoidRain,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['Avoid rain', 'Only when raining']) {
        final size = tester.getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first,
        );
        expect(
          size.height,
          greaterThanOrEqualTo(minimum),
          reason: 'segment "$label"',
        );
      }
    });
  });

  group('settings rows', () {
    testWidgets('tappable rows clear the minimum', (tester) async {
      await tester.pumpWidget(host(const SettingsTab()));
      await tester.pumpAndSettle();

      for (final label in [
        'Temperature unit',
        'Schedule layout',
        'Privacy Policy',
        'Terms of Service',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        final size = tester.getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first,
        );
        expect(
          size.height,
          greaterThanOrEqualTo(minimum),
          reason: 'settings row "$label"',
        );
      }
    });
  });
}
