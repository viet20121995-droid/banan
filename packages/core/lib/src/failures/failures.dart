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

/// Why a single cart item doesn't fit the customer's chosen fulfilment time.
enum TimelineReason {
  /// Needs more advance notice than the chosen time allows (see leadTimeHours).
  leadTime,

  /// Not sold on the chosen day of week (see availableDaysOfWeek).
  dayUnavailable,
}

/// One offending cake in an [OrderTimelineFailure] — carries enough detail for
/// the checkout UI to highlight the item and explain the fix.
@immutable
class TimelineViolation {
  const TimelineViolation({
    required this.productId,
    required this.name,
    required this.reason,
    this.leadTimeHours,
    this.availableDaysOfWeek = const [],
  });

  final String productId;
  final String name;
  final TimelineReason reason;

  /// Set when [reason] is [TimelineReason.leadTime].
  final int? leadTimeHours;

  /// Days (0=Sun..6=Sat) the product IS sold — set when [reason] is
  /// [TimelineReason.dayUnavailable].
  final List<int> availableDaysOfWeek;
}

/// Returned when an order is rejected because one or more cakes don't fit the
/// chosen delivery/pickup time. Unlike a plain [ValidationFailure] it carries
/// the full list of offending [items] (and the longest [earliestLeadHours]) so
/// the checkout screen can name each cake and offer a one-tap fix.
final class OrderTimelineFailure extends AppFailure {
  const OrderTimelineFailure({
    required this.items,
    this.earliestLeadHours,
    super.message,
  }) : super(code: 'ORDER_ITEMS_TIMELINE');

  final List<TimelineViolation> items;

  /// The largest lead-time (hours) among the lead-time offenders, so the app
  /// can jump the schedule to the soonest time that satisfies every cake.
  final int? earliestLeadHours;
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
