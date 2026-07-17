import 'dart:typed_data';

import 'package:banan_data/src/api/auth_api.dart' show kSkipAuthRefresh;
import 'package:banan_data/src/api/interceptors/auth_interceptor.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a canned status per call, so a test can say "401 first, then 200".
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statuses);

  final List<int> statuses;

  /// The Authorization header as it was *at call time*. Retries mutate the
  /// original RequestOptions in place, so holding the object would show every
  /// call the final token.
  final List<String?> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options.headers['Authorization'] as String?);
    final status = seen.length <= statuses.length
        ? statuses[seen.length - 1]
        : statuses.last;
    return ResponseBody.fromString(
      '{"data":{"ok":true}}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeStorage implements TokenStorage {
  _FakeStorage(this._tokens);
  StoredTokens? _tokens;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

Dio _client(_FakeAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.test/api/v1',
      // Mirrors createDioClient: repositories read the { data, error }
      // envelope off a 4xx, so anything under 500 is a "valid" status. This is
      // exactly what stops Dio from routing a 401 to onError.
      validateStatus: (s) => s != null && s < 500,
    ),
  )..httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('AuthInterceptor', () {
    test('401 triggers a refresh and retries with the new token', () async {
      final adapter = _FakeAdapter([401, 200]);
      final dio = _client(adapter);
      final storage = _FakeStorage(
        const StoredTokens(accessToken: 'old', refreshToken: 'r'),
      );
      var refreshCalls = 0;

      dio.interceptors.add(
        AuthInterceptor(
          tokenStorage: storage,
          dio: dio,
          refresh: () async {
            refreshCalls++;
            await storage.write(
              const StoredTokens(accessToken: 'new', refreshToken: 'r2'),
            );
            return true;
          },
        ),
      );

      final res = await dio.get<dynamic>('/me');

      // Without the onResponse hook the 401 came back untouched and the caller
      // signed the user out while their refresh token was still valid.
      expect(refreshCalls, 1);
      expect(res.statusCode, 200);
      expect(adapter.seen, ['Bearer old', 'Bearer new']);
    });

    test('a dead refresh token lets the 401 through to the caller', () async {
      final adapter = _FakeAdapter([401]);
      final dio = _client(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          tokenStorage: _FakeStorage(
            const StoredTokens(accessToken: 'old', refreshToken: 'r'),
          ),
          dio: dio,
          refresh: () async => false,
        ),
      );

      final res = await dio.get<dynamic>('/me');

      expect(res.statusCode, 401);
      expect(adapter.seen.length, 1, reason: 'must not retry');
    });

    test('the retry never loops when it 401s again', () async {
      final adapter = _FakeAdapter([401, 401]);
      final dio = _client(adapter);
      var refreshCalls = 0;
      dio.interceptors.add(
        AuthInterceptor(
          tokenStorage: _FakeStorage(
            const StoredTokens(accessToken: 'old', refreshToken: 'r'),
          ),
          dio: dio,
          refresh: () async {
            refreshCalls++;
            return true;
          },
        ),
      );

      final res = await dio.get<dynamic>('/me');

      expect(res.statusCode, 401);
      expect(refreshCalls, 1, reason: 'kSkipAuthRefresh must stop recursion');
      expect(adapter.seen.length, 2);
    });

    test('concurrent 401s share one refresh (single-flight)', () async {
      final adapter = _FakeAdapter([401, 401, 200, 200]);
      final dio = _client(adapter);
      var refreshCalls = 0;
      dio.interceptors.add(
        AuthInterceptor(
          tokenStorage: _FakeStorage(
            const StoredTokens(accessToken: 'old', refreshToken: 'r'),
          ),
          dio: dio,
          refresh: () async {
            refreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return true;
          },
        ),
      );

      await Future.wait([dio.get<dynamic>('/a'), dio.get<dynamic>('/b')]);

      expect(refreshCalls, 1);
    });

    test('auth endpoints marked skip-refresh are left alone', () async {
      final adapter = _FakeAdapter([401]);
      final dio = _client(adapter);
      var refreshCalls = 0;
      dio.interceptors.add(
        AuthInterceptor(
          tokenStorage: _FakeStorage(
            const StoredTokens(accessToken: 'old', refreshToken: 'r'),
          ),
          dio: dio,
          refresh: () async {
            refreshCalls++;
            return true;
          },
        ),
      );

      final res = await dio.get<dynamic>(
        '/auth/refresh',
        options: Options(extra: {kSkipAuthRefresh: true}),
      );

      expect(res.statusCode, 401);
      expect(refreshCalls, 0, reason: 'refreshing on the refresh call loops');
    });
  });
}
