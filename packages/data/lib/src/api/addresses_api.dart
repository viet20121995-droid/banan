import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/address_dto.dart';
import 'errors.dart';

class AddressesApi {
  AddressesApi(this._dio);
  final Dio _dio;

  Future<Result<List<AddressDto>, AppFailure>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/addresses');
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => AddressDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<AddressDto, AppFailure>> create(
    Map<String, dynamic> body,
  ) =>
      _send(() => _dio.post<Map<String, dynamic>>('/addresses', data: body));

  Future<Result<AddressDto, AppFailure>> update(
    String id,
    Map<String, dynamic> body,
  ) =>
      _send(
        () => _dio.patch<Map<String, dynamic>>(
          '/addresses/$id',
          data: body,
        ),
      );

  Future<Result<AddressDto, AppFailure>> setDefault(String id) =>
      _send(
        () => _dio.post<Map<String, dynamic>>('/addresses/$id/default'),
      );

  Future<Result<void, AppFailure>> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/addresses/$id');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<AddressDto, AppFailure>> _send(
    Future<Response<Map<String, dynamic>>> Function() run,
  ) async {
    try {
      final res = await run();
      final code = res.statusCode ?? 0;
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (code < 200 || code >= 300 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(AddressDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
