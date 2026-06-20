import 'package:banan_domain/banan_domain.dart';

import 'product_dto.dart';

class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.sortOrder = 0,
    this.isPinnedToHome = false,
    this.isBirthdayCakeCategory = false,
    this.products = const [],
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      imageUrl: json['imageUrl'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isPinnedToHome: json['isPinnedToHome'] as bool? ?? false,
      isBirthdayCakeCategory: json['isBirthdayCakeCategory'] as bool? ?? false,
      products: (json['products'] as List?)
              ?.map((e) => ProductDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;
  final bool isPinnedToHome;
  final bool isBirthdayCakeCategory;
  final List<ProductDto> products;

  Category toDomain() => Category(
        id: id,
        name: name,
        slug: slug,
        imageUrl: imageUrl,
        sortOrder: sortOrder,
        isPinnedToHome: isPinnedToHome,
        isBirthdayCakeCategory: isBirthdayCakeCategory,
        products: products.map((p) => p.toDomain()).toList(),
      );
}
