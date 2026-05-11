import 'package:banan_domain/banan_domain.dart';

import 'product_dto.dart';

class CollectionItemDto {
  const CollectionItemDto({
    required this.id,
    required this.productId,
    required this.sortOrder,
    this.product,
  });

  factory CollectionItemDto.fromJson(Map<String, dynamic> json) {
    return CollectionItemDto(
      id: json['id'] as String,
      productId: json['productId'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      product: json['product'] is Map
          ? ProductDto.fromJson(
              Map<String, dynamic>.from(json['product'] as Map),
            )
          : null,
    );
  }

  final String id;
  final String productId;
  final int sortOrder;
  final ProductDto? product;

  CollectionItem toDomain() => CollectionItem(
        id: id,
        productId: productId,
        sortOrder: sortOrder,
        product: product?.toDomain(),
      );
}

class CollectionDto {
  const CollectionDto({
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

  factory CollectionDto.fromJson(Map<String, dynamic> json) {
    return CollectionDto(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isPinnedToHome: json['isPinnedToHome'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      items: ((json['items'] as List?) ?? const [])
          .map((e) => CollectionItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String storeId;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final bool isPinnedToHome;
  final int sortOrder;
  final bool isActive;
  final List<CollectionItemDto> items;

  Collection toDomain() => Collection(
        id: id,
        storeId: storeId,
        name: name,
        slug: slug,
        description: description,
        imageUrl: imageUrl,
        isPinnedToHome: isPinnedToHome,
        sortOrder: sortOrder,
        isActive: isActive,
        items: items.map((i) => i.toDomain()).toList(),
      );
}
