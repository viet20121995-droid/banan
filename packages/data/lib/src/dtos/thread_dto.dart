import 'package:banan_domain/banan_domain.dart' as domain;

class ThreadDto {
  const ThreadDto({
    required this.id,
    required this.storeId,
    required this.authorId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.publishedAt,
    this.authorName,
    this.authorAvatarUrl,
    this.storeName,
  });

  factory ThreadDto.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : null;
    final store = json['store'] is Map
        ? Map<String, dynamic>.from(json['store'] as Map)
        : null;
    return ThreadDto(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      authorId: json['authorId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String?,
      publishedAt: json['publishedAt'] as String?,
      authorName: author?['fullName'] as String?,
      authorAvatarUrl: author?['avatarUrl'] as String?,
      storeName: store?['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String storeId;
  final String? storeName;
  final String authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String title;
  final String body;
  final String? imageUrl;
  final String? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  domain.Thread toDomain() => domain.Thread(
        id: id,
        storeId: storeId,
        storeName: storeName,
        authorId: authorId,
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        title: title,
        body: body,
        imageUrl: imageUrl,
        publishedAt:
            publishedAt == null ? null : DateTime.tryParse(publishedAt!),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
