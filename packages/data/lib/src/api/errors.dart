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
  Map<String, dynamic>? details;
  if (body is Map<String, dynamic>) {
    final err = body['error'];
    if (err is Map<String, dynamic>) {
      code = err['code'] as String?;
      message = err['message'] as String?;
      final d = err['details'];
      if (d is Map<String, dynamic>) details = d;
    }
  }

  // Structured per-item timeline rejection — preserve the offending cakes so
  // the checkout UI can highlight each one and offer a fix, instead of
  // collapsing to a single opaque message.
  if (code == 'ORDER_ITEMS_TIMELINE') {
    return _orderTimelineFailure(message, details);
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

/// True when [res] carries a 2xx status. Dio's `validateStatus` (< 500) lets
/// 4xx responses through as *normal* responses (not exceptions), so any list
/// endpoint MUST check this before reading `data`: an error envelope
/// (`{ error: { code, message } }`) has no `data` key, so `res.data?['data']
/// as List? ?? const []` would silently yield an empty list — masking a
/// 401/403/500 as "no results" and showing a misleading empty state instead of
/// the real error. Guard list reads with:
///   `if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));`
bool isOk(Response<dynamic> res) {
  final code = res.statusCode ?? 0;
  return code >= 200 && code < 300;
}

/// Parses the `{ items, earliestLeadHours }` payload of an
/// `ORDER_ITEMS_TIMELINE` error into a typed [OrderTimelineFailure]. Falls back
/// to an item-less failure (still carrying the message) if details are absent.
OrderTimelineFailure _orderTimelineFailure(
  String? message,
  Map<String, dynamic>? details,
) {
  final items = <TimelineViolation>[];
  final raw = details?['items'];
  if (raw is List) {
    for (final r in raw) {
      if (r is! Map) continue;
      final m = r.cast<String, dynamic>();
      items.add(
        TimelineViolation(
          productId: m['productId'] as String? ?? '',
          name: m['name'] as String? ?? '',
          reason: m['reason'] == 'DAY_UNAVAILABLE'
              ? TimelineReason.dayUnavailable
              : TimelineReason.leadTime,
          leadTimeHours: (m['leadTimeHours'] as num?)?.toInt(),
          availableDaysOfWeek: (m['availableDaysOfWeek'] as List?)
                  ?.whereType<num>()
                  .map((e) => e.toInt())
                  .toList() ??
              const [],
        ),
      );
    }
  }
  return OrderTimelineFailure(
    items: items,
    earliestLeadHours: (details?['earliestLeadHours'] as num?)?.toInt(),
    message: message,
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
