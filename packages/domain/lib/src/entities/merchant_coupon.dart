import 'package:equatable/equatable.dart';

import 'coupon.dart';

/// A promo code as seen in the merchant coupon manager.
class MerchantCoupon extends Equatable {
  const MerchantCoupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.startsAt,
    required this.endsAt,
    required this.redemptions,
    required this.perUserLimit,
    required this.isActive,
    required this.chainWide,
    required this.editable,
    this.minSubtotalVnd,
    this.maxRedemptions,
    this.label,
  });

  final String id;
  final String code;
  final CouponType type;
  final double value;
  final int? minSubtotalVnd;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Total uses allowed across everyone. Null = unlimited (shared code).
  final int? maxRedemptions;
  final int redemptions;

  /// Per-customer cap. 1 = single-use per customer.
  final int perUserLimit;
  final bool isActive;

  /// True when this coupon is chain-wide (admin-issued). Merchants see it
  /// read-only.
  final bool chainWide;

  /// Whether the current viewer may edit/toggle this coupon.
  final bool editable;
  final String? label;

  bool get expired => DateTime.now().isAfter(endsAt);

  bool get fullyClaimed =>
      maxRedemptions != null && redemptions >= maxRedemptions!;

  @override
  List<Object?> get props => [
        id,
        code,
        type,
        value,
        minSubtotalVnd,
        startsAt,
        endsAt,
        maxRedemptions,
        redemptions,
        perUserLimit,
        isActive,
        chainWide,
        editable,
        label,
      ];
}
