import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/store_settings_dto.dart';
import 'errors.dart';

/// Talks to `/merchant/store/...` — settings + blackout date management.
/// All endpoints require a merchant or admin token; scoping to the caller's
/// store happens server-side.
class StoreSettingsApi {
  StoreSettingsApi(this._dio);
  final Dio _dio;

  Future<Result<StoreSettingsDto, AppFailure>> getSettings() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/store/settings',
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(StoreSettingsDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<StoreSettingsDto, AppFailure>> updateSettings(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/merchant/store/settings',
        data: body,
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(StoreSettingsDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<List<StoreBlackoutDateDto>, AppFailure>> listBlackouts() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/store/blackouts',
      );
      final raw = (res.data?['data'] as List?) ?? const [];
      return Result.success(
        raw
            .map((e) =>
                StoreBlackoutDateDto.fromJson(e as Map<String, dynamic>),)
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<StoreBlackoutDateDto, AppFailure>> addBlackout({
    required String isoDate,
    String? reason,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/merchant/store/blackouts',
        data: {
          'date': isoDate,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(StoreBlackoutDateDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<int, AppFailure>> addBlackoutsBulk(
    List<({String isoDate, String? reason})> rows,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/merchant/store/blackouts/bulk',
        data: {
          'dates': rows
              .map(
                (r) => {
                  'date': r.isoDate,
                  if (r.reason != null && r.reason!.isNotEmpty)
                    'reason': r.reason,
                },
              )
              .toList(),
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      final added = (data?['added'] as num?)?.toInt() ?? 0;
      return Result.success(added);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> removeBlackout(String id) async {
    try {
      final res = await _dio.delete<dynamic>(
        '/merchant/store/blackouts/$id',
      );
      if (res.statusCode != null &&
          res.statusCode! >= 200 &&
          res.statusCode! < 300) {
        return const Result.success(null);
      }
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
