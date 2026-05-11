import 'package:banan_core/banan_core.dart';

/// User-friendly message for an [AppFailure] in the auth context.
String authFailureMessage(AppFailure failure) {
  if (failure is AuthFailure) {
    switch (failure.code) {
      case 'AUTH_INVALID_CREDENTIALS':
        return 'Invalid email or password.';
      case 'AUTH_FORBIDDEN':
        return 'Your account is not allowed to do that.';
      case 'AUTH_REFRESH_INVALID':
        return 'Session expired — please sign in again.';
    }
  }
  if (failure is ValidationFailure) {
    return failure.message ?? 'Please check the form and try again.';
  }
  if (failure is NetworkFailure || failure is TimeoutFailure) {
    return 'Cannot reach the kitchen — check your connection.';
  }
  if (failure is ServerFailure && failure.code == 'AUTH_EMAIL_TAKEN') {
    return 'An account with that email or phone already exists.';
  }
  return failure.message ?? 'Something went wrong. Please try again.';
}
