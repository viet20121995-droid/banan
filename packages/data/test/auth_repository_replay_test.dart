import 'package:banan_data/src/api/auth_api.dart';
import 'package:banan_data/src/repositories/auth_repository_impl.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyStorage implements TokenStorage {
  @override
  Future<StoredTokens?> read() async => null;

  @override
  Future<void> write(StoredTokens tokens) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  test('watchSession replays the current session to late subscribers',
      () async {
    final repo = AuthRepositoryImpl(
      api: AuthApi(Dio()),
      storage: _EmptyStorage(),
    );
    // bootstrap() emits before any widget subscribes — exactly what happens
    // on a page reload (main() awaits it before runApp).
    await repo.bootstrap();

    // A late subscriber must still get the current value. With a bare
    // broadcast stream this hangs forever and the timeout fails the test.
    final first = await repo
        .watchSession()
        .first
        .timeout(const Duration(seconds: 2));
    expect(first, isNull);
  });
}
