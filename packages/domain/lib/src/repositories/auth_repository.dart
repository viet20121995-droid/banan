import 'package:banan_core/banan_core.dart';

import '../entities/auth_session.dart';
import '../entities/user.dart';

/// Reactive abstraction over the auth backend. Implementations live in
/// `banan_data`. All methods return `Result` — errors don't escape as exceptions.
abstract class AuthRepository {
  /// Emits whenever the active session changes (login, logout, refresh, restore).
  Stream<AuthSession?> watchSession();

  /// Current cached session, if any. Available synchronously after `bootstrap`.
  AuthSession? get currentSession;

  /// Reads stored tokens, fetches `/me`, and primes [currentSession].
  /// Safe to call multiple times. Should be awaited from `main()` before
  /// `runApp` so the router's first redirect is correct.
  Future<void> bootstrap();

  Future<Result<AuthSession, AppFailure>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    DateTime? birthday,
  });

  Future<Result<AuthSession, AppFailure>> login({
    required String emailOrPhone,
    required String password,
  });

  Future<Result<User, AppFailure>> me();

  /// Change password for the signed-in user (verifies current password).
  Future<Result<bool, AppFailure>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Request a password-reset email for [email]. Always resolves to success
  /// when accepted (the server never reveals whether the email exists).
  Future<Result<bool, AppFailure>> forgotPassword(String email);

  /// Complete a password reset with the token from the email link.
  Future<Result<bool, AppFailure>> resetPassword({
    required String token,
    required String newPassword,
  });

  /// Self-service profile update for the signed-in user. Only non-null
  /// fields are sent. Pass [clearBirthday] to remove an existing birthday.
  /// On success the cached session is updated and re-emitted.
  Future<Result<User, AppFailure>> updateProfile({
    String? fullName,
    String? phone,
    DateTime? birthday,
    bool clearBirthday = false,
    String? avatarUrl,
    Gender? gender,
    bool? marketingOptIn,
    bool? orderUpdatesOptIn,
  });

  /// Permanently delete the signed-in user's account (verifies [password]
  /// server-side). On success the caller should clear the local session.
  Future<Result<bool, AppFailure>> deleteAccount(String password);

  /// Start an email change for the signed-in user. The backend emails a
  /// confirmation link to [newEmail]; the change only completes once that
  /// link is confirmed via [confirmEmailChange].
  Future<Result<bool, AppFailure>> requestEmailChange({
    required String newEmail,
    required String password,
  });

  /// Complete an email change with the token from the confirmation link.
  /// Public — no session required. Resolves to the new email on success.
  Future<Result<String, AppFailure>> confirmEmailChange(String token);

  /// Performs a single-flight refresh against the backend. Used by the auth
  /// interceptor and called automatically on 401.
  Future<Result<AuthSession, AppFailure>> refresh();

  Future<void> logout();

  /// Persist an externally-issued session (e.g. the tokens the orders
  /// endpoint hands back when a guest checkout creates a new account).
  /// Stores the tokens and emits the new session so the router + UI
  /// immediately reflect the logged-in state.
  Future<AuthSession> adoptSession(AuthSession session);
}
