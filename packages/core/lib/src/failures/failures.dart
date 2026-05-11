import 'package:banan_core/banan_core.dart' show Result;
import 'package:banan_core/src/result/result.dart' show Result;
import 'package:meta/meta.dart';

/// Base type returned by repositories on the failing branch of [Result].
@immutable
sealed class AppFailure {
  const AppFailure({required this.code, this.message, this.cause});

  /// Stable identifier (e.g. `AUTH_INVALID_CREDENTIALS`). Safe to switch on.
  final String code;

  /// Human-readable message (already localized server-side, or a fallback).
  final String? message;

  /// Underlying error if any (DioException, FormatException, ...).
  final Object? cause;

  @override
  String toString() => '$runtimeType(code=$code, message=$message)';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.message, super.cause})
      : super(code: 'NETWORK');
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.message, super.cause})
      : super(code: 'TIMEOUT');
}

final class AuthFailure extends AppFailure {
  const AuthFailure({required super.code, super.message, super.cause});

  factory AuthFailure.invalidCredentials() =>
      const AuthFailure(code: 'AUTH_INVALID_CREDENTIALS');
  factory AuthFailure.tokenExpired() =>
      const AuthFailure(code: 'AUTH_TOKEN_EXPIRED');
  factory AuthFailure.forbidden() =>
      const AuthFailure(code: 'AUTH_FORBIDDEN');
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({super.message, super.cause, this.fields = const {}})
      : super(code: 'VALIDATION');

  /// Field name → error message map from the server.
  final Map<String, String> fields;
}

/// Generic catch-all when the server returns a non-2xx with a known code.
final class ServerFailure extends AppFailure {
  const ServerFailure({required super.code, super.message, super.cause});
}

/// Last-resort wrapper for truly unexpected exceptions.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.message, super.cause})
      : super(code: 'UNKNOWN');
}
