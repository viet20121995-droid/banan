import 'package:equatable/equatable.dart';

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;

  @override
  List<Object?> get props => [id, name, slug, imageUrl, sortOrder];
}
