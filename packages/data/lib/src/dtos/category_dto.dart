import 'package:banan_domain/banan_domain.dart';

class CategoryDto {
  const CategoryDto({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.sortOrder = 0,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      imageUrl: json['imageUrl'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;

  Category toDomain() => Category(
        id: id,
        name: name,
        slug: slug,
        imageUrl: imageUrl,
        sortOrder: sortOrder,
      );
}
