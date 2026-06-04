import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import '../dtos/product_dto.dart';
import '../dtos/product_variant_dto.dart';
import 'errors.dart';

/// Public bundles API — customer site lists active combos + opens
/// detail view (which includes a `savedVnd` field computed server-side).
class BundlesApi {
  BundlesApi(this._dio);
  final Dio _dio;

  Future<Result<List<Bundle>, AppFailure>> list() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/bundles');
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw.map((e) => _fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<List<Bundle>, AppFailure>> home() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/bundles/home');
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw.map((e) => _fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Bundle, AppFailure>> detail(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/bundles/$id');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  // ── Merchant CRUD ──────────────────────────────────────────────────

  Future<Result<List<Bundle>, AppFailure>> merchantList() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/merchant/bundles');
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw.map((e) => _fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Bundle, AppFailure>> merchantDetail(String id) =>
      _writeOne(() => _dio.get('/merchant/bundles/$id'));

  Future<Result<Bundle, AppFailure>> create(Map<String, dynamic> body) =>
      _writeOne(() => _dio.post('/merchant/bundles', data: body));

  Future<Result<Bundle, AppFailure>> updateBundle(
    String id,
    Map<String, dynamic> body,
  ) =>
      _writeOne(() => _dio.patch('/merchant/bundles/$id', data: body));

  Future<Result<void, AppFailure>> deleteBundle(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/merchant/bundles/$id');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Bundle, AppFailure>> _writeOne(
    Future<Response<dynamic>> Function() run,
  ) async {
    try {
      final res = await run();
      final body = res.data as Map<String, dynamic>?;
      final data = body?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  static Bundle _fromJson(Map<String, dynamic> j) {
    final items = ((j['items'] as List?) ?? const [])
        .map((e) => _itemFromJson(e as Map<String, dynamic>))
        .toList();
    return Bundle(
      id: j['id'] as String,
      storeId: j['storeId'] as String,
      name: j['name'] as String,
      slug: j['slug'] as String,
      description: j['description'] as String?,
      imageUrl: j['imageUrl'] as String?,
      priceVnd: (j['priceVnd'] as num).toInt(),
      isActive: j['isActive'] as bool? ?? true,
      isPinnedToHome: j['isPinnedToHome'] as bool? ?? false,
      items: items,
      savedVnd: (j['savedVnd'] as num?)?.toInt(),
    );
  }

  static BundleItem _itemFromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>?;
    final variant = j['variant'] as Map<String, dynamic>?;
    return BundleItem(
      id: j['id'] as String,
      productId: j['productId'] as String,
      variantId: j['variantId'] as String?,
      quantity: (j['quantity'] as num).toInt(),
      product:
          product == null ? null : ProductDto.fromJson(product).toDomain(),
      variant:
          variant == null ? null : ProductVariantDto.fromJson(variant).toDomain(),
    );
  }
}
