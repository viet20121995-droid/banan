import 'package:meta/meta.dart';

/// Sealed result type. Domain layer returns `Result<T, Failure>` from every
/// repository call so callers handle failure as data, not as exceptions.
@immutable
sealed class Result<T, F> {
  const Result();

  const factory Result.success(T value) = Success<T, F>;
  const factory Result.failure(F failure) = Failure<T, F>;

  bool get isSuccess => this is Success<T, F>;
  bool get isFailure => this is Failure<T, F>;

  /// Folds the result into a single value.
  R when<R>({
    required R Function(T value) success,
    required R Function(F failure) failure,
  }) {
    return switch (this) {
      Success(:final value) => success(value),
      Failure(failure: final f) => failure(f),
    };
  }

  /// Returns the success value or null.
  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  /// Returns the failure or null.
  F? get failureOrNull => switch (this) {
        Success() => null,
        Failure(:final failure) => failure,
      };

  /// Maps the success value, leaving the failure untouched.
  Result<R, F> map<R>(R Function(T value) f) => switch (this) {
        Success(:final value) => Result.success(f(value)),
        Failure(:final failure) => Result.failure(failure),
      };
}

final class Success<T, F> extends Result<T, F> {
  const Success(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Success<T, F> && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

final class Failure<T, F> extends Result<T, F> {
  const Failure(this.failure);
  final F failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure<T, F> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
