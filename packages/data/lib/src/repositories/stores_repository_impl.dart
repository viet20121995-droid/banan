import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/stores_api.dart';

class StoresRepositoryImpl implements StoresRepository {
  StoresRepositoryImpl(this._api);
  final StoresApi _api;

  @override
  Future<Result<List<Store>, AppFailure>> list() async {
    final res = await _api.list();
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<List<Store>, AppFailure>> listForAdmin() async {
    final res = await _api.listForAdmin();
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<Store, AppFailure>> create(StoreDraft draft) async {
    final res = await _api.create(draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Store, AppFailure>> update(String id, StoreDraft draft) async {
    final res = await _api.update(id, draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<void, AppFailure>> delete(String id) => _api.delete(id);
}
