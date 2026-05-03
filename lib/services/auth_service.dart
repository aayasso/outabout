import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';

// ---------------------------------------------------------------------------
// AuthResult
// ---------------------------------------------------------------------------

class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  const AuthResult._({
    required this.success,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.success(User user) => AuthResult._(
        success: true,
        user: user,
      );

  factory AuthResult.failure(String message) => AuthResult._(
        success: false,
        errorMessage: message,
      );
}

// ---------------------------------------------------------------------------
// AuthService
// ---------------------------------------------------------------------------

class AuthService {
  final SupabaseClient _supabase;

  AuthService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Returns the currently signed-in user, or `null`.
  User? get currentUser => _supabase.auth.currentUser;

  /// Creates a new account with email and password.
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        return AuthResult.success(user);
      }
      return AuthResult.failure('Something went wrong. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    } catch (_) {
      return AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  /// Signs in with an existing email and password.
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user != null) {
        return AuthResult.success(user);
      }
      return AuthResult.failure('Something went wrong. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    } catch (_) {
      return AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  /// Sends a magic link to the given email address.
  Future<AuthResult> sendMagicLink(String email) async {
    try {
      await _supabase.auth.signInWithOtp(email: email);
      // OTP sends an email — there is no user object in the response.
      return const AuthResult._(success: true);
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    } catch (_) {
      return AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  /// Signs in anonymously (guest mode).
  Future<AuthResult> signInAnonymously() async {
    try {
      final response = await _supabase.auth.signInAnonymously();
      final user = response.user;
      if (user != null) {
        return AuthResult.success(user);
      }
      return AuthResult.failure('Something went wrong. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    } catch (_) {
      return AuthResult.failure('Something went wrong. Please try again.');
    }
  }

  /// Maps Supabase [AuthException] messages to user-friendly strings.
  /// Never exposes raw error details.
  String _mapAuthError(AuthException e) {
    final msg = e.message;
    if (msg.contains('Invalid login credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('User already registered')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Please check your email to confirm your account.';
    }
    return 'Something went wrong. Please try again.';
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthService(supabase: supabase);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});
