import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/thread_dto.dart';
import 'errors.dart';

class ThreadsApi {
  ThreadsApi(this._dio);
  final Dio _dio;

  Future<Result<List<ThreadDto>, AppFailure>> published({
    String? storeId,
    String? hashtag,
    int limit = 10,
  }) =>
      _list('/threads', {
        if (storeId != null) 'storeId': storeId,
        if (hashtag != null && hashtag.isNotEmpty) 'hashtag': hashtag,
        'limit': limit,
      });

  /// Best-effort impression ping. Swallows all errors.
  Future<void> trackView(String id) async {
    try {
      await _dio.post<void>('/threads/$id/view');
    } catch (_) {
      // analytics is non-critical
    }
  }

  Future<Result<List<ThreadDto>, AppFailure>> store() =>
      _list('/merchant/threads', const {});

  Future<Result<ThreadDto, AppFailure>> get(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/threads/$id');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(ThreadDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<ThreadDto, AppFailure>> create(Map<String, dynamic> body) =>
      _post('/merchant/threads', body);

  Future<Result<ThreadDto, AppFailure>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/merchant/threads/$id',
        data: body,
      );
      if (res.statusCode != 200) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(ThreadDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/merchant/threads/$id');
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

  Future<Result<List<ThreadDto>, AppFailure>> _list(
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => ThreadDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<ThreadDto, AppFailure>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (res.statusCode != 200 && res.statusCode != 201) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(ThreadDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
