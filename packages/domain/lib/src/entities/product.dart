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
