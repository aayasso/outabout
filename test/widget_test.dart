import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/main.dart';

void main() {
  testWidgets('OutAboutApp renders onboarding placeholder by default',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const OutAboutApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Value Proposition'), findsOneWidget);
  });

  testWidgets('OutAboutApp renders home when onboarding is complete',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const OutAboutApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to OutAbout'), findsOneWidget);
  });

  testWidgets('OutAboutApp uses MaterialApp.router', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const OutAboutApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify MaterialApp is present (MaterialApp.router creates a MaterialApp)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
