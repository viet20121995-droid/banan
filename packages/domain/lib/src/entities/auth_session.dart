import 'package:equatable/equatable.dart';

import 'user.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final User user;

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    User? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, user];
}

/// Stored token pair. The user object is fetched via `/me` after restoring.
class StoredTokens extends Equatable {
  const StoredTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  List<Object?> get props => [accessToken, refreshToken];
}
