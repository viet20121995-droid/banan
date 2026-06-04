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

  /// Self-service profile update for the signed-in user. Only non-null
  /// fields are sent. Pass [clearBirthday] to remove an existing birthday.
  /// On success the cached session is updated and re-emitted.
  Future<Result<User, AppFailure>> updateProfile({
    String? fullName,
    String? phone,
    DateTime? birthday,
    bool clearBirthday = false,
    String? avatarUrl,
  });

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
