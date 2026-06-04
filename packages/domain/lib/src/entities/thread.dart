import 'package:equatable/equatable.dart';

/// A homepage feed entry — announcements, seasonal highlights, news.
/// `publishedAt = null` means it's a draft (only visible to merchants).
/// Instagram-style: carousel images, hashtags, product link, CTA button.
class Thread extends Equatable {
  const Thread({
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

  final String id;
  final String storeId;
  final String? storeName;
  final String authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String title;
  final String body;
  final String? imageUrl;

  /// Carousel images (first = cover). Falls back to [imageUrl] when empty.
  final List<String> images;
  final List<String> hashtags;

  /// Optional "Shop this" deep-link target.
  final String? productId;
  final String? productName;
  final String? productSlug;

  final String? ctaLabel;
  final String? ctaUrl;
  final DateTime? scheduledPublishAt;
  final int viewCount;

  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => publishedAt != null;
  bool get isDraft => publishedAt == null;
  bool get isScheduled => publishedAt == null && scheduledPublishAt != null;

  /// All display images, cover first. Merges the legacy [imageUrl] in.
  List<String> get gallery {
    if (images.isNotEmpty) return images;
    if (imageUrl != null && imageUrl!.isNotEmpty) return [imageUrl!];
    return const [];
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        storeName,
        authorId,
        authorName,
        authorAvatarUrl,
        title,
        body,
        imageUrl,
        images,
        hashtags,
        productId,
        productName,
        productSlug,
        ctaLabel,
        ctaUrl,
        scheduledPublishAt,
        viewCount,
        publishedAt,
        createdAt,
        updatedAt,
      ];
}
