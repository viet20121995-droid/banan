import 'package:banan_core/banan_core.dart';

import '../entities/thread.dart';

class ThreadDraft {
  const ThreadDraft({
    required this.title,
    required this.body,
    this.imageUrl,
    this.images = const [],
    this.productId,
    this.ctaLabel,
    this.ctaUrl,
    this.scheduledPublishAt,
    this.publish = false,
  });

  final String title;
  final String body;
  final String? imageUrl;
  final List<String> images;
  final String? productId;
  final String? ctaLabel;
  final String? ctaUrl;
  final DateTime? scheduledPublishAt;
  final bool publish;

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        'images': images,
        if (productId != null && productId!.isNotEmpty) 'productId': productId,
        if (ctaLabel != null && ctaLabel!.isNotEmpty) 'ctaLabel': ctaLabel,
        if (ctaUrl != null && ctaUrl!.isNotEmpty) 'ctaUrl': ctaUrl,
        if (scheduledPublishAt != null)
          'scheduledPublishAt':
              scheduledPublishAt!.toUtc().toIso8601String(),
        'publish': publish,
      };
}

abstract class ThreadsRepository {
  /// Public — published threads only, newest first. Optional hashtag filter.
  Future<Result<List<Thread>, AppFailure>> published({
    String? storeId,
    String? hashtag,
    int limit = 10,
  });

  /// Merchant — drafts + published.
  Future<Result<List<Thread>, AppFailure>> storeThreads();

  Future<Result<Thread, AppFailure>> get(String id);

  Future<Result<Thread, AppFailure>> create(ThreadDraft draft);

  Future<Result<Thread, AppFailure>> update(String id, ThreadDraft draft);

  Future<Result<void, AppFailure>> delete(String id);

  /// Fire-and-forget impression tracking from the customer feed.
  Future<void> trackView(String id);
}
