import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/kitchens_api.dart';

class KitchensRepositoryImpl implements KitchensRepository {
  KitchensRepositoryImpl(this._api);
  final KitchensApi _api;

  @override
  Future<Result<List<Kitchen>, AppFailure>> list() async {
    final res = await _api.list();
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<Kitchen, AppFailure>> create(KitchenDraft draft) async {
    final res = await _api.create(draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Kitchen, AppFailure>> update(String id, KitchenDraft draft) async {
    final res = await _api.update(id, draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<void, AppFailure>> delete(String id) => _api.delete(id);
}
