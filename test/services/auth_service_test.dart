import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockSession extends Mock implements Session {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockFunctionsClient mockFunctions;
  late SharedPreferences prefs;
  late AuthService authService;

  /// Keys AuthService clears on deletion, plus one it must leave alone.
  const userScopedKeys = <String>[
    'onboarding_complete',
    'categories_seeded',
    'cached_weather_data',
    'cached_weather_fetched_at',
    'cached_forecast_data',
    'cached_forecast_fetched_at',
  ];

  setUp(() async {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockFunctions = MockFunctionsClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockSupabase.functions).thenReturn(mockFunctions);
    when(() => mockAuth.signOut()).thenAnswer((_) async {});

    SharedPreferences.setMockInitialValues({
      for (final key in userScopedKeys) key: 'set',
      // The real key written by UserThemeOverrideNotifier.
      'weather_theme_override': 'rainy',
    });
    prefs = await SharedPreferences.getInstance();

    authService = AuthService(supabase: mockSupabase, prefs: prefs);
  });

  // -------------------------------------------------------------------------
  // AuthResult
  // -------------------------------------------------------------------------

  group('AuthResult', () {
    test('success factory sets correct fields', () {
      final user = MockUser();
      final result = AuthResult.success(user);

      expect(result.success, isTrue);
      expect(result.user, user);
      expect(result.errorMessage, isNull);
    });

    test('failure factory sets correct fields', () {
      final result = AuthResult.failure('Something went wrong.');

      expect(result.success, isFalse);
      expect(result.user, isNull);
      expect(result.errorMessage, 'Something went wrong.');
    });
  });

  // -------------------------------------------------------------------------
  // Error mapping
  // -------------------------------------------------------------------------

  group('Error mapping', () {
    test('Invalid login credentials maps to user-friendly message', () async {
      when(() => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthException('Invalid login credentials'));

      final result = await authService.signInWithEmail(
        'test@example.com',
        'wrong-password',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Incorrect email or password. Please try again.',
      );
    });

    test('User already registered maps to user-friendly message', () async {
      when(() => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenThrow(AuthException('User already registered'));

      final result = await authService.signUpWithEmail(
        'test@example.com',
        'password123',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'An account with this email already exists. Try signing in instead.',
      );
    });

    test('Email not confirmed maps to user-friendly message', () async {
      when(() => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthException('Email not confirmed'));

      final result = await authService.signInWithEmail(
        'test@example.com',
        'password123',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Please check your email to confirm your account.',
      );
    });

    test('Unknown AuthException maps to generic message', () async {
      when(() => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthException('Some obscure Supabase error'));

      final result = await authService.signInWithEmail(
        'test@example.com',
        'password123',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Something went wrong. Please try again.',
      );
    });

    test('Generic exception maps to fallback message', () async {
      when(() => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Network error'));

      final result = await authService.signInWithEmail(
        'test@example.com',
        'password123',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Something went wrong. Please try again.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // signUpWithEmail
  // -------------------------------------------------------------------------

  group('signUpWithEmail', () {
    test('calls supabase.auth.signUp and returns success on a live session',
        () async {
      final mockUser = MockUser();
      final response = AuthResponse(
        user: mockUser,
        session: MockSession(),
      );

      when(() => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async => response);

      final result = await authService.signUpWithEmail(
        'test@example.com',
        'password123',
      );

      expect(result.success, isTrue);
      expect(result.user, mockUser);
      verify(() => mockAuth.signUp(
            email: 'test@example.com',
            password: 'password123',
            emailRedirectTo: authRedirectUrl,
          )).called(1);
    });

    // Previously asserted as success, which was the bug: a user with no
    // session is the email-confirmation-pending state. The account exists but
    // cannot act, so reporting success sent the caller on to the next
    // onboarding step and then into an app whose router bounced them straight
    // back out — currentUser is null — with nothing telling them why.
    test('a user with no session reports confirmation, not success', () async {
      final response = AuthResponse(user: MockUser(), session: null);

      when(() => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async => response);

      final result = await authService.signUpWithEmail(
        'test@example.com',
        'password123',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Please check your email to confirm your account.',
      );
    });
  });

  // -------------------------------------------------------------------------
  // signInWithEmail
  // -------------------------------------------------------------------------

  group('signInWithEmail', () {
    test(
        'calls supabase.auth.signInWithPassword and returns success on valid response',
        () async {
      final mockUser = MockUser();
      final response = AuthResponse(
        user: mockUser,
        session: null,
      );

      when(() => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => response);

      final result = await authService.signInWithEmail(
        'test@example.com',
        'password123',
      );

      expect(result.success, isTrue);
      expect(result.user, mockUser);
      verify(() => mockAuth.signInWithPassword(
            email: 'test@example.com',
            password: 'password123',
          )).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // sendMagicLink
  // -------------------------------------------------------------------------

  group('sendMagicLink', () {
    test('calls supabase.auth.signInWithOtp and returns success', () async {
      when(() => mockAuth.signInWithOtp(
            email: any(named: 'email'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          )).thenAnswer((_) async {});

      final result = await authService.sendMagicLink('test@example.com');

      expect(result.success, isTrue);
      // The redirect is the point of the link: without it Supabase falls back
      // to the project's Site URL and the user lands on a web page instead of
      // back in the app.
      verify(() => mockAuth.signInWithOtp(
            email: 'test@example.com',
            emailRedirectTo: authRedirectUrl,
          )).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // signInAnonymously
  // -------------------------------------------------------------------------

  group('signInAnonymously', () {
    test(
        'calls supabase.auth.signInAnonymously and returns success on valid response',
        () async {
      final mockUser = MockUser();
      final response = AuthResponse(
        user: mockUser,
        session: null,
      );

      when(() => mockAuth.signInAnonymously())
          .thenAnswer((_) async => response);

      final result = await authService.signInAnonymously();

      expect(result.success, isTrue);
      expect(result.user, mockUser);
      verify(() => mockAuth.signInAnonymously()).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // currentUser
  // -------------------------------------------------------------------------

  group('currentUser', () {
    test('returns current session user', () {
      final mockUser = MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      expect(authService.currentUser, mockUser);
    });

    test('returns null when no user is signed in', () {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(authService.currentUser, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // deleteAccount
  // -------------------------------------------------------------------------

  group('AuthService.deleteAccount', () {
    FunctionResponse response(Object? data, int status) =>
        FunctionResponse(data: data, status: status);

    test('returns success and clears local state when the function '
        'reports ok', () async {
      when(() => mockFunctions.invoke('delete-account'))
          .thenAnswer((_) async => response({'ok': true}, 200));

      final result = await authService.deleteAccount();

      expect(result.success, isTrue);
      verify(() => mockAuth.signOut()).called(1);
      for (final key in userScopedKeys) {
        expect(prefs.get(key), isNull, reason: '$key should be cleared');
      }
    });

    test('leaves device-level preferences alone', () async {
      when(() => mockFunctions.invoke('delete-account'))
          .thenAnswer((_) async => response({'ok': true}, 200));

      await authService.deleteAccount();

      // Theme override is a device preference — it outlives the account.
      expect(prefs.getString('weather_theme_override'), 'rainy');
    });

    test('still signs out and clears state when the function fails', () async {
      when(() => mockFunctions.invoke('delete-account'))
          .thenAnswer((_) async => response({'ok': false}, 500));

      final result = await authService.deleteAccount();

      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
      // Staying signed in would leave a token for a possibly-deleted user.
      verify(() => mockAuth.signOut()).called(1);
      for (final key in userScopedKeys) {
        expect(prefs.get(key), isNull);
      }
    });

    test('still signs out and clears state when invoke throws', () async {
      when(() => mockFunctions.invoke('delete-account'))
          .thenThrow(Exception('network down'));

      final result = await authService.deleteAccount();

      expect(result.success, isFalse);
      verify(() => mockAuth.signOut()).called(1);
      for (final key in userScopedKeys) {
        expect(prefs.get(key), isNull);
      }
    });

    test('treats a non-map response body as failure', () async {
      when(() => mockFunctions.invoke('delete-account'))
          .thenAnswer((_) async => response('unexpected', 200));

      final result = await authService.deleteAccount();

      expect(result.success, isFalse);
    });
  });
}
