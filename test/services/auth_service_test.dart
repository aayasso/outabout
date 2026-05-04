import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late AuthService authService;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    authService = AuthService(supabase: mockSupabase);
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
    test('calls supabase.auth.signUp and returns success on valid response',
        () async {
      final mockUser = MockUser();
      final response = AuthResponse(
        user: mockUser,
        session: null,
      );

      when(() => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
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
          )).called(1);
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
          )).thenAnswer((_) async {});

      final result = await authService.sendMagicLink('test@example.com');

      expect(result.success, isTrue);
      verify(() => mockAuth.signInWithOtp(
            email: 'test@example.com',
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
}
