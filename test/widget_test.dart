import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/main.dart';
import 'package:outabout/services/behavioral_event_service.dart';

class MockBehavioralEventService extends Mock
    implements BehavioralEventService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

MockBehavioralEventService _buildMockEventService() {
  final mockEventService = MockBehavioralEventService();
  when(() => mockEventService.log(any(), extra: any(named: 'extra')))
      .thenAnswer((_) async {});
  return mockEventService;
}

MockSupabaseClient _buildMockSupabase({User? user}) {
  final mockSupabase = MockSupabaseClient();
  final mockAuth = MockGoTrueClient();
  when(() => mockSupabase.auth).thenReturn(mockAuth);
  when(() => mockAuth.currentUser).thenReturn(user);
  return mockSupabase;
}

void main() {
  testWidgets('OutAboutApp renders value proposition headline by default',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          behavioralEventServiceProvider
              .overrideWithValue(_buildMockEventService()),
          supabaseClientProvider
              .overrideWithValue(_buildMockSupabase()),
        ],
        child: const OutAboutApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Never miss perfect weather for the things you love'),
      findsOneWidget,
    );
  });

  testWidgets('OutAboutApp renders home when onboarding is complete',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          behavioralEventServiceProvider
              .overrideWithValue(_buildMockEventService()),
          supabaseClientProvider
              .overrideWithValue(_buildMockSupabase(user: MockUser())),
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
          behavioralEventServiceProvider
              .overrideWithValue(_buildMockEventService()),
          supabaseClientProvider
              .overrideWithValue(_buildMockSupabase()),
        ],
        child: const OutAboutApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
