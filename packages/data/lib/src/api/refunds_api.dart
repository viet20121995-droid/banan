import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/refund_dto.dart';
import 'errors.dart';

class RefundsApi {
  RefundsApi(this._dio);
  final Dio _dio;

  Future<Result<({List<RefundDto> items, int page, int perPage, int total}),
      AppFailure>> list({
    String? status,
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/refunds',
        queryParameters: {
          if (status != null) 'status': status,
          'page': page,
          'perPage': perPage,
        },
      );
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>? ?? const {};
      return Result.success((
        items: raw
            .map((e) => RefundDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: (meta['page'] as num?)?.toInt() ?? 1,
        perPage: (meta['perPage'] as num?)?.toInt() ?? raw.length,
        total: (meta['total'] as num?)?.toInt() ?? raw.length,
      ),);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<RefundDto, AppFailure>> approve(String id) =>
      _post('/refunds/$id/approve', const {});

  Future<Result<RefundDto, AppFailure>> reject(String id, {String? reason}) =>
      _post('/refunds/$id/reject', {if (reason != null) 'reason': reason});

  Future<Result<RefundDto, AppFailure>> _post(
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
      return Result.success(RefundDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
