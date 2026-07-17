import 'package:banan_core/banan_core.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_test/flutter_test.dart';

/// `authFailureMessage` is what every app shows a shopper when a call fails,
/// so each branch needs to stay mapped to a human sentence — an unmapped
/// failure silently degrades to the generic fallback.
void main() {
  group('authFailureMessage', () {
    test('maps each known auth code to its own message', () {
      expect(
        authFailureMessage(AuthFailure.invalidCredentials()),
        'Invalid email or password.',
      );
      expect(
        authFailureMessage(const AuthFailure(code: 'AUTH_FORBIDDEN')),
        'Your account is not allowed to do that.',
      );
      expect(
        authFailureMessage(const AuthFailure(code: 'AUTH_REFRESH_INVALID')),
        'Session expired — please sign in again.',
      );
    });

    test('network and timeout share the offline wording', () {
      const offline = 'Cannot reach the kitchen — check your connection.';
      expect(authFailureMessage(const NetworkFailure()), offline);
      expect(authFailureMessage(const TimeoutFailure()), offline);
    });

    test('validation prefers the server message, falls back when absent', () {
      expect(
        authFailureMessage(const ValidationFailure(message: 'Phone is taken.')),
        'Phone is taken.',
      );
      expect(
        authFailureMessage(const ValidationFailure()),
        'Please check the form and try again.',
      );
    });

    test('AUTH_EMAIL_TAKEN is special-cased among server failures', () {
      expect(
        authFailureMessage(const ServerFailure(code: 'AUTH_EMAIL_TAKEN')),
        'An account with that email or phone already exists.',
      );
    });

    test('an unknown failure degrades to its message, else the generic one', () {
      expect(
        authFailureMessage(
          const ServerFailure(code: 'BOOM', message: 'Server on fire.'),
        ),
        'Server on fire.',
      );
      expect(
        authFailureMessage(const ServerFailure(code: 'BOOM')),
        'Something went wrong. Please try again.',
      );
    });
  });
}
