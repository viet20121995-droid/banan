import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/banner_dto.dart';
import 'errors.dart';

class BannersApi {
  BannersApi(this._dio);
  final Dio _dio;

  Future<Result<List<BannerDto>, AppFailure>> publicList() =>
      _list('/banners');

  Future<Result<List<BannerDto>, AppFailure>> list() =>
      _list('/merchant/banners');

  Future<Result<BannerDto, AppFailure>> create(
    Map<String, dynamic> body,
  ) =>
      _send(
        () => _dio.post<Map<String, dynamic>>(
          '/merchant/banners',
          data: body,
        ),
      );

  Future<Result<BannerDto, AppFailure>> update(
    String id,
    Map<String, dynamic> body,
  ) =>
      _send(
        () => _dio.patch<Map<String, dynamic>>(
          '/merchant/banners/$id',
          data: body,
        ),
      );

  Future<Result<void, AppFailure>> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/merchant/banners/$id');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<List<BannerDto>, AppFailure>> _list(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => BannerDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<BannerDto, AppFailure>> _send(
    Future<Response<Map<String, dynamic>>> Function() run,
  ) async {
    try {
      final res = await run();
      final code = res.statusCode ?? 0;
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (code < 200 || code >= 300 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(BannerDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
