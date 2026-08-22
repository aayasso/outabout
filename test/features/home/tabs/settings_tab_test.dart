import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/features/home/tabs/settings_tab.dart';
import 'package:outabout/services/auth_service.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

void main() {
  late MockAuthService mockAuthService;
  late MockBehavioralEventService mockEventService;
  late SharedPreferences prefs;

  setUp(() async {
    mockAuthService = MockAuthService();
    mockEventService = MockBehavioralEventService();
    when(() => mockEventService.log(any(), extra: any(named: 'extra')))
        .thenAnswer((_) async {});

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
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
          authServiceProvider.overrideWithValue(mockAuthService),
          behavioralEventServiceProvider.overrideWithValue(mockEventService),
        ],
        child: const MaterialApp(home: SettingsTab()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await pumpSettings(tester);
    // The Account section sits below the fold in the default test viewport.
    await tester.ensureVisible(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
  }

  /// The confirm button inside the dialog (the row label shares its text).
  Finder confirmButton() => find.widgetWithText(TextButton, 'Delete Account');

  bool isEnabled(WidgetTester tester) =>
      tester.widget<TextButton>(confirmButton()).onPressed != null;

  group('SettingsTab delete account', () {
    testWidgets('Account section offers a delete row', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('dialog explains permanence and asks for confirmation',
        (tester) async {
      await openDeleteDialog(tester);

      expect(find.text('Delete account?'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(find.text('Type DELETE to confirm.'), findsOneWidget);
    });

    testWidgets('confirm is disabled until DELETE is typed exactly',
        (tester) async {
      await openDeleteDialog(tester);

      expect(isEnabled(tester), isFalse, reason: 'disabled when empty');

      // Wrong case must not enable it.
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pumpAndSettle();
      expect(isEnabled(tester), isFalse, reason: 'lowercase rejected');

      // Neither may a trailing space — the match is exact, not trimmed.
      await tester.enterText(find.byType(TextField), 'DELETE ');
      await tester.pumpAndSettle();
      expect(isEnabled(tester), isFalse, reason: 'trailing space rejected');

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      expect(isEnabled(tester), isTrue, reason: 'exact match enables');
    });

    testWidgets('a disabled confirm cannot trigger deletion', (tester) async {
      await openDeleteDialog(tester);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      verifyNever(() => mockAuthService.deleteAccount());
    });

    testWidgets('cancel closes without deleting', (tester) async {
      await openDeleteDialog(tester);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete account?'), findsNothing);
      verifyNever(() => mockAuthService.deleteAccount());
    });

    testWidgets('failure keeps the dialog open and shows the message',
        (tester) async {
      when(() => mockAuthService.deleteAccount()).thenAnswer(
        (_) async => AuthResult.failure('Could not delete. Try again.'),
      );

      await openDeleteDialog(tester);
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      expect(find.text('Delete account?'), findsOneWidget);
      expect(find.text('Could not delete. Try again.'), findsOneWidget);
      verify(() => mockAuthService.deleteAccount()).called(1);
    });

    testWidgets('logs account_deletion_requested before deleting',
        (tester) async {
      when(() => mockAuthService.deleteAccount()).thenAnswer(
        (_) async => AuthResult.failure('nope'),
      );

      await openDeleteDialog(tester);
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();

      verifyInOrder([
        () => mockEventService.log('account_deletion_requested'),
        () => mockAuthService.deleteAccount(),
      ]);
    });
  });
}
