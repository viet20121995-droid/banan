import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart' as domain;

import '../api/threads_api.dart';

class ThreadsRepositoryImpl implements domain.ThreadsRepository {
  ThreadsRepositoryImpl(this._api);
  final ThreadsApi _api;

  @override
  Future<Result<List<domain.Thread>, AppFailure>> published({
    String? storeId,
    int limit = 10,
  }) async {
    final res = await _api.published(storeId: storeId, limit: limit);
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<List<domain.Thread>, AppFailure>> storeThreads() async {
    final res = await _api.store();
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<domain.Thread, AppFailure>> get(String id) async {
    final res = await _api.get(id);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<domain.Thread, AppFailure>> create(domain.ThreadDraft draft) async {
    final res = await _api.create(draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<domain.Thread, AppFailure>> update(
    String id,
    domain.ThreadDraft draft,
  ) async {
    final res = await _api.update(id, draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<void, AppFailure>> delete(String id) => _api.delete(id);
}
