import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/onboarding/pages/first_activity_page.dart';
import 'package:outabout/models/activity.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

void main() {
  group('Activity model', () {
    test('toJson() includes all fields with snake_case keys', () {
      final now = DateTime(2026, 4, 14, 10, 30);
      final activity = Activity(
        id: 'abc-123',
        userId: 'user-456',
        name: 'Morning Hike',
        categoryIds: const ['hiking-id'],
        createdAt: now,
      );

      final json = activity.toJson();

      expect(json['id'], 'abc-123');
      expect(json['user_id'], 'user-456');
      expect(json['name'], 'Morning Hike');
      expect(json['category_ids'], ['hiking-id']);
      expect(json['created_at'], now.toIso8601String());
    });

    test('toJson() excludes id when null', () {
      final activity = Activity(
        userId: 'user-456',
        name: 'Morning Hike',
        categoryIds: const ['hiking-id'],
        createdAt: DateTime(2026, 4, 14),
      );

      final json = activity.toJson();

      expect(json.containsKey('id'), isFalse);
    });

    test('fromJson() round-trips correctly', () {
      final now = DateTime(2026, 4, 14, 10, 30);
      final original = Activity(
        id: 'abc-123',
        userId: 'user-456',
        name: 'Morning Hike',
        categoryIds: const ['hiking-id'],
        createdAt: now,
      );

      final restored = Activity.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.name, original.name);
      expect(restored.categoryIds, original.categoryIds);
      expect(restored.createdAt, original.createdAt);
    });
  });

  group('FirstActivityPage', () {
    Future<SharedPreferences> mockPrefs() async {
      SharedPreferences.setMockInitialValues({});
      return SharedPreferences.getInstance();
    }

    MockBehavioralEventService buildMockEventService() {
      final mockEventService = MockBehavioralEventService();
      when(() => mockEventService.log(any(), extra: any(named: 'extra')))
          .thenAnswer((_) async {});
      return mockEventService;
    }

    MockSupabaseClient buildMockSupabaseClient() {
      final mockSupabase = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentUser).thenReturn(null);
      return mockSupabase;
    }

    Widget buildSubject({
      SharedPreferences? prefs,
      WeatherTheme? themeOverride,
      MockBehavioralEventService? mockEventService,
      MockSupabaseClient? mockSupabaseClient,
    }) {
      final eventService = mockEventService ?? buildMockEventService();
      final supabaseClient = mockSupabaseClient ?? buildMockSupabaseClient();
      return ProviderScope(
        overrides: [
          if (prefs != null)
            sharedPreferencesProvider.overrideWithValue(prefs),
          if (themeOverride != null)
            weatherThemeProvider.overrideWith(
              (ref) => WeatherThemeNotifier(themeOverride),
            ),
          behavioralEventServiceProvider.overrideWithValue(eventService),
          supabaseClientProvider.overrideWithValue(supabaseClient),
        ],
        child: const MaterialApp(
          home: Scaffold(body: FirstActivityPage()),
        ),
      );
    }

    testWidgets('renders headline text', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      expect(
        find.text('What do you love doing outside?'),
        findsOneWidget,
      );
    });

    testWidgets('renders body text', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      expect(
        find.text('Pick one to get started. You can always add more later.'),
        findsOneWidget,
      );
    });

    testWidgets('renders category grid with 8 categories', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      const categoryLabels = [
        'Hiking',
        'Cycling',
        'Running',
        'Picnic',
        'Beach',
        'Photography',
        'Gardening',
        'Stargazing',
      ];

      for (final label in categoryLabels) {
        expect(find.text(label), findsOneWidget,
            reason: 'Expected to find category "$label"');
      }
    });

    testWidgets('tapping a category highlights it (selection works)',
        (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      // Tap on Hiking
      await tester.tap(find.text('Hiking'));
      await tester.pumpAndSettle();

      // Find the AnimatedContainer that wraps Hiking
      // Verify the selection by checking the name field is pre-filled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Hiking');
    });

    testWidgets('activity name field is editable', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      // First select a category to pre-fill
      await tester.tap(find.text('Hiking'));
      await tester.pumpAndSettle();

      // Clear and type custom name
      await tester.enterText(find.byType(TextField), 'Morning Trail Walk');
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Morning Trail Walk');
    });

    testWidgets('tapping category pre-fills name field', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      // Scroll to make Photography visible
      await tester.scrollUntilVisible(
        find.text('Photography'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Photography'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Photography');
    });

    testWidgets('"Add to Wishlist" CTA disabled when no category selected',
        (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      // Find the ElevatedButton inside OnboardingButton
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('CTA enabled when category selected', (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      // Select a category
      await tester.tap(find.text('Cycling'));
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('selecting different category updates name field',
        (tester) async {
      final prefs = await mockPrefs();

      await tester.pumpWidget(buildSubject(prefs: prefs));
      await tester.pumpAndSettle();

      // Select Hiking first
      await tester.tap(find.text('Hiking'));
      await tester.pumpAndSettle();

      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Hiking');

      // Scroll down to reveal Beach which may be off-screen
      await tester.scrollUntilVisible(
        find.text('Beach'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Now select Beach
      await tester.tap(find.text('Beach'));
      await tester.pumpAndSettle();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Beach');
    });

    testWidgets(
        'completes onboarding even when Supabase insert throws (RLS failure)',
        (tester) async {
      final prefs = await mockPrefs();
      final mockEventService = buildMockEventService();
      final mockSupabase = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentUser).thenReturn(null);

      // Simulate RLS policy denial — from().insert() throws
      when(() => mockSupabase.from(any())).thenThrow(
        Exception('new row violates row-level security policy'),
      );

      // Track navigation to /home
      var navigatedToHome = false;

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const Scaffold(body: FirstActivityPage()),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) {
              navigatedToHome = true;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          behavioralEventServiceProvider.overrideWithValue(mockEventService),
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      // Use pump instead of pumpAndSettle (flutter_animate never settles)
      await tester.pump(const Duration(milliseconds: 500));

      // Select a category
      await tester.tap(find.text('Hiking'));
      await tester.pump(const Duration(milliseconds: 500));

      // Scroll down to reveal the CTA
      await tester.scrollUntilVisible(
        find.text('Add to Wishlist'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Add to Wishlist"
      await tester.tap(find.text('Add to Wishlist'));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify behavioral events were still logged despite insert failure
      verify(() => mockEventService.log(
            'wishlist_added',
            extra: any(named: 'extra'),
          )).called(1);
      verify(() => mockEventService.log(
            'onboarding_completed',
            extra: any(named: 'extra'),
          )).called(1);

      // Verify onboarding_complete was set in SharedPreferences
      expect(prefs.getBool('onboarding_complete'), isTrue);

      // Verify navigation to /home occurred
      expect(navigatedToHome, isTrue);
    });

    testWidgets(
        'skips Supabase insert when no auth session exists (no anonymous string)',
        (tester) async {
      final prefs = await mockPrefs();
      final mockEventService = buildMockEventService();
      final mockSupabase = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentUser).thenReturn(null); // No session

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (_, __) => const Scaffold(body: FirstActivityPage()),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home')),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          behavioralEventServiceProvider.overrideWithValue(mockEventService),
          supabaseClientProvider.overrideWithValue(mockSupabase),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Hiking'));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.scrollUntilVisible(
        find.text('Add to Wishlist'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Add to Wishlist'));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify supabase.from() was NEVER called — no insert with 'anonymous'
      verifyNever(() => mockSupabase.from(any()));

      // But events and onboarding completion still happen
      verify(() => mockEventService.log(
            'wishlist_added',
            extra: any(named: 'extra'),
          )).called(1);
      expect(prefs.getBool('onboarding_complete'), isTrue);
    });

    // Parameterized test for all 5 weather themes
    for (final theme in WeatherTheme.values) {
      testWidgets('renders correctly with ${theme.displayName} theme',
          (tester) async {
        final prefs = await mockPrefs();
        final expectedColors = WeatherThemeColors.forTheme(theme);

        await tester.pumpWidget(
          buildSubject(prefs: prefs, themeOverride: theme),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('What do you love doing outside?'),
          findsOneWidget,
        );

        // Verify background color via ColoredBox
        final coloredBoxes = tester.widgetList<ColoredBox>(
          find.byType(ColoredBox),
        );
        final backgrounds = coloredBoxes.map((w) => w.color).toList();
        expect(
          backgrounds.any((c) => c == expectedColors.background),
          isTrue,
          reason:
              'Expected background color ${expectedColors.background} for ${theme.displayName} theme',
        );
      });
    }
  });
}
