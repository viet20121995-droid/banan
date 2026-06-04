import 'package:banan_core/banan_core.dart';

import '../entities/banner.dart';

class BannerDraft {
  const BannerDraft({
    required this.imageUrl,
    this.title,
    this.ctaUrl,
    this.sortOrder = 0,
  });

  final String imageUrl;
  final String? title;
  final String? ctaUrl;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl,
        if (title != null && title!.isNotEmpty) 'title': title,
        if (ctaUrl != null && ctaUrl!.isNotEmpty) 'ctaUrl': ctaUrl,
        'sortOrder': sortOrder,
      };
}

abstract class BannersRepository {
  /// Public — active banners for the customer hero carousel.
  Future<Result<List<HomeBanner>, AppFailure>> publicList();

  /// Merchant — own store's + chain-wide banners.
  Future<Result<List<HomeBanner>, AppFailure>> list();

  Future<Result<HomeBanner, AppFailure>> create(BannerDraft draft);

  Future<Result<HomeBanner, AppFailure>> update(
    String id, {
    String? imageUrl,
    String? title,
    String? ctaUrl,
    int? sortOrder,
    bool? isActive,
  });

  Future<Result<void, AppFailure>> delete(String id);
}
