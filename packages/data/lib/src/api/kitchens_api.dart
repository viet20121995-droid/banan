import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/kitchen_dto.dart';
import 'errors.dart';

/// Admin-only kitchen CRUD over `/admin/kitchens` (ADMIN-gated server-side).
/// The Bearer token is attached automatically by the Dio auth interceptor.
class KitchensApi {
  KitchensApi(this._dio);
  final Dio _dio;

  Future<Result<List<KitchenDto>, AppFailure>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/admin/kitchens');
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => KitchenDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<KitchenDto, AppFailure>> create(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/kitchens',
        data: body,
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(KitchenDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<KitchenDto, AppFailure>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/kitchens/$id',
        data: body,
      );
      if (res.statusCode != 200) return Result.failure(mapHttpStatusToFailure(res));
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(KitchenDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/admin/kitchens/$id');
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
