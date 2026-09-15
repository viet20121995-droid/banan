import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// What the counter POS (CukCuk) has recorded for a phone number — public,
/// totals only. `found` false = no counter history for that phone.
class SpendLookup {
  const SpendLookup({
    required this.found,
    required this.hasAccount,
    required this.totalSpendVnd,
    required this.micho,
    required this.discountEligible,
    required this.discountRate,
    required this.discountThresholdVnd,
    required this.earnRatePerVnd,
    this.name,
    this.invoiceCount = 0,
    this.lastVisitAt,
  });

  factory SpendLookup.fromJson(Map<String, dynamic> j) => SpendLookup(
        found: j['found'] as bool? ?? false,
        hasAccount: j['hasAccount'] as bool? ?? false,
        name: j['name'] as String?,
        totalSpendVnd: (j['totalSpendVnd'] as num?)?.toDouble() ?? 0,
        micho: (j['micho'] as num?)?.toInt() ?? 0,
        discountEligible: j['discountEligible'] as bool? ?? false,
        discountRate: (j['discountRate'] as num?)?.toDouble() ?? 0,
        discountThresholdVnd:
            (j['discountThresholdVnd'] as num?)?.toDouble() ?? 0,
        earnRatePerVnd: (j['earnRatePerVnd'] as num?)?.toDouble() ?? 0,
        invoiceCount: (j['invoiceCount'] as num?)?.toInt() ?? 0,
        lastVisitAt: j['lastVisitAt'] is String
            ? DateTime.tryParse(j['lastVisitAt'] as String)
            : null,
      );

  final bool found;

  /// A website account already exists for this phone.
  final bool hasAccount;

  /// Masked ("Ng*** V***") — the phone is the only key, so no full name.
  final String? name;
  final double totalSpendVnd;

  /// Micho the counter spend converts to at [earnRatePerVnd].
  final int micho;
  final bool discountEligible;
  final double discountRate;
  final double discountThresholdVnd;
  final double earnRatePerVnd;
  final int invoiceCount;
  final DateTime? lastVisitAt;
}

class SpendLookupApi {
  SpendLookupApi(this._dio);
  final Dio _dio;

  Future<Result<SpendLookup, AppFailure>> lookup(String phone) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/public/spend-lookup',
        queryParameters: {'phone': phone},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(SpendLookup.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
