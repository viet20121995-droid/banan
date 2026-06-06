import 'package:banan_core/banan_core.dart';

import '../entities/coupon.dart';
import '../entities/loyalty.dart';

abstract class LoyaltyRepository {
  Future<Result<MembershipSummary, AppFailure>> me();
}

abstract class CouponRepository {
  /// Server-side validation. Returns the discount the customer would get.
  Future<Result<CouponPreview, AppFailure>> validate({
    required String code,
    required int subtotalVnd,
    required int deliveryFeeVnd,
  });

  /// The signed-in customer's voucher wallet (GET /coupons/mine), split into
  /// available / used / expired buckets.
  Future<Result<VoucherWallet, AppFailure>> myWallet();
}
