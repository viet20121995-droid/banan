import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

/// Maps a Dio response (4xx/5xx) — already passed through Dio's
/// `validateStatus` — to a typed [AppFailure]. Reads our `{ error: { code, message } }`
/// envelope when present.
AppFailure mapHttpStatusToFailure(Response<dynamic> res) {
  final status = res.statusCode ?? 0;
  final body = res.data;

  String? code;
  String? message;
  if (body is Map<String, dynamic>) {
    final err = body['error'];
    if (err is Map<String, dynamic>) {
      code = err['code'] as String?;
      message = err['message'] as String?;
    }
  }

  if (status == 401) {
    if (code == 'AUTH_REFRESH_INVALID') {
      return AuthFailure(code: code!, message: message);
    }
    return AuthFailure.invalidCredentials();
  }
  if (status == 403) {
    return AuthFailure.forbidden();
  }
  if (status == 422 || status == 400) {
    return ValidationFailure(message: message);
  }
  return ServerFailure(
    code: code ?? 'HTTP_$status',
    message: message ?? 'Request failed ($status).',
  );
}

AppFailure mapDioErrorToFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return TimeoutFailure(cause: e);
    case DioExceptionType.connectionError:
      return NetworkFailure(message: e.message, cause: e);
    case DioExceptionType.badResponse:
      if (e.response != null) return mapHttpStatusToFailure(e.response!);
      return ServerFailure(code: 'BAD_RESPONSE', message: e.message);
    case DioExceptionType.cancel:
      return UnknownFailure(message: 'Request cancelled', cause: e);
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnknownFailure(message: e.message, cause: e);
  }
}
