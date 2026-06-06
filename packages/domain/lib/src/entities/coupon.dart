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

/// A voucher in the customer's wallet (GET /coupons/mine). Money values are
/// kept as the wire `double` (₫). [usedAt] is only set for used vouchers.
class Voucher extends Equatable {
  const Voucher({
    required this.code,
    required this.type,
    required this.value,
    required this.startsAt,
    required this.endsAt,
    this.minSubtotal,
    this.label,
    this.usedAt,
  });

  final String code;
  final CouponType type;
  final double value;

  /// Minimum order subtotal to use the voucher (₫). Null = no minimum.
  final double? minSubtotal;

  /// Optional human label (e.g. campaign name) shown above the code.
  final String? label;
  final DateTime startsAt;
  final DateTime endsAt;

  /// When the voucher was redeemed — only present in the "used" bucket.
  final DateTime? usedAt;

  @override
  List<Object?> get props =>
      [code, type, value, minSubtotal, label, startsAt, endsAt, usedAt];
}

/// The customer's voucher wallet, split into three buckets by the backend.
class VoucherWallet extends Equatable {
  const VoucherWallet({
    required this.available,
    required this.used,
    required this.expired,
  });

  final List<Voucher> available;
  final List<Voucher> used;
  final List<Voucher> expired;

  static const empty = VoucherWallet(available: [], used: [], expired: []);

  @override
  List<Object?> get props => [available, used, expired];
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
