import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// Raw shape returned by the merchant summary endpoint. Kept as a `Map` here
/// to keep the data layer thin — the dashboard parses what it needs.
class MerchantSummary {
  const MerchantSummary({required this.raw});

  factory MerchantSummary.fromJson(Map<String, dynamic> json) =>
      MerchantSummary(raw: json);

  final Map<String, dynamic> raw;

  String get range => raw['range'] as String;
  Map<String, dynamic> get totals =>
      Map<String, dynamic>.from(raw['totals'] as Map);
  List<Map<String, dynamic>> get daily => ((raw['daily'] as List?) ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<Map<String, dynamic>> get bestSellers =>
      ((raw['bestSellers'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  List<Map<String, dynamic>> get peakHours =>
      ((raw['peakHours'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
}

class KitchenAnalyticsSummary {
  const KitchenAnalyticsSummary({required this.raw});

  factory KitchenAnalyticsSummary.fromJson(Map<String, dynamic> json) =>
      KitchenAnalyticsSummary(raw: json);

  final Map<String, dynamic> raw;

  String get range => raw['range'] as String;
  Map<String, dynamic> get totals =>
      Map<String, dynamic>.from(raw['totals'] as Map);
  List<Map<String, dynamic>> get daily => ((raw['daily'] as List?) ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

class AnalyticsApi {
  AnalyticsApi(this._dio);
  final Dio _dio;

  Future<Result<MerchantSummary, AppFailure>> merchantSummary({
    String range = '7d',
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/analytics/summary',
        queryParameters: {'range': range},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(MerchantSummary.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<KitchenAnalyticsSummary, AppFailure>> kitchenSummary({
    String range = '7d',
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/kitchen/analytics/summary',
        queryParameters: {'range': range},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(KitchenAnalyticsSummary.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
