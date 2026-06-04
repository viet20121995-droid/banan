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
}
