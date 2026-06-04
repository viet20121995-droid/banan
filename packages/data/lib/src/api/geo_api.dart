import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// Public ward catalog + live delivery-fee quote + admin-only config.
/// Backend uses hardcoded ward centroids for distance — no external map API.
class GeoApi {
  GeoApi(this._dio);
  final Dio _dio;

  Future<Result<List<HcmWard>, AppFailure>> hcmWards() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/geo/hcm-wards');
      final list = (res.data?['data'] as List?) ?? const [];
      return Result.success(
        list
            .map((e) {
              final m = e as Map<String, dynamic>;
              return HcmWard(
                code: m['code'] as String,
                name: m['name'] as String,
                lat: (m['lat'] as num).toDouble(),
                lng: (m['lng'] as num).toDouble(),
                oldArea: m['oldArea'] as String?,
              );
            })
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Live delivery-fee quote. Pass the ward + cart's product ids so the
  /// backend can detect birthday-cake items and apply the right fee tier.
  Future<Result<DeliveryQuote, AppFailure>> deliveryQuote({
    String? wardCode,
    List<String> productIds = const [],
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/geo/delivery-quote',
        data: {
          if (wardCode != null && wardCode.isNotEmpty) 'wardCode': wardCode,
          if (productIds.isNotEmpty) 'productIds': productIds,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      final storeJson = m['store'] as Map<String, dynamic>?;
      return Result.success(
        DeliveryQuote(
          totalVnd: (m['totalVnd'] as num).toInt(),
          distanceKm: (m['distanceKm'] as num?)?.toDouble(),
          wardKnown: m['wardKnown'] as bool? ?? false,
          tier: (m['tier'] as String?) == 'birthdayCake'
              ? DeliveryFeeTier.birthdayCake
              : DeliveryFeeTier.standard,
          // Backend sends `wardMatch: 'same' | 'other'`. Fall back to the
          // legacy `band: 'over'` from older API versions just in case.
          wardMatch: ((m['wardMatch'] as String?) ?? '') == 'other' ||
                  (m['band'] as String?) == 'over'
              ? DeliveryWardMatch.other
              : DeliveryWardMatch.same,
          hasBirthdayCake: m['hasBirthdayCake'] as bool? ?? false,
          noStoreAvailable: m['noStoreAvailable'] as bool? ?? false,
          store: storeJson == null
              ? null
              : RoutedStore(
                  id: storeJson['id'] as String,
                  name: storeJson['name'] as String,
                  address: storeJson['address'] as String,
                ),
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  // ── Admin-only config CRUD ───────────────────────────────────────────

  Future<Result<DeliveryConfig, AppFailure>> getConfig() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/geo/delivery-config',
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_configFromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<DeliveryConfig, AppFailure>> updateConfig({
    int? standardFeeSameWardVnd,
    int? standardFeeOtherWardVnd,
    int? birthdayCakeFeeSameWardVnd,
    int? birthdayCakeFeeOtherWardVnd,
    String? birthdayCakeCollectionSlug,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/geo/delivery-config',
        data: {
          if (standardFeeSameWardVnd != null)
            'standardFeeSameWardVnd': standardFeeSameWardVnd,
          if (standardFeeOtherWardVnd != null)
            'standardFeeOtherWardVnd': standardFeeOtherWardVnd,
          if (birthdayCakeFeeSameWardVnd != null)
            'birthdayCakeFeeSameWardVnd': birthdayCakeFeeSameWardVnd,
          if (birthdayCakeFeeOtherWardVnd != null)
            'birthdayCakeFeeOtherWardVnd': birthdayCakeFeeOtherWardVnd,
          if (birthdayCakeCollectionSlug != null)
            'birthdayCakeCollectionSlug': birthdayCakeCollectionSlug,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(_configFromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  DeliveryConfig _configFromJson(Map<String, dynamic> m) => DeliveryConfig(
        standardFeeSameWardVnd:
            (m['standardFeeSameWardVnd'] as num).toInt(),
        standardFeeOtherWardVnd:
            (m['standardFeeOtherWardVnd'] as num).toInt(),
        birthdayCakeFeeSameWardVnd:
            (m['birthdayCakeFeeSameWardVnd'] as num).toInt(),
        birthdayCakeFeeOtherWardVnd:
            (m['birthdayCakeFeeOtherWardVnd'] as num).toInt(),
        birthdayCakeCollectionSlug:
            m['birthdayCakeCollectionSlug'] as String,
      );
}
