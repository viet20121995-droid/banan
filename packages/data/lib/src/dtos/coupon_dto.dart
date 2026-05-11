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
