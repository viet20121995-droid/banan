import 'package:equatable/equatable.dart';

import 'product.dart';

/// A saved product in the customer's wishlist ("Yêu thích").
class WishlistItem extends Equatable {
  const WishlistItem({
    required this.id,
    required this.productId,
    required this.createdAt,
    this.product,
  });

  final String id;
  final String productId;
  final DateTime createdAt;

  /// Decorated by the API — present on the full wishlist endpoint, absent
  /// on the lightweight `/wishlist/ids` endpoint.
  final Product? product;

  @override
  List<Object?> get props => [id, productId, createdAt, product];
}
