import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// Merchant + admin reporting API. Every endpoint takes an inclusive day
/// range (`YYYY-MM-DD` strings, ICT) so the merchant can think in calendar
/// days. The XLSX endpoint returns a multi-sheet workbook with every
/// report — convenient for a one-click "export everything for the month".
class ReportsApi {
  ReportsApi(this._dio);
  final Dio _dio;

  Future<Result<ReportSummary, AppFailure>> summary({
    required String from,
    required String to,
    String? storeId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/reports/summary',
        queryParameters: {
          'from': from,
          'to': to,
          if (storeId != null) 'storeId': storeId,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(ReportSummary.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<List<ProductSalesRow>, AppFailure>> productSales({
    required String from,
    required String to,
    String? storeId,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/reports/products',
        queryParameters: {
          'from': from,
          'to': to,
          'limit': limit,
          if (storeId != null) 'storeId': storeId,
        },
      );
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => ProductSalesRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Fetches the multi-sheet XLSX workbook as raw bytes. The UI hands
  /// these to a platform-specific saver (browser blob, or
  /// `path_provider` on mobile).
  Future<Result<Uint8List, AppFailure>> exportXlsx({
    required String from,
    required String to,
    String? storeId,
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        '/merchant/reports/export.xlsx',
        queryParameters: {
          'from': from,
          'to': to,
          if (storeId != null) 'storeId': storeId,
        },
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept':
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',},
        ),
      );
      final data = res.data;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(Uint8List.fromList(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}

class ReportSummary {
  const ReportSummary({
    required this.from,
    required this.to,
    required this.storeId,
    required this.totals,
    required this.daily,
    required this.fulfillment,
    required this.paymentMethods,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> j) {
    final range = j['range'] as Map<String, dynamic>;
    final totals = j['totals'] as Map<String, dynamic>;
    final daily = ((j['daily'] as List?) ?? const [])
        .map((e) => DailyRevenue.fromJson(e as Map<String, dynamic>))
        .toList();
    final ful = j['fulfillment'] as Map<String, dynamic>? ?? const {};
    final pm = j['paymentMethods'] as Map<String, dynamic>? ?? const {};
    return ReportSummary(
      from: DateTime.parse(range['from'] as String),
      to: DateTime.parse(range['to'] as String),
      storeId: range['storeId'] as String?,
      totals: ReportTotals(
        orders: (totals['orders'] as num).toInt(),
        completed: (totals['completed'] as num).toInt(),
        cancelled: (totals['cancelled'] as num).toInt(),
        revenue: (totals['revenue'] as num).toDouble(),
        deliveryFees: (totals['deliveryFees'] as num).toDouble(),
        coupons: (totals['coupons'] as num).toDouble(),
        pointsBurned: (totals['pointsBurned'] as num).toDouble(),
        avgOrderValue: (totals['avgOrderValue'] as num).toDouble(),
        refundedAmount: (totals['refundedAmount'] as num).toDouble(),
      ),
      daily: daily,
      fulfillment: FulfillmentSplit(
        pickup: (ful['pickup'] as num?)?.toInt() ?? 0,
        delivery: (ful['delivery'] as num?)?.toInt() ?? 0,
      ),
      paymentMethods: pm.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  final DateTime from;
  final DateTime to;
  final String? storeId;
  final ReportTotals totals;
  final List<DailyRevenue> daily;
  final FulfillmentSplit fulfillment;
  final Map<String, int> paymentMethods;
}

class ReportTotals {
  const ReportTotals({
    required this.orders,
    required this.completed,
    required this.cancelled,
    required this.revenue,
    required this.deliveryFees,
    required this.coupons,
    required this.pointsBurned,
    required this.avgOrderValue,
    required this.refundedAmount,
  });
  final int orders;
  final int completed;
  final int cancelled;
  final double revenue;
  final double deliveryFees;
  final double coupons;
  final double pointsBurned;
  final double avgOrderValue;
  final double refundedAmount;
}

class DailyRevenue {
  const DailyRevenue({
    required this.date,
    required this.revenue,
    required this.orders,
  });
  factory DailyRevenue.fromJson(Map<String, dynamic> j) => DailyRevenue(
        date: j['date'] as String,
        revenue: (j['revenue'] as num).toDouble(),
        orders: (j['orders'] as num).toInt(),
      );
  final String date; // YYYY-MM-DD
  final double revenue;
  final int orders;
}

class FulfillmentSplit {
  const FulfillmentSplit({required this.pickup, required this.delivery});
  final int pickup;
  final int delivery;
}

class ProductSalesRow {
  const ProductSalesRow({
    required this.productId,
    required this.productName,
    required this.unitsSold,
    required this.revenue,
  });
  factory ProductSalesRow.fromJson(Map<String, dynamic> j) => ProductSalesRow(
        productId: j['productId'] as String,
        productName: j['productName'] as String,
        unitsSold: (j['unitsSold'] as num).toInt(),
        revenue: (j['revenue'] as num).toDouble(),
      );
  final String productId;
  final String productName;
  final int unitsSold;
  final double revenue;
}
