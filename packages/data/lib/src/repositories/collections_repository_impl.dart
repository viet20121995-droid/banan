import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/collections_api.dart';

class CollectionsRepositoryImpl implements CollectionsRepository {
  CollectionsRepositoryImpl(this._api);
  final CollectionsApi _api;

  @override
  Future<Result<List<Collection>, AppFailure>> homeCollections({
    String? storeId,
  }) async {
    final res = await _api.home(storeId: storeId);
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<List<Collection>, AppFailure>> storeCollections() async {
    final res = await _api.store();
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<Collection, AppFailure>> get(String id) async {
    final res = await _api.get(id);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Collection, AppFailure>> create(CollectionDraft draft) async {
    final res = await _api.create(draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Collection, AppFailure>> update(
    String id,
    CollectionDraft draft,
  ) async {
    final res = await _api.update(id, draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<void, AppFailure>> delete(String id) => _api.delete(id);
}
