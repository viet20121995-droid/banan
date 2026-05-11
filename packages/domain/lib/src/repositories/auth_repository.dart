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
  });

  Future<Result<AuthSession, AppFailure>> login({
    required String emailOrPhone,
    required String password,
  });

  Future<Result<User, AppFailure>> me();

  /// Performs a single-flight refresh against the backend. Used by the auth
  /// interceptor and called automatically on 401.
  Future<Result<AuthSession, AppFailure>> refresh();

  Future<void> logout();
}
