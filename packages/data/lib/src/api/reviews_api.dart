import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// Customer reviews of products. Anyone can read PUBLISHED reviews;
/// only the order's customer can create/update theirs.
class ReviewsApi {
  ReviewsApi(this._dio);
  final Dio _dio;

  Future<Result<ReviewPage, AppFailure>> forProduct(
    String productId, {
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/reviews/product/$productId',
        queryParameters: {'page': page, 'perPage': perPage},
      );
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>? ?? const {};
      final sum = res.data?['summary'] as Map<String, dynamic>?;
      return Result.success(
        ReviewPage(
          items: raw.map((e) => _fromJson(e as Map<String, dynamic>)).toList(),
          page: (meta['page'] as num?)?.toInt() ?? page,
          perPage: (meta['perPage'] as num?)?.toInt() ?? perPage,
          total: (meta['total'] as num?)?.toInt() ?? raw.length,
          summary: sum == null
              ? null
              : ReviewSummary(
                  averageRating:
                      (sum['averageRating'] as num?)?.toDouble() ?? 0,
                  totalReviews: (sum['totalReviews'] as num?)?.toInt() ?? 0,
                ),
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// My reviews against a specific order — drives the per-item "Đánh giá /
  /// Sửa đánh giá" button on the customer order detail.
  Future<Result<List<Review>, AppFailure>> mineForOrder(String orderId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/reviews/mine/order/$orderId',
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

  Future<Result<Review, AppFailure>> create({
    required String productId,
    required String orderId,
    required int rating,
    String? body,
    List<String> images = const [],
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/reviews',
        data: {
          'productId': productId,
          'orderId': orderId,
          'rating': rating,
          if (body != null && body.isNotEmpty) 'body': body,
          if (images.isNotEmpty) 'images': images,
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> delete(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/reviews/$id');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  // ── Merchant moderation ─────────────────────────────────────────────

  Future<Result<ReviewPage, AppFailure>> moderatorList({
    ReviewStatus? status,
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/reviews',
        queryParameters: {
          if (status != null) 'status': _statusToWire(status),
          'page': page,
          'perPage': perPage,
        },
      );
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>? ?? const {};
      return Result.success(
        ReviewPage(
          items: raw.map((e) => _fromJson(e as Map<String, dynamic>)).toList(),
          page: (meta['page'] as num?)?.toInt() ?? page,
          perPage: (meta['perPage'] as num?)?.toInt() ?? perPage,
          total: (meta['total'] as num?)?.toInt() ?? raw.length,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Review, AppFailure>> moderate(
    String id, {
    required ReviewStatus status,
    String? moderationNote,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/merchant/reviews/$id/moderate',
        data: {
          'status': _statusToWire(status),
          if (moderationNote != null) 'moderationNote': moderationNote,
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  static Review _fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>?;
    final product = j['product'] as Map<String, dynamic>?;
    final images = ((j['images'] as List?) ?? const []).cast<String>();
    return Review(
      id: j['id'] as String,
      productId: j['productId'] as String,
      userId: j['userId'] as String,
      orderId: j['orderId'] as String?,
      rating: (j['rating'] as num).toInt(),
      body: j['body'] as String?,
      images: images,
      status: _statusFromWire(j['status'] as String?),
      createdAt: DateTime.parse(j['createdAt'] as String),
      userFullName: user?['fullName'] as String?,
      userAvatarUrl: user?['avatarUrl'] as String?,
      productName: product?['name'] as String?,
      productImage: () {
        final imgs = (product?['images'] as List?)?.cast<String>();
        return imgs == null || imgs.isEmpty ? null : imgs.first;
      }(),
    );
  }

  static String _statusToWire(ReviewStatus s) {
    switch (s) {
      case ReviewStatus.pending:
        return 'PENDING';
      case ReviewStatus.published:
        return 'PUBLISHED';
      case ReviewStatus.rejected:
        return 'REJECTED';
    }
  }

  static ReviewStatus _statusFromWire(String? wire) {
    switch (wire) {
      case 'PENDING':
        return ReviewStatus.pending;
      case 'REJECTED':
        return ReviewStatus.rejected;
      default:
        return ReviewStatus.published;
    }
  }
}
