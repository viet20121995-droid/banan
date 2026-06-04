import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// Registers/unregisters a push device token for the logged-in user.
/// Backend upserts by token (idempotent), so re-registering the same token
/// is safe.
class DevicesApi {
  DevicesApi(this._dio);
  final Dio _dio;

  Future<Result<void, AppFailure>> register({
    required String platform, // 'WEB' | 'IOS' | 'ANDROID'
    required String token,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/devices',
        data: {'platform': platform, 'token': token},
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> unregister(String token) async {
    try {
      final res = await _dio.delete<dynamic>('/me/devices/$token');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
