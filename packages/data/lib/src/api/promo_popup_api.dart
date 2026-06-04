import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

class PromoPopupApi {
  PromoPopupApi(this._dio);
  final Dio _dio;

  /// Public read — every customer page load.
  Future<Result<PromoPopup, AppFailure>> get() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/promo-popup');
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Admin-only — read the full popup row.
  Future<Result<PromoPopup, AppFailure>> adminGet() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/admin/promo-popup');
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<PromoPopup, AppFailure>> adminUpdate({
    bool? isActive,
    String? title,
    String? body,
    String? imageUrl,
    String? ctaLabel,
    String? ctaUrl,
    int? countdownSeconds,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/promo-popup',
        data: {
          if (isActive != null) 'isActive': isActive,
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (ctaLabel != null) 'ctaLabel': ctaLabel,
          if (ctaUrl != null) 'ctaUrl': ctaUrl,
          if (countdownSeconds != null)
            'countdownSeconds': countdownSeconds,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Bumps the version — forces every customer to re-see the popup
  /// regardless of previous dismissal.
  Future<Result<PromoPopup, AppFailure>> adminBump() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/promo-popup/bump',
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  PromoPopup _fromJson(Map<String, dynamic> m) => PromoPopup(
        isActive: m['isActive'] as bool? ?? false,
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        imageUrl: m['imageUrl'] as String?,
        ctaLabel: m['ctaLabel'] as String?,
        ctaUrl: m['ctaUrl'] as String?,
        countdownSeconds:
            (m['countdownSeconds'] as num?)?.toInt() ?? 0,
        version: (m['version'] as num?)?.toInt() ?? 1,
      );
}
