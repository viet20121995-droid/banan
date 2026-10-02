import 'package:banan_core/banan_core.dart';
import 'package:banan_data/src/api/auth_api.dart';
import 'package:banan_data/src/dtos/auth_response_dto.dart';
import 'package:banan_data/src/repositories/auth_repository_impl.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage implements TokenStorage {
  StoredTokens? tokens =
      const StoredTokens(accessToken: 'a', refreshToken: 'r');
  @override
  Future<StoredTokens?> read() async => tokens;
  @override
  Future<void> write(StoredTokens t) async => tokens = t;
  @override
  Future<void> clear() async => tokens = null;
}

class _Api extends AuthApi {
  _Api(this.failure) : super(Dio());
  final AppFailure failure;
  @override
  Future<Result<AuthResponseDto, AppFailure>> refresh(String token) async =>
      Result.failure(failure);
}

Future<StoredTokens?> _afterRefresh(AppFailure f) async {
  final storage = _Storage();
  await AuthRepositoryImpl(api: _Api(f), storage: storage).refresh();
  return storage.tokens;
}

void main() {
  test('a 502 while the backend restarts keeps the session', () async {
    expect(
      await _afterRefresh(const ServerFailure(code: 'HTTP_502')),
      isNotNull,
    );
  });
  test('a refused refresh token ends the session', () async {
    expect(
      await _afterRefresh(const AuthFailure(code: 'AUTH_REFRESH_INVALID')),
      isNull,
    );
  });
}
