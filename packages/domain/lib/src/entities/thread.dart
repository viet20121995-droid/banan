import 'package:equatable/equatable.dart';

/// A homepage feed entry — announcements, seasonal highlights, news.
/// `publishedAt = null` means it's a draft (only visible to merchants).
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
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPublished => publishedAt != null;
  bool get isDraft => publishedAt == null;

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
        publishedAt,
        createdAt,
        updatedAt,
      ];
}
