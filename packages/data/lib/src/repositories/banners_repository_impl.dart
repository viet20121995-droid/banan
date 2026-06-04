import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/banners_api.dart';

class BannersRepositoryImpl implements BannersRepository {
  BannersRepositoryImpl(this._api);
  final BannersApi _api;

  @override
  Future<Result<List<HomeBanner>, AppFailure>> publicList() async {
    final res = await _api.publicList();
    return res.map((l) => l.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<List<HomeBanner>, AppFailure>> list() async {
    final res = await _api.list();
    return res.map((l) => l.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<HomeBanner, AppFailure>> create(BannerDraft draft) async {
    final res = await _api.create(draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<HomeBanner, AppFailure>> update(
    String id, {
    String? imageUrl,
    String? title,
    String? ctaUrl,
    int? sortOrder,
    bool? isActive,
  }) async {
    final res = await _api.update(id, {
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (title != null) 'title': title,
      if (ctaUrl != null) 'ctaUrl': ctaUrl,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (isActive != null) 'isActive': isActive,
    });
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<void, AppFailure>> delete(String id) => _api.delete(id);
}
