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
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
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

  /// Flavour picks inside composed sets (macaron set 5/10).
  Future<Result<List<FlavorSalesRow>, AppFailure>> flavorSales({
    required String from,
    required String to,
    String? storeId,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/reports/flavors',
        queryParameters: {
          'from': from,
          'to': to,
          if (storeId != null) 'storeId': storeId,
        },
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => FlavorSalesRow.fromJson(e as Map<String, dynamic>))
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
          headers: {
            'Accept':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
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
    this.byStatus = const {},
    this.bySource = const [],
    this.byStore = const [],
    this.byCategory = const [],
    this.topCustomers = const [],
  });

  factory ReportSummary.fromJson(Map<String, dynamic> j) {
    final range = j['range'] as Map<String, dynamic>;
    final totals = j['totals'] as Map<String, dynamic>;
    final daily = ((j['daily'] as List?) ?? const [])
        .map((e) => DailyRevenue.fromJson(e as Map<String, dynamic>))
        .toList();
    final ful = j['fulfillment'] as Map<String, dynamic>? ?? const {};
    final pm = j['paymentMethods'] as Map<String, dynamic>? ?? const {};
    final st = j['byStatus'] as Map<String, dynamic>? ?? const {};
    List<GroupRow> groups(String key) => ((j[key] as List?) ?? const [])
        .map((e) => GroupRow.fromJson(e as Map<String, dynamic>))
        .toList();
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
        inProgress: (totals['inProgress'] as num?)?.toInt() ?? 0,
        grossSales: (totals['grossSales'] as num?)?.toDouble() ?? 0,
        discounts: (totals['discounts'] as num?)?.toDouble() ?? 0,
        itemsSold: (totals['itemsSold'] as num?)?.toInt() ?? 0,
        avgItemsPerOrder: (totals['avgItemsPerOrder'] as num?)?.toDouble() ?? 0,
        cancelRate: (totals['cancelRate'] as num?)?.toDouble() ?? 0,
        cancelledValue: (totals['cancelledValue'] as num?)?.toDouble() ?? 0,
        uniqueCustomers: (totals['uniqueCustomers'] as num?)?.toInt() ?? 0,
        newCustomers: (totals['newCustomers'] as num?)?.toInt() ?? 0,
        returningCustomers:
            (totals['returningCustomers'] as num?)?.toInt() ?? 0,
        giftOrders: (totals['giftOrders'] as num?)?.toInt() ?? 0,
        scheduledOrders: (totals['scheduledOrders'] as num?)?.toInt() ?? 0,
      ),
      daily: daily,
      fulfillment: FulfillmentSplit(
        pickup: (ful['pickup'] as num?)?.toInt() ?? 0,
        delivery: (ful['delivery'] as num?)?.toInt() ?? 0,
      ),
      paymentMethods: pm.map((k, v) => MapEntry(k, (v as num).toInt())),
      byStatus: st.map((k, v) => MapEntry(k, (v as num).toInt())),
      bySource: groups('bySource'),
      byStore: groups('byStore'),
      byCategory: ((j['byCategory'] as List?) ?? const [])
          .map(
            (e) => GroupRow(
              name: (e as Map<String, dynamic>)['category'] as String,
              orders: (e['units'] as num).toInt(),
              revenue: (e['revenue'] as num).toDouble(),
            ),
          )
          .toList(),
      topCustomers: ((j['topCustomers'] as List?) ?? const [])
          .map((e) => CustomerSalesRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final DateTime from;
  final DateTime to;
  final String? storeId;
  final ReportTotals totals;
  final List<DailyRevenue> daily;
  final FulfillmentSplit fulfillment;
  final Map<String, int> paymentMethods;
  final Map<String, int> byStatus;
  final List<GroupRow> bySource;
  final List<GroupRow> byStore;

  /// `orders` carries units sold for category rows.
  final List<GroupRow> byCategory;
  final List<CustomerSalesRow> topCustomers;
}

/// One bucket of a split (channel, branch, category…).
class GroupRow {
  const GroupRow({
    required this.name,
    required this.orders,
    required this.revenue,
    this.completed = 0,
    this.cancelled = 0,
  });
  factory GroupRow.fromJson(Map<String, dynamic> j) => GroupRow(
        name: j['name'] as String,
        orders: (j['orders'] as num).toInt(),
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        cancelled: (j['cancelled'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num).toDouble(),
      );
  final String name;
  final int orders;
  final int completed;
  final int cancelled;
  final double revenue;
}

class CustomerSalesRow {
  const CustomerSalesRow({
    required this.name,
    required this.phone,
    required this.orders,
    required this.completed,
    required this.revenue,
  });
  factory CustomerSalesRow.fromJson(Map<String, dynamic> j) => CustomerSalesRow(
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        orders: (j['orders'] as num).toInt(),
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        revenue: (j['revenue'] as num).toDouble(),
      );
  final String name;
  final String phone;
  final int orders;
  final int completed;
  final double revenue;
}

class FlavorSalesRow {
  const FlavorSalesRow({
    required this.productName,
    required this.flavor,
    required this.units,
  });
  factory FlavorSalesRow.fromJson(Map<String, dynamic> j) => FlavorSalesRow(
        productName: j['productName'] as String,
        flavor: j['flavor'] as String,
        units: (j['units'] as num).toInt(),
      );
  final String productName;
  final String flavor;
  final int units;
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
    this.inProgress = 0,
    this.grossSales = 0,
    this.discounts = 0,
    this.itemsSold = 0,
    this.avgItemsPerOrder = 0,
    this.cancelRate = 0,
    this.cancelledValue = 0,
    this.uniqueCustomers = 0,
    this.newCustomers = 0,
    this.returningCustomers = 0,
    this.giftOrders = 0,
    this.scheduledOrders = 0,
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
  final int inProgress;
  final double grossSales;
  final double discounts;
  final int itemsSold;
  final double avgItemsPerOrder;

  /// Percent, 0–100.
  final double cancelRate;
  final double cancelledValue;
  final int uniqueCustomers;
  final int newCustomers;
  final int returningCustomers;
  final int giftOrders;
  final int scheduledOrders;
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
    this.variantLabel = '',
    this.sku = '',
    this.category = '',
    this.orders = 0,
    this.share = 0,
  });
  factory ProductSalesRow.fromJson(Map<String, dynamic> j) => ProductSalesRow(
        productId: j['productId'] as String,
        productName: j['productName'] as String,
        variantLabel: j['variantLabel'] as String? ?? '',
        sku: j['sku'] as String? ?? '',
        category: j['category'] as String? ?? '',
        orders: (j['orders'] as num?)?.toInt() ?? 0,
        unitsSold: (j['unitsSold'] as num).toInt(),
        revenue: (j['revenue'] as num).toDouble(),
        share: (j['share'] as num?)?.toDouble() ?? 0,
      );
  final String productId;
  final String productName;

  /// "size · flavor" of the sold variant; empty when the product has none.
  final String variantLabel;
  final String sku;
  final String category;

  /// Distinct orders containing this line.
  final int orders;
  final int unitsSold;
  final double revenue;

  /// Share of item revenue in the period, percent 0–100.
  final double share;
}
