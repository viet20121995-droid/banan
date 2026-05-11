import 'package:banan_domain/banan_domain.dart';

class ProductVariantDto {
  const ProductVariantDto({
    required this.id,
    required this.size,
    required this.flavor,
    required this.priceDelta,
    required this.stockMode,
    this.stockQty,
    this.isAvailable = true,
  });

  factory ProductVariantDto.fromJson(Map<String, dynamic> json) {
    return ProductVariantDto(
      id: json['id'] as String,
      size: json['size'] as String,
      flavor: json['flavor'] as String,
      priceDelta: _toDouble(json['priceDelta']),
      stockMode: json['stockMode'] as String,
      stockQty: (json['stockQty'] as num?)?.toInt(),
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  final String id;
  final String size;
  final String flavor;
  final double priceDelta;
  final String stockMode;
  final int? stockQty;
  final bool isAvailable;

  ProductVariant toDomain() => ProductVariant(
        id: id,
        size: size,
        flavor: flavor,
        priceDelta: priceDelta,
        stockMode: StockMode.fromWire(stockMode),
        stockQty: stockQty,
        isAvailable: isAvailable,
      );
}

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
