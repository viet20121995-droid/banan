import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/store_dto.dart';
import 'errors.dart';

class StoresApi {
  StoresApi(this._dio);
  final Dio _dio;

  /// Public store directory (customer pickup picker). Returns the trimmed
  /// public shape (no ward / default-kitchen).
  Future<Result<List<StoreDto>, AppFailure>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/stores');
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => StoreDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Admin store list — full identity rows (ward + default kitchen included),
  /// used by the management screen + editor hydration. ADMIN-gated server-side.
  Future<Result<List<StoreDto>, AppFailure>> listForAdmin() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/stores');
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => StoreDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<StoreDto, AppFailure>> create(Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/stores',
        data: body,
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(StoreDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<StoreDto, AppFailure>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/stores/$id',
        data: body,
      );
      if (res.statusCode != 200) return Result.failure(mapHttpStatusToFailure(res));
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(StoreDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/admin/stores/$id');
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
