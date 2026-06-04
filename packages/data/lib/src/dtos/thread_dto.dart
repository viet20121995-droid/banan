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
    this.images = const [],
    this.hashtags = const [],
    this.productId,
    this.productName,
    this.productSlug,
    this.ctaLabel,
    this.ctaUrl,
    this.scheduledPublishAt,
    this.viewCount = 0,
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
    final product = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : null;
    List<String> strList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];
    return ThreadDto(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      authorId: json['authorId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      imageUrl: json['imageUrl'] as String?,
      images: strList(json['images']),
      hashtags: strList(json['hashtags']),
      productId: json['productId'] as String?,
      productName: product?['name'] as String?,
      productSlug: product?['slug'] as String?,
      ctaLabel: json['ctaLabel'] as String?,
      ctaUrl: json['ctaUrl'] as String?,
      scheduledPublishAt: json['scheduledPublishAt'] as String?,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
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
  final List<String> images;
  final List<String> hashtags;
  final String? productId;
  final String? productName;
  final String? productSlug;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? scheduledPublishAt;
  final int viewCount;
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
        images: images,
        hashtags: hashtags,
        productId: productId,
        productName: productName,
        productSlug: productSlug,
        ctaLabel: ctaLabel,
        ctaUrl: ctaUrl,
        scheduledPublishAt: scheduledPublishAt == null
            ? null
            : DateTime.tryParse(scheduledPublishAt!),
        viewCount: viewCount,
        publishedAt:
            publishedAt == null ? null : DateTime.tryParse(publishedAt!),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
