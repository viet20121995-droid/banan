import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';

import '../entities/category.dart';
import '../entities/product.dart';

class ProductDraft {
  ProductDraft({
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.description,
    required this.basePrice,
    required this.variants,
    this.images = const [],
    this.tags = const [],
    this.preparationMinutes,
    this.isAvailable,
    this.isSeasonal,
    this.seasonStart,
    this.seasonEnd,
    this.leadTimeHours,
    this.availableDaysOfWeek = const [],
    this.dailyMaxQuantity,
    this.flavorPickCount,
    this.flavorOptions = const [],
  });

  String categoryId;
  String name;
  String slug;
  String description;
  double basePrice;
  List<String> images;
  /// Free-form merchant-set badges. E.g. ["Vegan", "Bestseller", "New"].
  List<String> tags;
  List<VariantDraft> variants;
  int? preparationMinutes;
  bool? isAvailable;
  bool? isSeasonal;
  DateTime? seasonStart;
  DateTime? seasonEnd;

  /// Optional per-product overrides for the store's order rules.
  ///   leadTimeHours       — advance notice (h); null = use store default.
  ///   availableDaysOfWeek — days the product is sold (0=Sun..6=Sat).
  ///                          Empty = every day.
  ///   dailyMaxQuantity    — hard daily order cap; null = unlimited.
  int? leadTimeHours;
  List<int> availableDaysOfWeek;
  int? dailyMaxQuantity;

  /// Macaron-set composer. When non-null and > 0, the customer must pick
  /// exactly this many flavours from [flavorOptions]. 0/null = off.
  int? flavorPickCount;

  /// Selectable flavour names for the composer. Empty = no composer.
  List<String> flavorOptions;
}

class VariantDraft {
  VariantDraft({
    required this.size, required this.flavor, this.id,
    this.sku,
    this.priceDelta = 0,
    this.stockQty,
    this.isAvailable = true,
  });

  /// Present for existing variants; absent for newly added rows.
  String? id;
  String size;
  String flavor;

  /// Unified SKU — same code as the kitchen MES product. Empty clears it.
  String? sku;
  double priceDelta;
  int? stockQty;
  bool isAvailable;
}

class UploadResult {
  const UploadResult({
    required this.url,
    required this.filename,
    required this.size,
    required this.mimeType,
  });

  final String url;
  final String filename;
  final int size;
  final String mimeType;
}

/// Input shape for category create / update. `toJson` only emits the fields
/// the merchant actually set — mirrors the partial-body contract on the
/// backend's `POST /categories` and `PATCH /categories/:id`.
class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.slug,
    this.imageUrl,
    this.sortOrder = 0,
    this.isPinnedToHome = false,
    this.isBirthdayCakeCategory = false,
  });

  final String name;
  final String slug;
  final String? imageUrl;
  final int sortOrder;
  final bool isPinnedToHome;
  final bool isBirthdayCakeCategory;

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        'sortOrder': sortOrder,
        'isPinnedToHome': isPinnedToHome,
        'isBirthdayCakeCategory': isBirthdayCakeCategory,
      };
}

abstract class CatalogRepository {
  /// [includeHidden] is honoured only for staff tokens — the merchant category
  /// manager passes it to list + unhide hidden categories; customers omit it.
  Future<Result<List<Category>, AppFailure>> categories({
    bool includeHidden = false,
  });

  /// Quick list-level visibility toggle — PATCHes only `isHidden` without
  /// touching the rest of the category.
  Future<Result<Category, AppFailure>> setCategoryHidden(
    String id, {
    required bool hidden,
  });

  /// Customer home strips — pinned categories that have ≥1 available
  /// product, each carrying its `products` array.
  Future<Result<List<Category>, AppFailure>> homeCategories();

  Future<Result<Category, AppFailure>> createCategory(CategoryDraft draft);
  Future<Result<Category, AppFailure>> updateCategory(
    String id,
    CategoryDraft draft,
  );
  /// [force] also removes the category's products (order-free ones are hard-
  /// deleted; the backend refuses if any product already appears in an order).
  Future<Result<void, AppFailure>> deleteCategory(String id, {bool force});

  /// Persists the given category ordering — `sortOrder` becomes each id's
  /// index in [ids].
  Future<Result<void, AppFailure>> reorderCategories(List<String> ids);

  /// Public catalog listing — only available products.
  Future<Result<ProductPage, AppFailure>> products({
    String? categoryId,
    String? q,
    bool? seasonal,
    int page = 1,
    int perPage = 20,
  });

  Future<Result<Product, AppFailure>> product(String id);

  /// "Khách cũng mua" — products that historically appeared in the same
  /// basket as [productId]. Falls back to same-category siblings if the
  /// product is too new to have co-occurrence data.
  Future<Result<List<Product>, AppFailure>> recommendations(
    String productId, {
    int limit,
  });

  /// Merchant view — includes unavailable products. Scoped to caller's store.
  Future<Result<ProductPage, AppFailure>> merchantProducts({
    String? q,
    int page = 1,
    int perPage = 50,
  });

  Future<Result<Product, AppFailure>> createProduct(ProductDraft draft);
  Future<Result<Product, AppFailure>> updateProduct(String id, ProductDraft draft);

  /// Removes the product. Returns `(deleted, archived)` so the UI can
  /// surface the correct outcome — hard delete vs archive-because-of-orders.
  Future<Result<DeleteProductResult, AppFailure>> deleteProduct(String id);

  /// Brings an archived product back to the menu.
  Future<Result<Product, AppFailure>> restoreProduct(String id);

  /// Toggle a product's customer-facing visibility without re-sending the
  /// full draft. Useful for the eye-icon toggle in the merchant menu list.
  Future<Result<Product, AppFailure>> setProductVisibility(
    String id, {
    required bool isAvailable,
  });

  Future<Result<UploadResult, AppFailure>> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  });
}

/// Outcome of `deleteProduct` — distinguishes a real DB delete from an
/// archive (set `isAvailable=false`) when past orders block hard delete.
class DeleteProductResult {
  const DeleteProductResult({required this.deleted, required this.archived});
  final bool deleted;
  final bool archived;
}
