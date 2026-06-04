import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/addresses_api.dart';

class AddressesRepositoryImpl implements AddressesRepository {
  AddressesRepositoryImpl(this._api);
  final AddressesApi _api;

  @override
  Future<Result<List<Address>, AppFailure>> list() async {
    final res = await _api.list();
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<Address, AppFailure>> create(AddressDraft draft) async {
    final res = await _api.create(draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Address, AppFailure>> update(
    String id,
    AddressDraft draft,
  ) async {
    final res = await _api.update(id, draft.toJson());
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Address, AppFailure>> setDefault(String id) async {
    final res = await _api.setDefault(id);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<void, AppFailure>> delete(String id) => _api.delete(id);
}
