import 'package:banan_domain/banan_domain.dart';

import 'user_dto.dart';

class AuthResponseDto {
  const AuthResponseDto({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final UserDto user;

  AuthSession toDomain() {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user.toDomain(),
    );
  }
}
