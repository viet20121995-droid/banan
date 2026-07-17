import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import '../auth_api.dart';

/// Dio interceptor responsible for:
///   1. Attaching `Authorization: Bearer <access>` from secure storage.
///   2. On 401 (for non-auth endpoints), invoking [_refresh] **once** even if
///      multiple requests fail concurrently (single-flight), then retrying
///      the original request with the new token.
///
/// The 401 hook lives in [onResponse], not just [onError]: `createDioClient`
/// sets `validateStatus` to accept anything under 500 so repositories can read
/// the `{ data, error }` envelope off a 4xx, which means Dio hands a 401 back
/// as a *successful* response and [onError] never sees it. [onError] is kept
/// for the paths where a 401 does arrive as an exception.
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

  /// Collapses concurrent 401s onto one refresh call.
  Future<bool> _refreshOnce() =>
      _inFlight ??= _refresh().whenComplete(() {
        _inFlight = null;
      });

  /// Re-fires a request with the freshly-stored token. Marked skip-refresh so
  /// a second 401 can't loop, which also means `onRequest` won't attach the
  /// header — hence setting it here.
  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final tokens = await _storage.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    options.extra[kSkipAuthRefresh] = true;
    return _dio.fetch<dynamic>(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final skip = response.requestOptions.extra[kSkipAuthRefresh] == true;
    if (response.statusCode != 401 || skip) {
      return handler.next(response);
    }

    final ok = await _refreshOnce();
    // Refresh token dead too — let the 401 through so the caller maps it to an
    // AuthFailure and signs the user out.
    if (!ok) return handler.next(response);

    try {
      return handler.resolve(await _retry(response.requestOptions));
    } on DioException catch (retryErr) {
      return handler.reject(retryErr);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final skip = err.requestOptions.extra[kSkipAuthRefresh] == true;

    if (!isUnauthorized || skip) {
      return handler.next(err);
    }

    final ok = await _refreshOnce();
    if (!ok) return handler.next(err);

    try {
      return handler.resolve(await _retry(err.requestOptions));
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    }
  }
}
