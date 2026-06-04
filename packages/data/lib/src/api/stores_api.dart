import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/store_dto.dart';
import 'errors.dart';

class StoresApi {
  StoresApi(this._dio);
  final Dio _dio;

  Future<Result<List<StoreDto>, AppFailure>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/stores');
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => StoreDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    }
  }
}
