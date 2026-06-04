import 'package:equatable/equatable.dart';

import 'product.dart';
import 'product_variant.dart';

/// A fixed-price combo — bundle has its own price, image, name; pulls
/// together existing [Product] rows via [BundleItem]s. The customer site
/// renders a bundle the way it renders a product (card + detail), but
/// the underlying line item on order is a single row with the combo
/// price (cheaper than buying parts separately).
class Bundle extends Equatable {
  const Bundle({
    required this.id,
    required this.storeId,
    required this.name,
    required this.slug,
    required this.priceVnd,
    required this.isActive,
    required this.isPinnedToHome,
    required this.items,
    this.description,
    this.imageUrl,
    this.savedVnd,
  });

  final String id;
  final String storeId;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;

  /// Flat bundle price in VND — sold for this regardless of constituent
  /// products' regular prices.
  final int priceVnd;
  final bool isActive;
  final bool isPinnedToHome;
  final List<BundleItem> items;

  /// Optional — only populated on `GET /bundles/:id`. Sum of regular
  /// line prices minus [priceVnd], so the UI can render "Tiết kiệm X₫".
  final int? savedVnd;

  @override
  List<Object?> get props => [
        id,
        storeId,
        name,
        slug,
        description,
        imageUrl,
        priceVnd,
        isActive,
        isPinnedToHome,
        items,
        savedVnd,
      ];
}

class BundleItem extends Equatable {
  const BundleItem({
    required this.id,
    required this.productId,
    required this.quantity,
    this.variantId,
    this.product,
    this.variant,
  });

  final String id;
  final String productId;
  final String? variantId;
  final int quantity;

  /// Always populated on bundle responses — denormalised so the UI can
  /// render thumbnail + name without a follow-up product fetch.
  final Product? product;

  /// Populated when the bundle item pins a specific variant; null when
  /// the bundle uses the product's default variant.
  final ProductVariant? variant;

  @override
  List<Object?> get props =>
      [id, productId, variantId, quantity, product, variant];
}
