import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/catalog_api.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._api);

  final CatalogApi _api;

  @override
  Future<Result<List<Category>, AppFailure>> categories({
    bool includeHidden = false,
  }) async {
    final res = await _api.categories(includeHidden: includeHidden);
    return res.map((dtos) => dtos.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<Category, AppFailure>> setCategoryHidden(
    String id, {
    required bool hidden,
  }) async {
    final res = await _api.updateCategory(id, {'isHidden': hidden});
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<List<Category>, AppFailure>> homeCategories() async {
    final res = await _api.homeCategories();
    return res.map((dtos) => dtos.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<Category, AppFailure>> createCategory(CategoryDraft draft) async {
    final res = await _api.createCategory(draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Category, AppFailure>> updateCategory(
    String id,
    CategoryDraft draft,
  ) async {
    final res = await _api.updateCategory(id, draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<void, AppFailure>> deleteCategory(String id, {bool force = false}) {
    return _api.deleteCategory(id, force: force);
  }

  @override
  Future<Result<void, AppFailure>> reorderCategories(List<String> ids) {
    return _api.reorderCategories(ids);
  }

  @override
  Future<Result<ProductPage, AppFailure>> products({
    String? categoryId,
    String? q,
    bool? seasonal,
    int page = 1,
    int perPage = 20,
  }) async {
    final res = await _api.products(
      categoryId: categoryId,
      q: q,
      seasonal: seasonal,
      page: page,
      perPage: perPage,
    );
    return res.map(
      (data) => ProductPage(
        items: data.items.map((d) => d.toDomain()).toList(),
        page: data.page,
        perPage: data.perPage,
        total: data.total,
      ),
    );
  }

  @override
  Future<Result<Product, AppFailure>> product(String id) async {
    final res = await _api.product(id);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<List<Product>, AppFailure>> recommendations(
    String productId, {
    int limit = 8,
  }) async {
    final res = await _api.recommendations(productId, limit: limit);
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<ProductPage, AppFailure>> merchantProducts({
    String? q,
    int page = 1,
    int perPage = 50,
  }) async {
    final res = await _api.products(
      q: q,
      page: page,
      perPage: perPage,
      path: '/products/merchant/list',
    );
    return res.map(
      (data) => ProductPage(
        items: data.items.map((d) => d.toDomain()).toList(),
        page: data.page,
        perPage: data.perPage,
        total: data.total,
      ),
    );
  }

  @override
  Future<Result<Product, AppFailure>> createProduct(ProductDraft draft) async {
    final res = await _api.createProduct(_draftToJson(draft));
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Product, AppFailure>> updateProduct(
    String id,
    ProductDraft draft,
  ) async {
    final res = await _api.updateProduct(id, _draftToJson(draft));
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<DeleteProductResult, AppFailure>> deleteProduct(String id) async {
    final res = await _api.deleteProduct(id);
    return res.map(
      (o) => DeleteProductResult(deleted: o.deleted, archived: o.archived),
    );
  }

  @override
  Future<Result<Product, AppFailure>> restoreProduct(String id) async {
    final res = await _api.restoreProduct(id);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Product, AppFailure>> setProductVisibility(
    String id, {
    required bool isAvailable,
  }) async {
    final res = await _api.updateProduct(id, {'isAvailable': isAvailable});
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<UploadResult, AppFailure>> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    return _api.uploadImage(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }

  Map<String, dynamic> _draftToJson(ProductDraft d) {
    return {
      'categoryId': d.categoryId,
      'name': d.name,
      'slug': d.slug,
      'description': d.description,
      'basePrice': d.basePrice,
      'images': d.images,
      'tags': d.tags,
      if (d.preparationMinutes != null)
        'preparationMinutes': d.preparationMinutes,
      if (d.isAvailable != null) 'isAvailable': d.isAvailable,
      if (d.isSeasonal != null) 'isSeasonal': d.isSeasonal,
      if (d.seasonStart != null)
        'seasonStart': d.seasonStart!.toUtc().toIso8601String(),
      if (d.seasonEnd != null)
        'seasonEnd': d.seasonEnd!.toUtc().toIso8601String(),
      // Availability rules. Sending an empty array is meaningful — it
      // explicitly clears any previous restriction.
      'leadTimeHours': d.leadTimeHours,
      'availableDaysOfWeek': d.availableDaysOfWeek,
      'dailyMaxQuantity': d.dailyMaxQuantity,
      if (d.flavorPickCount != null) 'flavorPickCount': d.flavorPickCount,
      // Always sent (like availableDaysOfWeek): an empty array explicitly
      // clears a previously-saved flavour list when the composer is turned off.
      'flavorOptions': d.flavorOptions,
      'variants': d.variants
          .map(
            (v) => {
              if (v.id != null) 'id': v.id,
              'size': v.size,
              'flavor': v.flavor,
              'priceDelta': v.priceDelta,
              if (v.stockQty != null) 'stockQty': v.stockQty,
              'isAvailable': v.isAvailable,
            },
          )
          .toList(),
    };
  }
}
