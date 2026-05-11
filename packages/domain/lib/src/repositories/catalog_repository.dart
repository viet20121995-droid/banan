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
}

class VariantDraft {
  VariantDraft({
    required this.size, required this.flavor, this.id,
    this.priceDelta = 0,
    this.stockQty,
    this.isAvailable = true,
  });

  /// Present for existing variants; absent for newly added rows.
  String? id;
  String size;
  String flavor;
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

abstract class CatalogRepository {
  Future<Result<List<Category>, AppFailure>> categories();

  /// Public catalog listing — only available products.
  Future<Result<ProductPage, AppFailure>> products({
    String? categoryId,
    String? q,
    bool? seasonal,
    int page = 1,
    int perPage = 20,
  });

  Future<Result<Product, AppFailure>> product(String id);

  /// Merchant view — includes unavailable products. Scoped to caller's store.
  Future<Result<ProductPage, AppFailure>> merchantProducts({
    String? q,
    int page = 1,
    int perPage = 50,
  });

  Future<Result<Product, AppFailure>> createProduct(ProductDraft draft);
  Future<Result<Product, AppFailure>> updateProduct(String id, ProductDraft draft);
  Future<Result<void, AppFailure>> deleteProduct(String id);

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
