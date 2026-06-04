import 'package:banan_core/banan_core.dart';

import '../entities/store.dart';

abstract class StoresRepository {
  /// Public — every active branch the chain operates.
  Future<Result<List<Store>, AppFailure>> list();
}
