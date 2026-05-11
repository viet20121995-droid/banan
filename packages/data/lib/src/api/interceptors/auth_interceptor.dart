import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import '../auth_api.dart';

/// Dio interceptor responsible for:
///   1. Attaching `Authorization: Bearer <access>` from secure storage.
///   2. On 401 (for non-auth endpoints), invoking [_refresh] **once** even if
///      multiple requests fail concurrently (single-flight), then retrying
///      the original request with the new token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Future<bool> Function() refresh,
    required Dio dio,
  })  : _storage = tokenStorage,
        _refresh = refresh,
        _dio = dio;

  final TokenStorage _storage;
  final Future<bool> Function() _refresh;
  final Dio _dio;

  Future<bool>? _inFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[kSkipAuthRefresh] == true) {
      return handler.next(options);
    }
    final tokens = await _storage.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final isUnauthorized = response?.statusCode == 401;
    final skip = err.requestOptions.extra[kSkipAuthRefresh] == true;

    if (!isUnauthorized || skip) {
      return handler.next(err);
    }

    final ok = await (_inFlight ??= _refresh().whenComplete(() {
      _inFlight = null;
    }));

    if (!ok) return handler.next(err);

    try {
      // Re-fire the original request with the new token attached. Mark it as
      // skip-refresh to prevent recursion if it 401s again.
      final retryOptions = err.requestOptions;
      final tokens = await _storage.read();
      if (tokens != null) {
        retryOptions.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
      retryOptions.extra[kSkipAuthRefresh] = true;
      final retried = await _dio.fetch<dynamic>(retryOptions);
      return handler.resolve(retried);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    }
  }
}
