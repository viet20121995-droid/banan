import 'package:banan_core/banan_core.dart';

import '../entities/store.dart';

/// Admin input for creating / editing a branch's identity. Operational settings
/// (opening hours, pause flags, min-order, lead time) are tuned separately via
/// the store-settings screen. `toJson` matches `POST /admin/stores` and
/// `PATCH /admin/stores/:id`.
///
/// `defaultKitchenId` is always emitted (a value assigns the default kitchen,
/// `null` detaches it). `wardCode` is emitted as a (possibly empty) string —
/// the backend stores an empty value as `null`.
class StoreDraft {
  const StoreDraft({
    required this.name,
    required this.slug,
    required this.address,
    required this.phone,
    this.wardCode,
    this.defaultKitchenId,
    this.lat,
    this.lng,
  });

  final String name;
  final String slug;
  final String address;
  final String phone;
  final String? wardCode;
  final String? defaultKitchenId;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        'address': address,
        'phone': phone,
        'wardCode': wardCode ?? '',
        'defaultKitchenId': defaultKitchenId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

abstract class StoresRepository {
  /// Public — every active branch the chain operates (customer pickup picker).
  Future<Result<List<Store>, AppFailure>> list();

  /// Admin — full branch list (all identity fields) for the management screen.
  Future<Result<List<Store>, AppFailure>> listForAdmin();

  Future<Result<Store, AppFailure>> create(StoreDraft draft);
  Future<Result<Store, AppFailure>> update(String id, StoreDraft draft);
  Future<Result<void, AppFailure>> delete(String id);
}
