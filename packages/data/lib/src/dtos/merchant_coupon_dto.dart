import 'package:banan_domain/banan_domain.dart';

class MerchantCouponDto {
  const MerchantCouponDto(this._json);

  factory MerchantCouponDto.fromJson(Map<String, dynamic> json) =>
      MerchantCouponDto(json);
  final Map<String, dynamic> _json;

  MerchantCoupon toDomain() => MerchantCoupon(
        id: _json['id'] as String,
        code: _json['code'] as String,
        type: CouponType.fromWire(_json['type'] as String),
        value: (_json['value'] as num).toDouble(),
        minSubtotalVnd: _json['minSubtotalVnd'] == null
            ? null
            : (_json['minSubtotalVnd'] as num).toInt(),
        startsAt: DateTime.parse(_json['startsAt'] as String),
        endsAt: DateTime.parse(_json['endsAt'] as String),
        maxRedemptions: _json['maxRedemptions'] == null
            ? null
            : (_json['maxRedemptions'] as num).toInt(),
        redemptions: (_json['redemptions'] as num).toInt(),
        perUserLimit: (_json['perUserLimit'] as num).toInt(),
        isActive: _json['isActive'] as bool? ?? true,
        chainWide: _json['chainWide'] as bool? ?? false,
        editable: _json['editable'] as bool? ?? true,
        label: _json['label'] as String?,
      );
}
