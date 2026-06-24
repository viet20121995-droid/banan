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

  /// Pinned home categories (each WITH a `products` array). Public endpoint.
  Future<Result<List<CategoryDto>, AppFailure>> homeCategories() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/categories/home');
      final list = (res.data?['data'] as List?) ?? const [];
      return Result.success(
        list
            .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<CategoryDto, AppFailure>> createCategory(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/categories',
        data: body,
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(CategoryDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<CategoryDto, AppFailure>> updateCategory(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/categories/$id',
        data: body,
      );
      if (res.statusCode != 200) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(CategoryDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> deleteCategory(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/categories/$id');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> reorderCategories(List<String> ids) async {
    try {
      final res = await _dio.patch<dynamic>(
        '/categories/reorder',
        data: {'ids': ids},
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
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
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
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

  /// "Khách cũng mua" recommendations for a product detail page.
  /// Returns an ordered list (highest co-occurrence first).
  Future<Result<List<ProductDto>, AppFailure>> recommendations(
    String productId, {
    int limit = 8,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/products/$productId/recommendations',
        queryParameters: {'limit': limit},
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
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

  /// Outcome of `DELETE /products/:id` so the merchant UI can show the
  /// correct toast — hard delete vs archived because of past orders.
  Future<Result<DeleteProductOutcome, AppFailure>> deleteProduct(
    String id,
  ) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>('/products/$id');
      final code = res.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final data = res.data?['data'] as Map<String, dynamic>? ?? const {};
      return Result.success(
        DeleteProductOutcome(
          deleted: data['deleted'] as bool? ?? true,
          archived: data['archived'] as bool? ?? false,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Brings an archived product back to the menu.
  Future<Result<ProductDto, AppFailure>> restoreProduct(String id) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/products/$id/restore',
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(ProductDto.fromJson(data));
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

/// Indicates whether the product was actually removed from the DB or just
/// archived because past orders still reference it.
class DeleteProductOutcome {
  const DeleteProductOutcome({required this.deleted, required this.archived});
  final bool deleted;
  final bool archived;
}
