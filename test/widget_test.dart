import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/main.dart';

void main() {
  testWidgets('OutAboutApp renders design system preview', (tester) async {
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

    expect(find.text('OutAbout'), findsOneWidget);
    expect(find.text('Ready to build.'), findsOneWidget);
    expect(find.text('Get Outside'), findsOneWidget);
  });

  testWidgets('theme switcher buttons are present for all 5 themes', (tester) async {
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

    expect(find.text('Sunny'), findsOneWidget);
    expect(find.text('Overcast'), findsOneWidget);
    expect(find.text('Rainy'), findsOneWidget);
    expect(find.text('Snowy'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);
  });
}
