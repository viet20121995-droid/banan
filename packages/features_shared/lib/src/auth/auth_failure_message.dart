import 'package:banan_core/banan_core.dart';

import '../i18n/app_strings.dart';

/// User-friendly message for an [AppFailure] in the auth context. Pass the
/// active [AppStrings] for a localized message; defaults to Vietnamese for
/// the staff apps, which are VI-only.
String authFailureMessage(AppFailure failure, [AppStrings s = viStrings]) {
  if (failure is AuthFailure) {
    switch (failure.code) {
      case 'AUTH_INVALID_CREDENTIALS':
        return s.authErrInvalidCredentials;
      case 'AUTH_FORBIDDEN':
        return s.authErrForbidden;
      case 'AUTH_REFRESH_INVALID':
        return s.authErrSessionExpired;
    }
  }
  if (failure is ValidationFailure) {
    return failure.message ?? s.authErrCheckInfo;
  }
  if (failure is NetworkFailure || failure is TimeoutFailure) {
    return s.authErrNetwork;
  }
  if (failure is ServerFailure && failure.code == 'AUTH_EMAIL_TAKEN') {
    return s.authErrEmailTaken;
  }
  return failure.message ?? s.authErrGeneric;
}
