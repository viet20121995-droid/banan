import 'package:equatable/equatable.dart';

enum CouponType {
  percent,
  fixed,
  freeDelivery;

  static CouponType fromWire(String value) {
    switch (value) {
      case 'PERCENT':
        return CouponType.percent;
      case 'FIXED':
        return CouponType.fixed;
      case 'FREE_DELIVERY':
        return CouponType.freeDelivery;
      default:
        throw FormatException('Unknown coupon type: $value');
    }
  }
}

/// Result of POST /coupons/validate — what we'd save the customer if applied.
class CouponPreview extends Equatable {
  const CouponPreview({
    required this.code,
    required this.type,
    required this.value,
    required this.discount,
    required this.appliesToDelivery,
  });

  final String code;
  final CouponType type;
  final double value;
  final double discount;
  final bool appliesToDelivery;

  @override
  List<Object?> get props =>
      [code, type, value, discount, appliesToDelivery];
}
