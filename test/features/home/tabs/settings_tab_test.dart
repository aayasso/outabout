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
  late List<Uri> launched;
  late bool launchSucceeds;
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

    launched = [];
    launchSucceeds = true;
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
          urlLauncherProvider.overrideWithValue((Uri url) async {
            launched.add(url);
            return launchSucceeds;
          }),
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

  group('SettingsTab legal links', () {
    Future<void> tapRow(WidgetTester tester, String label) async {
      await pumpSettings(tester);
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('shows both legal rows', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets('privacy policy row opens the hosted URL', (tester) async {
      await tapRow(tester, 'Privacy Policy');

      // Apple reads the hosted copy, not the one in the repo.
      expect(launched, [Uri.parse(LegalUrls.privacyPolicy)]);
      expect(
        LegalUrls.privacyPolicy,
        'https://aayasso.github.io/outabout/privacy-policy.html',
      );
    });

    testWidgets('terms row opens the hosted URL', (tester) async {
      await tapRow(tester, 'Terms of Service');

      expect(launched, [Uri.parse(LegalUrls.termsOfService)]);
      expect(
        LegalUrls.termsOfService,
        'https://aayasso.github.io/outabout/terms-of-service.html',
      );
    });

    testWidgets('surfaces a message when the link cannot open',
        (tester) async {
      launchSucceeds = false;

      await tapRow(tester, 'Privacy Policy');

      expect(find.text('Could not open Privacy Policy.'), findsOneWidget);
    });

    testWidgets('rows carry a link semantics label', (tester) async {
      await pumpSettings(tester);
      final handle = tester.ensureSemantics();

      // The row's own Text merges into the node, so match on the part this
      // widget contributes rather than the whole merged string.
      expect(
        find.bySemanticsLabel(RegExp('Privacy Policy, opens in browser')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Terms of Service, opens in browser')),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
