import 'package:banan_core/banan_core.dart';

import '../entities/collection.dart';

/// Input shape for create / update — `items` is the full authoritative list
/// of products, and the server diff-updates against the existing rows.
class CollectionDraft {
  const CollectionDraft({
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
    this.isPinnedToHome = false,
    this.sortOrder = 0,
    this.isActive = true,
    this.items = const [],
  });

  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;
  final bool isPinnedToHome;
  final int sortOrder;
  final bool isActive;
  final List<CollectionItemDraft> items;

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        if (description != null && description!.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        'isPinnedToHome': isPinnedToHome,
        'sortOrder': sortOrder,
        'isActive': isActive,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class CollectionItemDraft {
  const CollectionItemDraft({required this.productId, this.sortOrder});

  final String productId;
  final int? sortOrder;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };
}

abstract class CollectionsRepository {
  /// Customer-facing — pinned + active only.
  Future<Result<List<Collection>, AppFailure>> homeCollections({String? storeId});

  /// Merchant-side — every collection for the store.
  Future<Result<List<Collection>, AppFailure>> storeCollections();

  Future<Result<Collection, AppFailure>> get(String id);

  Future<Result<Collection, AppFailure>> create(CollectionDraft draft);

  Future<Result<Collection, AppFailure>> update(
    String id,
    CollectionDraft draft,
  );

  Future<Result<void, AppFailure>> delete(String id);
}
