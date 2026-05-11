import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import '../dtos/category_dto.dart';
import '../dtos/product_dto.dart';
import '../local/json_cache.dart';
import 'errors.dart';

class CatalogApi {
  CatalogApi(this._dio, {JsonCache? cache}) : _cache = cache;

  final Dio _dio;
  final JsonCache? _cache;

  /// `true` if the most recent `categories()` / `products()` call was
  /// served from the local cache because the network was unreachable.
  /// Read by `connectivityProvider` (and the offline banner) to surface
  /// the state to the UI.
  bool _lastWasCached = false;
  DateTime? _lastCacheTimestamp;
  bool get lastWasCached => _lastWasCached;
  DateTime? get lastCacheTimestamp => _lastCacheTimestamp;

  Future<Result<List<CategoryDto>, AppFailure>> categories() async {
    const cacheKey = 'categories';
    try {
      final res = await _dio.get<Map<String, dynamic>>('/categories');
      final list = (res.data?['data'] as List?) ?? const [];
      _lastWasCached = false;
      await _cache?.write(cacheKey, list);
      return Result.success(
        list
            .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      final failure = mapDioErrorToFailure(e);
      final cached = _readCached(cacheKey, failure);
      if (cached != null) {
        return Result.success(
          (cached.payload as List)
              .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
      return Result.failure(failure);
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<({List<ProductDto> items, int page, int perPage, int total}),
      AppFailure>> products({
    String? categoryId,
    String? q,
    bool? seasonal,
    String? storeId,
    int page = 1,
    int perPage = 20,
    String path = '/products',
  }) async {
    final cacheKey = 'products?'
        'c=${categoryId ?? ''}'
        '&q=${q ?? ''}'
        '&s=${seasonal ?? ''}'
        '&store=${storeId ?? ''}'
        '&p=$page'
        '&pp=$perPage'
        '&path=$path';
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: {
          if (categoryId != null) 'categoryId': categoryId,
          if (q != null && q.isNotEmpty) 'q': q,
          if (seasonal != null) 'seasonal': seasonal.toString(),
          if (storeId != null) 'storeId': storeId,
          'page': page,
          'perPage': perPage,
        },
      );
      final data = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>? ?? const {};
      _lastWasCached = false;
      await _cache?.write(cacheKey, {'data': data, 'meta': meta});
      return Result.success((
        items: data
            .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        page: (meta['page'] as num?)?.toInt() ?? page,
        perPage: (meta['perPage'] as num?)?.toInt() ?? perPage,
        total: (meta['total'] as num?)?.toInt() ?? data.length,
      ),);
    } on DioException catch (e) {
      final failure = mapDioErrorToFailure(e);
      final cached = _readCached(cacheKey, failure);
      if (cached != null) {
        final body = cached.payload as Map<String, dynamic>;
        final data = (body['data'] as List?) ?? const [];
        final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};
        return Result.success((
          items: data
              .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
              .toList(),
          page: (meta['page'] as num?)?.toInt() ?? page,
          perPage: (meta['perPage'] as num?)?.toInt() ?? perPage,
          total: (meta['total'] as num?)?.toInt() ?? data.length,
        ),);
      }
      return Result.failure(failure);
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Returns a cached value when [failure] is a network/timeout error AND
  /// we have a previous response stored. Records that the next caller
  /// served stale data so the UI can flag it.
  CachedValue? _readCached(String key, AppFailure failure) {
    if (_cache == null) return null;
    if (failure is! NetworkFailure && failure is! TimeoutFailure) return null;
    final value = _cache.read(key);
    if (value == null) return null;
    _lastWasCached = true;
    _lastCacheTimestamp = value.updatedAt;
    return value;
  }

  Future<Result<ProductDto, AppFailure>> product(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/products/$id');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(ProductDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<ProductDto, AppFailure>> createProduct(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/products',
        data: body,
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (res.statusCode != 200 && res.statusCode != 201) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(ProductDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<ProductDto, AppFailure>> updateProduct(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/products/$id',
        data: body,
      );
      if (res.statusCode != 200) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(ProductDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> deleteProduct(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/products/$id');
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

  Future<Result<UploadResult, AppFailure>> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(mimeType),
        ),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (res.statusCode != 200 && res.statusCode != 201) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(
        UploadResult(
          url: data['url'] as String,
          filename: data['filename'] as String,
          size: (data['size'] as num).toInt(),
          mimeType: data['mimeType'] as String,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
