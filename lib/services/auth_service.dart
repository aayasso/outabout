import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/weather_theme_provider.dart';

/// Where Supabase sends the user back to after they follow an emailed link.
///
/// Registered as a URL scheme in `ios/Runner/Info.plist` and as an Android
/// intent filter. Without it Supabase falls back to the project's Site URL —
/// a web page — so a magic link and a confirmation link both opened a browser
/// and never returned to the app, stranding the account unconfirmed.
const String authRedirectUrl = 'outabout://login-callback';

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
  final SharedPreferences _prefs;

  AuthService({
    required SupabaseClient supabase,
    required SharedPreferences prefs,
  })  : _supabase = supabase,
        _prefs = prefs;

  /// Returns the currently signed-in user, or `null`.
  User? get currentUser => _supabase.auth.currentUser;

  /// Creates a new account with email and password.
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: authRedirectUrl,
      );
      final user = response.user;
      // A user with no session means email confirmation is on: the account
      // exists but cannot act yet. Reporting that as success walked the caller
      // into onboarding's next step and then into the app, which the router
      // immediately bounced back out of — `currentUser` is null, so the
      // redirect sends them to onboarding and the whole flow loops. Telling
      // them to check their email is the only honest answer.
      if (user != null && response.session == null) {
        return AuthResult.failure(
          'Please check your email to confirm your account.',
        );
      }
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
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: authRedirectUrl,
      );
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

  /// Permanently deletes the signed-in account and all of its data.
  ///
  /// The server-side `delete-account` edge function does the actual removal;
  /// the session JWT is attached by [FunctionsClient] so no token is handled
  /// here. Works identically for anonymous accounts, which are real
  /// `auth.users` rows.
  ///
  /// Local sign-out and pref clearing happen **regardless of the outcome**: if
  /// the account really was deleted, staying signed in leaves the app holding
  /// a token for a user that no longer exists.
  Future<AuthResult> deleteAccount() async {
    AuthResult result;
    try {
      final response = await _supabase.functions.invoke('delete-account');
      final body = response.data;
      final ok = body is Map && body['ok'] == true;
      result = ok
          ? const AuthResult._(success: true)
          : AuthResult.failure(
              'We could not delete your account. Please try again.',
            );
    } catch (e) {
      log('Account deletion failed', error: e, name: 'AuthService');
      result = AuthResult.failure(
        'We could not delete your account. Please try again.',
      );
    }

    await _clearLocalSession();
    return result;
  }

  /// Signs out and drops user-scoped local state. Never throws — the caller
  /// has already committed to leaving this account behind.
  Future<void> _clearLocalSession() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      log('Sign-out during deletion failed', error: e, name: 'AuthService');
    }
    for (final key in userScopedPrefsKeys) {
      try {
        await _prefs.remove(key);
      } catch (e) {
        log('Clearing "$key" failed', error: e, name: 'AuthService');
      }
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
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthService(supabase: supabase, prefs: prefs);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});
