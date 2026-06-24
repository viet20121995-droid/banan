import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/collection_dto.dart';
import 'errors.dart';

class CollectionsApi {
  CollectionsApi(this._dio);
  final Dio _dio;

  Future<Result<List<CollectionDto>, AppFailure>> home({String? storeId}) =>
      _list('/collections/home', {if (storeId != null) 'storeId': storeId});

  Future<Result<List<CollectionDto>, AppFailure>> store() =>
      _list('/merchant/collections', const {});

  Future<Result<CollectionDto, AppFailure>> get(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/collections/$id');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(CollectionDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<CollectionDto, AppFailure>> create(
    Map<String, dynamic> body,
  ) =>
      _post('/merchant/collections', body);

  /// Append products to an existing collection — the "add to collection"
  /// flow from the menu list. Server skips products already present.
  Future<Result<CollectionDto, AppFailure>> addItems(
    String id,
    List<String> productIds,
  ) =>
      _post('/merchant/collections/$id/items', {'productIds': productIds});

  Future<Result<CollectionDto, AppFailure>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/merchant/collections/$id',
        data: body,
      );
      if (res.statusCode != 200) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(CollectionDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> delete(String id) async {
    try {
      final res =
          await _dio.delete<dynamic>('/merchant/collections/$id');
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

  Future<Result<List<CollectionDto>, AppFailure>> _list(
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => CollectionDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<CollectionDto, AppFailure>> _post(
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
      return Result.success(CollectionDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
