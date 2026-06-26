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

  /// Completed revenue + orders per branch. One entry when scoped to a single
  /// store; multiple entries for a whole-chain (admin) view. Already sorted
  /// desc by revenue server-side.
  List<Map<String, dynamic>> get byStore =>
      ((raw['byStore'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  /// Pickup vs delivery split of completed revenue + orders.
  MerchantFulfillmentSplit get byFulfillment {
    final m = raw['byFulfillment'];
    if (m is Map) {
      return MerchantFulfillmentSplit.fromJson(
        Map<String, dynamic>.from(m),
      );
    }
    return const MerchantFulfillmentSplit();
  }

  /// Completed-order counts grouped by payment provider (e.g. CASH, NINEPAY).
  List<Map<String, dynamic>> get byPayment =>
      ((raw['byPayment'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  /// Total coupon + campaign + points + gift-card discount on completed
  /// orders (VND).
  num get discountsGiven => (raw['discountsGiven'] as num?) ?? 0;
}

/// One side (pickup/delivery) of the fulfillment split.
class MerchantFulfillmentBucket {
  const MerchantFulfillmentBucket({this.revenue = 0, this.orders = 0});

  factory MerchantFulfillmentBucket.fromJson(Map<String, dynamic> json) =>
      MerchantFulfillmentBucket(
        revenue: (json['revenue'] as num?) ?? 0,
        orders: (json['orders'] as num?)?.toInt() ?? 0,
      );

  final num revenue;
  final int orders;
}

/// Pickup vs delivery breakdown returned under `byFulfillment`.
class MerchantFulfillmentSplit {
  const MerchantFulfillmentSplit({
    this.pickup = const MerchantFulfillmentBucket(),
    this.delivery = const MerchantFulfillmentBucket(),
  });

  factory MerchantFulfillmentSplit.fromJson(Map<String, dynamic> json) {
    final pickup = json['pickup'];
    final delivery = json['delivery'];
    return MerchantFulfillmentSplit(
      pickup: pickup is Map
          ? MerchantFulfillmentBucket.fromJson(
              Map<String, dynamic>.from(pickup),
            )
          : const MerchantFulfillmentBucket(),
      delivery: delivery is Map
          ? MerchantFulfillmentBucket.fromJson(
              Map<String, dynamic>.from(delivery),
            )
          : const MerchantFulfillmentBucket(),
    );
  }

  final MerchantFulfillmentBucket pickup;
  final MerchantFulfillmentBucket delivery;
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
    String? storeId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/analytics/summary',
        queryParameters: {
          'range': range,
          if (storeId != null) 'storeId': storeId,
        },
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
