import 'package:banan_core/banan_core.dart';

import '../entities/coupon.dart';
import '../entities/merchant_coupon.dart';

/// Payload for creating a promo code.
class CouponDraft {
  const CouponDraft({
    required this.code,
    required this.type,
    required this.value,
    required this.startsAt,
    required this.endsAt,
    required this.perUserLimit,
    this.minSubtotalVnd,
    this.maxRedemptions,
    this.label,
  });

  final String code;
  final CouponType type;
  final int value;
  final int? minSubtotalVnd;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Null = unlimited total uses (shared code).
  final int? maxRedemptions;

  /// 1 = single-use per customer.
  final int perUserLimit;
  final String? label;

  String get _typeWire => switch (type) {
        CouponType.percent => 'PERCENT',
        CouponType.fixed => 'FIXED',
        CouponType.freeDelivery => 'FREE_DELIVERY',
      };

  Map<String, dynamic> toJson() => {
        'code': code,
        'type': _typeWire,
        'value': value,
        if (minSubtotalVnd != null && minSubtotalVnd! > 0)
          'minSubtotalVnd': minSubtotalVnd,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt.toUtc().toIso8601String(),
        if (maxRedemptions != null) 'maxRedemptions': maxRedemptions,
        'perUserLimit': perUserLimit,
        if (label != null && label!.isNotEmpty) 'label': label,
      };
}

abstract class MerchantCouponsRepository {
  Future<Result<List<MerchantCoupon>, AppFailure>> list();

  Future<Result<MerchantCoupon, AppFailure>> create(CouponDraft draft);

  /// Toggle active / extend end date / change limits / rename.
  Future<Result<MerchantCoupon, AppFailure>> update(
    String id, {
    bool? isActive,
    DateTime? endsAt,
    int? maxRedemptions,
    String? label,
  });
}
