import 'package:equatable/equatable.dart';

enum StockMode {
  unlimited,
  limited;

  static StockMode fromWire(String value) =>
      value == 'LIMITED' ? StockMode.limited : StockMode.unlimited;
}

class ProductVariant extends Equatable {
  const ProductVariant({
    required this.id,
    required this.size,
    required this.flavor,
    required this.priceDelta,
    this.sku,
    this.stockMode = StockMode.unlimited,
    this.stockQty,
    this.isAvailable = true,
  });

  final String id;
  final String size;
  final String flavor;

  /// Unified SKU — same code as the kitchen MES product (e.g. VT00708).
  final String? sku;
  final double priceDelta;
  final StockMode stockMode;
  final int? stockQty;
  final bool isAvailable;

  String get label => size == flavor ? size : '$size · $flavor';

  @override
  List<Object?> get props =>
      [id, size, flavor, sku, priceDelta, stockMode, stockQty, isAvailable];
}
