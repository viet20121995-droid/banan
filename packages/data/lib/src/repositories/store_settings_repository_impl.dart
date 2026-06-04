import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/store_settings_api.dart';

class StoreSettingsRepositoryImpl implements StoreSettingsRepository {
  StoreSettingsRepositoryImpl(this._api);
  final StoreSettingsApi _api;

  @override
  Future<Result<StoreSettings, AppFailure>> getSettings() async {
    final res = await _api.getSettings();
    return res.map((dto) => dto.toDomain());
  }

  @override
  Future<Result<StoreSettings, AppFailure>> updateSettings(
    StoreSettingsPatch patch,
  ) async {
    final res = await _api.updateSettings(patch.toJson());
    return res.map((dto) => dto.toDomain());
  }

  @override
  Future<Result<List<StoreBlackoutDate>, AppFailure>> listBlackouts() async {
    final res = await _api.listBlackouts();
    return res.map((list) => list.map((d) => d.toDomain()).toList());
  }

  @override
  Future<Result<StoreBlackoutDate, AppFailure>> addBlackout({
    required String isoDate,
    String? reason,
  }) async {
    final res = await _api.addBlackout(isoDate: isoDate, reason: reason);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<int, AppFailure>> addBlackoutsBulk(
    List<({String isoDate, String? reason})> rows,
  ) =>
      _api.addBlackoutsBulk(rows);

  @override
  Future<Result<void, AppFailure>> removeBlackout(String id) =>
      _api.removeBlackout(id);
}
