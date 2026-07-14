import 'package:equatable/equatable.dart';

import 'product.dart';

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.sortOrder = 0,
    this.isPinnedToHome = false,
    this.isBirthdayCakeCategory = false,
    this.isHidden = false,
    this.products = const [],
  });

  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;

  /// Whether this category is surfaced as a horizontal product strip on the
  /// customer home page. Set by admins in the merchant category manager.
  final bool isPinnedToHome;

  /// When true, this is the single chain-wide birthday-cake category — its
  /// products get the cake-personalization wizard on the customer detail
  /// screen. At most one category carries this flag.
  final bool isBirthdayCakeCategory;

  /// Hidden from the customer storefront entirely (chip, home strip, and all
  /// its products). Merchant/admin still see it to unhide. Visible only in the
  /// merchant category manager.
  final bool isHidden;

  /// Up to a handful of available products, populated only by the
  /// `/categories/home` endpoint so the home strip can render its carousel.
  /// Empty for the plain chip listing.
  final List<Product> products;

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        imageUrl,
        sortOrder,
        isPinnedToHome,
        isBirthdayCakeCategory,
        isHidden,
        products,
      ];
}
