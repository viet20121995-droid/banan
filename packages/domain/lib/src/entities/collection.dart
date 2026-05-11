import 'package:equatable/equatable.dart';

import 'product.dart';

/// A merchant-curated grouping of products. Pinned collections appear on
/// the customer home page as horizontal carousels.
class Collection extends Equatable {
  const Collection({
    required this.id,
    required this.storeId,
    required this.name,
    required this.slug,
    required this.items,
    this.description,
    this.imageUrl,
    this.isPinnedToHome = false,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String storeId;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final bool isPinnedToHome;
  final int sortOrder;
  final bool isActive;
  final List<CollectionItem> items;

  /// Convenience: just the product list, in display order.
  List<Product> get products =>
      items.map((i) => i.product).whereType<Product>().toList();

  @override
  List<Object?> get props => [
        id,
        storeId,
        name,
        slug,
        description,
        imageUrl,
        isPinnedToHome,
        sortOrder,
        isActive,
        items,
      ];
}

class CollectionItem extends Equatable {
  const CollectionItem({
    required this.id,
    required this.productId,
    required this.sortOrder,
    this.product,
  });

  final String id;
  final String productId;
  final int sortOrder;

  /// Hydrated when the API includes the product. Null on lightweight payloads.
  final Product? product;

  @override
  List<Object?> get props => [id, productId, sortOrder, product];
}
