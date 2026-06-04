import 'package:banan_core/banan_core.dart';

import '../entities/store.dart';

/// Patch shape for `PATCH /merchant/store/settings`. Every field is optional;
/// only the keys present in the map are sent to the backend.
class StoreSettingsPatch {
  StoreSettingsPatch({
    this.isPaused,
    this.isPickupPaused,
    this.isDeliveryPaused,
    this.pauseReason,
    this.minOrderVnd,
    this.defaultLeadHours,
    this.openingHours,
  });

  bool? isPaused;
  bool? isPickupPaused;
  bool? isDeliveryPaused;

  /// Pass an empty string to clear the saved reason on the backend.
  String? pauseReason;
  int? minOrderVnd;
  int? defaultLeadHours;
  Map<String, List<List<String>>>? openingHours;

  Map<String, Object?> toJson() {
    return {
      if (isPaused != null) 'isPaused': isPaused,
      if (isPickupPaused != null) 'isPickupPaused': isPickupPaused,
      if (isDeliveryPaused != null) 'isDeliveryPaused': isDeliveryPaused,
      if (pauseReason != null) 'pauseReason': pauseReason,
      if (minOrderVnd != null) 'minOrderVnd': minOrderVnd,
      if (defaultLeadHours != null) 'defaultLeadHours': defaultLeadHours,
      if (openingHours != null) 'openingHours': openingHours,
    };
  }
}

/// Merchant-facing settings + blackout calendar for the caller's store.
abstract class StoreSettingsRepository {
  Future<Result<StoreSettings, AppFailure>> getSettings();

  Future<Result<StoreSettings, AppFailure>> updateSettings(
    StoreSettingsPatch patch,
  );

  Future<Result<List<StoreBlackoutDate>, AppFailure>> listBlackouts();

  /// `isoDate` is YYYY-MM-DD in the store's local calendar.
  Future<Result<StoreBlackoutDate, AppFailure>> addBlackout({
    required String isoDate,
    String? reason,
  });

  /// Returns the number of dates that were newly inserted (duplicates skipped).
  Future<Result<int, AppFailure>> addBlackoutsBulk(
    List<({String isoDate, String? reason})> rows,
  );

  Future<Result<void, AppFailure>> removeBlackout(String id);
}
