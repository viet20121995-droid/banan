import 'package:banan_domain/banan_domain.dart';

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class CouponPreviewDto {
  const CouponPreviewDto({
    required this.code,
    required this.type,
    required this.value,
    required this.discount,
    required this.appliesToDelivery,
  });

  factory CouponPreviewDto.fromJson(Map<String, dynamic> json) {
    return CouponPreviewDto(
      code: json['code'] as String,
      type: json['type'] as String,
      value: _toDouble(json['value']),
      discount: _toDouble(json['discount']),
      appliesToDelivery: json['appliesToDelivery'] as bool? ?? false,
    );
  }

  final String code;
  final String type;
  final double value;
  final double discount;
  final bool appliesToDelivery;

  CouponPreview toDomain() => CouponPreview(
        code: code,
        type: CouponType.fromWire(type),
        value: value,
        discount: discount,
        appliesToDelivery: appliesToDelivery,
      );
}

/// Wire format for a single wallet voucher (GET /coupons/mine). Money values
/// arrive as decimal strings; [minSubtotal] / [usedAt] may be null.
class VoucherDto {
  const VoucherDto({
    required this.code,
    required this.type,
    required this.value,
    required this.startsAt,
    required this.endsAt,
    this.minSubtotal,
    this.label,
    this.usedAt,
  });

  factory VoucherDto.fromJson(Map<String, dynamic> json) {
    return VoucherDto(
      code: json['code'] as String,
      type: json['type'] as String,
      value: _toDouble(json['value']),
      minSubtotal:
          json['minSubtotal'] == null ? null : _toDouble(json['minSubtotal']),
      label: json['label'] as String?,
      startsAt: json['startsAt'] as String,
      endsAt: json['endsAt'] as String,
      usedAt: json['usedAt'] as String?,
    );
  }

  final String code;
  final String type;
  final double value;
  final double? minSubtotal;
  final String? label;
  final String startsAt;
  final String endsAt;
  final String? usedAt;

  Voucher toDomain() => Voucher(
        code: code,
        type: CouponType.fromWire(type),
        value: value,
        minSubtotal: minSubtotal,
        label: label,
        startsAt: DateTime.parse(startsAt),
        endsAt: DateTime.parse(endsAt),
        usedAt: usedAt == null ? null : DateTime.tryParse(usedAt!),
      );
}

/// Wire format for the customer's voucher wallet — three buckets.
class VoucherWalletDto {
  const VoucherWalletDto({
    required this.available,
    required this.used,
    required this.expired,
  });

  factory VoucherWalletDto.fromJson(Map<String, dynamic> json) {
    List<VoucherDto> bucket(String key) =>
        ((json[key] as List?) ?? const [])
            .map((e) => VoucherDto.fromJson(e as Map<String, dynamic>))
            .toList();
    return VoucherWalletDto(
      available: bucket('available'),
      used: bucket('used'),
      expired: bucket('expired'),
    );
  }

  final List<VoucherDto> available;
  final List<VoucherDto> used;
  final List<VoucherDto> expired;

  VoucherWallet toDomain() => VoucherWallet(
        available: available.map((v) => v.toDomain()).toList(),
        used: used.map((v) => v.toDomain()).toList(),
        expired: expired.map((v) => v.toDomain()).toList(),
      );
}
