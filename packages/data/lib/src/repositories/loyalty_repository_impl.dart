import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/loyalty_api.dart';

class LoyaltyRepositoryImpl implements LoyaltyRepository {
  LoyaltyRepositoryImpl(this._api);
  final LoyaltyApi _api;

  @override
  Future<Result<MembershipSummary, AppFailure>> me() async {
    final res = await _api.me();
    return res.map((d) => d.toDomain());
  }
}

class CouponRepositoryImpl implements CouponRepository {
  CouponRepositoryImpl(this._api);
  final CouponsApi _api;

  @override
  Future<Result<CouponPreview, AppFailure>> validate({
    required String code,
    required int subtotalVnd,
    required int deliveryFeeVnd,
  }) async {
    final res = await _api.validate(
      code: code,
      subtotalVnd: subtotalVnd,
      deliveryFeeVnd: deliveryFeeVnd,
    );
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<VoucherWallet, AppFailure>> myWallet() async {
    final res = await _api.myWallet();
    return res.map((d) => d.toDomain());
  }
}
