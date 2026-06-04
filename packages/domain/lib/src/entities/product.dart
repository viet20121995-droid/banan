import 'dart:math';

import 'package:equatable/equatable.dart';

import 'category.dart';
import 'product_variant.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.description,
    required this.basePrice,
    required this.images,
    required this.variants,
    this.tags = const [],
    this.category,
    this.preparationMinutes = 60,
    this.isAvailable = true,
    this.isSeasonal = false,
    this.seasonStart,
    this.seasonEnd,
    this.leadTimeHours,
    this.availableDaysOfWeek = const [],
    this.dailyMaxQuantity,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.isBirthdayCake = false,
    this.flavorPickCount,
    this.flavorOptions = const [],
  });

  final String id;
  final String storeId;
  final String categoryId;
  final Category? category;
  final String name;
  final String slug;
  final String description;
  final double basePrice;
  final List<String> images;
  final List<ProductVariant> variants;
  /// Free-form merchant-set badges. E.g. ["Vegan", "Bestseller", "New"].
  final List<String> tags;
  final int preparationMinutes;
  final bool isAvailable;
  final bool isSeasonal;
  final DateTime? seasonStart;
  final DateTime? seasonEnd;

  /// Minimum advance notice (hours) the merchant requires for this product.
  /// Null = use the store-wide default.
  final int? leadTimeHours;

  /// Days of week (0=Sun..6=Sat, matches JS Date.getDay()) when this product
  /// is sold. Empty = every day. Used for things like "Trà chiều chỉ T2-T6".
  final List<int> availableDaysOfWeek;

  /// Hard daily quantity cap. Null = unlimited.
  final int? dailyMaxQuantity;

  /// Average star rating across all PUBLISHED reviews (0..5). 0 means no
  /// reviews yet (use [reviewCount] == 0 to distinguish from "rated 0").
  final double averageRating;
  final int reviewCount;

  /// True when the product belongs to the chain's birthday-cake
  /// collection (slug matches `DeliveryConfig.birthdayCakeCollectionSlug`
  /// on the backend). Drives the cake personalization wizard on the
  /// customer product detail.
  final bool isBirthdayCake;

  /// Macaron-set composer. When non-null, the customer must pick exactly
  /// this many flavours from [flavorOptions] (repeats allowed) before
  /// adding to cart. Null = ordinary product (no composer).
  final int? flavorPickCount;
  final List<String> flavorOptions;

  bool get hasFlavorComposer =>
      flavorPickCount != null &&
      flavorPickCount! > 0 &&
      flavorOptions.isNotEmpty;

  /// Sum of remaining stock across every LIMITED variant. `null` when
  /// every variant is UNLIMITED — the UI then knows to hide the indicator
  /// instead of showing "Còn 0" by mistake.
  int? get totalLimitedStock {
    int sum = 0;
    var anyLimited = false;
    for (final v in variants) {
      if (v.stockMode == StockMode.limited) {
        anyLimited = true;
        sum += v.stockQty ?? 0;
      }
    }
    return anyLimited ? sum : null;
  }

  /// True when any LIMITED variant is at or below 5 units — drives the
  /// "Còn N cái cuối" urgency badge.
  bool get isLowStock {
    final qty = totalLimitedStock;
    return qty != null && qty > 0 && qty <= 5;
  }

  /// True when every LIMITED variant is sold out (or there are no
  /// UNLIMITED variants left to fall back to).
  bool get isSoldOut {
    if (variants.isEmpty) return false;
    final unlimited = variants.any(
      (v) => v.stockMode == StockMode.unlimited && v.isAvailable,
    );
    if (unlimited) return false;
    return variants
        .where((v) => v.isAvailable)
        .every((v) => v.stockMode == StockMode.limited && (v.stockQty ?? 0) <= 0);
  }

  String? get coverImage => images.isEmpty ? null : images.first;

  /// Price for a given variant. Combine [basePrice] + the variant's delta.
  double priceFor(ProductVariant variant) => basePrice + variant.priceDelta;

  /// Min price across all variants — used for "from X" labels in lists.
  double get minPrice {
    if (variants.isEmpty) return basePrice;
    return variants
        .map((v) => basePrice + v.priceDelta)
        .reduce(min);
  }

  double get maxPrice {
    if (variants.isEmpty) return basePrice;
    return variants
        .map((v) => basePrice + v.priceDelta)
        .reduce(max);
  }

  bool get hasPriceRange => variants.length > 1 && minPrice != maxPrice;

  @override
  List<Object?> get props => [
        id,
        storeId,
        categoryId,
        category,
        name,
        slug,
        description,
        basePrice,
        images,
        variants,
        tags,
        preparationMinutes,
        isAvailable,
        isSeasonal,
        seasonStart,
        seasonEnd,
        leadTimeHours,
        availableDaysOfWeek,
        dailyMaxQuantity,
        averageRating,
        reviewCount,
        isBirthdayCake,
        flavorPickCount,
        flavorOptions,
      ];
}

class ProductPage extends Equatable {
  const ProductPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<Product> items;
  final int page;
  final int perPage;
  final int total;

  bool get hasMore => page * perPage < total;

  @override
  List<Object?> get props => [items, page, perPage, total];
}
