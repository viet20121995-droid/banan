import 'package:equatable/equatable.dart';

enum ReviewStatus { pending, published, rejected }

/// A customer review of a product. Customers can leave at most one review
/// per product; submitting again updates the existing one.
class Review extends Equatable {
  const Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.rating,
    required this.status,
    required this.createdAt,
    this.orderId,
    this.body,
    this.images = const [],
    this.userFullName,
    this.userAvatarUrl,
    this.productName,
    this.productImage,
  });

  final String id;
  final String productId;
  final String userId;
  final String? orderId;

  /// 1..5 stars.
  final int rating;
  final String? body;
  final List<String> images;
  final ReviewStatus status;
  final DateTime createdAt;

  /// Decorated by the API for display ("Đánh giá của <fullName>").
  final String? userFullName;
  final String? userAvatarUrl;
  final String? productName;
  final String? productImage;

  bool get isPublished => status == ReviewStatus.published;

  @override
  List<Object?> get props => [
        id,
        productId,
        userId,
        orderId,
        rating,
        body,
        images,
        status,
        createdAt,
        userFullName,
        userAvatarUrl,
        productName,
        productImage,
      ];
}

/// Aggregate shown above the review list ("4.6 ★ · 128 đánh giá").
class ReviewSummary extends Equatable {
  const ReviewSummary({required this.averageRating, required this.totalReviews});
  final double averageRating;
  final int totalReviews;

  @override
  List<Object?> get props => [averageRating, totalReviews];
}

class ReviewPage extends Equatable {
  const ReviewPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    this.summary,
  });

  final List<Review> items;
  final int page;
  final int perPage;
  final int total;
  final ReviewSummary? summary;

  bool get hasMore => page * perPage < total;

  @override
  List<Object?> get props => [items, page, perPage, total, summary];
}
