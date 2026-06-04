import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/merchant_coupons_api.dart';

class MerchantCouponsRepositoryImpl implements MerchantCouponsRepository {
  MerchantCouponsRepositoryImpl(this._api);
  final MerchantCouponsApi _api;

  @override
  Future<Result<List<MerchantCoupon>, AppFailure>> list() async {
    final res = await _api.list();
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<MerchantCoupon, AppFailure>> create(
    CouponDraft draft,
  ) async {
    final res = await _api.create(draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<MerchantCoupon, AppFailure>> update(
    String id, {
    bool? isActive,
    DateTime? endsAt,
    int? maxRedemptions,
    String? label,
  }) async {
    final res = await _api.update(id, {
      if (isActive != null) 'isActive': isActive,
      if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
      if (maxRedemptions != null) 'maxRedemptions': maxRedemptions,
      if (label != null) 'label': label,
    });
    return res.map((d) => d.toDomain());
  }
}
