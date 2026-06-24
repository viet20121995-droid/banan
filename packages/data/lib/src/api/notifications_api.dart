import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/notification_dto.dart';
import 'errors.dart';

class NotificationsApi {
  NotificationsApi(this._dio);
  final Dio _dio;

  Future<Result<({List<NotificationDto> items, int unread, int total}),
      AppFailure>> list({int page = 1, int perPage = 30}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/me/notifications',
        queryParameters: {'page': page, 'perPage': perPage},
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>? ?? const {};
      return Result.success((
        items: raw
            .map((e) => NotificationDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        unread: (meta['unread'] as num?)?.toInt() ?? 0,
        total: (meta['total'] as num?)?.toInt() ?? raw.length,
      ),);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> markRead(List<String> ids) async {
    try {
      await _dio.post<dynamic>('/me/notifications/read', data: {'ids': ids});
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> markAllRead() async {
    try {
      await _dio.post<dynamic>('/me/notifications/read-all');
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
