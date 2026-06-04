import 'package:banan_domain/banan_domain.dart';

import 'category_dto.dart';
import 'product_variant_dto.dart';

class ProductDto {
  const ProductDto({
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

  factory ProductDto.fromJson(Map<String, dynamic> json) {
    return ProductDto(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String,
      basePrice: _toDouble(json['basePrice']),
      images: ((json['images'] as List?) ?? const []).cast<String>(),
      tags: ((json['tags'] as List?) ?? const []).cast<String>(),
      preparationMinutes:
          (json['preparationMinutes'] as num?)?.toInt() ?? 60,
      isAvailable: json['isAvailable'] as bool? ?? true,
      isSeasonal: json['isSeasonal'] as bool? ?? false,
      seasonStart: json['seasonStart'] as String?,
      seasonEnd: json['seasonEnd'] as String?,
      leadTimeHours: (json['leadTimeHours'] as num?)?.toInt(),
      availableDaysOfWeek: ((json['availableDaysOfWeek'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      dailyMaxQuantity: (json['dailyMaxQuantity'] as num?)?.toInt(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      isBirthdayCake: json['isBirthdayCake'] as bool? ?? false,
      flavorPickCount: (json['flavorPickCount'] as num?)?.toInt(),
      flavorOptions:
          ((json['flavorOptions'] as List?) ?? const []).cast<String>(),
      variants: ((json['variants'] as List?) ?? const [])
          .map((e) => ProductVariantDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      category: json['category'] == null
          ? null
          : CategoryDto.fromJson(json['category'] as Map<String, dynamic>),
    );
  }

  final String id;
  final String storeId;
  final String categoryId;
  final CategoryDto? category;
  final String name;
  final String slug;
  final String description;
  final double basePrice;
  final List<String> images;
  final List<String> tags;
  final List<ProductVariantDto> variants;
  final int preparationMinutes;
  final bool isAvailable;
  final bool isSeasonal;
  final String? seasonStart;
  final String? seasonEnd;
  final int? leadTimeHours;
  final List<int> availableDaysOfWeek;
  final int? dailyMaxQuantity;
  final double averageRating;
  final int reviewCount;
  final bool isBirthdayCake;
  final int? flavorPickCount;
  final List<String> flavorOptions;

  Product toDomain() => Product(
        id: id,
        storeId: storeId,
        categoryId: categoryId,
        category: category?.toDomain(),
        name: name,
        slug: slug,
        description: description,
        basePrice: basePrice,
        images: images,
        tags: tags,
        variants: variants.map((v) => v.toDomain()).toList(),
        preparationMinutes: preparationMinutes,
        isAvailable: isAvailable,
        isSeasonal: isSeasonal,
        seasonStart:
            seasonStart == null ? null : DateTime.tryParse(seasonStart!),
        seasonEnd: seasonEnd == null ? null : DateTime.tryParse(seasonEnd!),
        leadTimeHours: leadTimeHours,
        availableDaysOfWeek: availableDaysOfWeek,
        dailyMaxQuantity: dailyMaxQuantity,
        averageRating: averageRating,
        reviewCount: reviewCount,
        isBirthdayCake: isBirthdayCake,
        flavorPickCount: flavorPickCount,
        flavorOptions: flavorOptions,
      );
}

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
