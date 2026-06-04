import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import '../dtos/product_dto.dart';
import 'errors.dart';

/// Customer-only wishlist ("Yêu thích"). Adds are idempotent.
class WishlistApi {
  WishlistApi(this._dio);
  final Dio _dio;

  /// Full list with decorated product info — used by the wishlist tab.
  Future<Result<List<WishlistItem>, AppFailure>> list({
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/wishlist',
        queryParameters: {'page': page, 'perPage': perPage},
      );
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

  /// Lightweight — just the wishlisted product ids so the catalog can paint
  /// hearts on each card without a heavy round-trip.
  Future<Result<Set<String>, AppFailure>> ids() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/wishlist/ids');
      final data = res.data?['data'] as Map<String, dynamic>?;
      final list = (data?['productIds'] as List?)?.cast<String>() ?? const [];
      return Result.success(list.toSet());
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> add(String productId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/wishlist/$productId',
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

  Future<Result<void, AppFailure>> remove(String productId) async {
    try {
      final res = await _dio.delete<dynamic>('/wishlist/$productId');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  static WishlistItem _fromJson(Map<String, dynamic> j) {
    final prod = j['product'] as Map<String, dynamic>?;
    return WishlistItem(
      id: j['id'] as String,
      productId: j['productId'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      product: prod == null ? null : ProductDto.fromJson(prod).toDomain(),
    );
  }
}
