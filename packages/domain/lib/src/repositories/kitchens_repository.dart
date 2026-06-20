import 'package:banan_core/banan_core.dart';

import '../entities/kitchen.dart';

/// Admin input for creating / editing a kitchen. `toJson` matches the
/// `POST /admin/kitchens` and `PATCH /admin/kitchens/:id` body contract.
class KitchenDraft {
  const KitchenDraft({
    required this.name,
    required this.address,
    this.capacityPerHour = 40,
  });

  final String name;
  final String address;
  final int capacityPerHour;

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'capacityPerHour': capacityPerHour,
      };
}

/// Chain kitchens — admin-only CRUD. There is no public kitchen listing;
/// everything goes through the `/admin/kitchens` surface (ADMIN-gated).
abstract class KitchensRepository {
  Future<Result<List<Kitchen>, AppFailure>> list();
  Future<Result<Kitchen, AppFailure>> create(KitchenDraft draft);
  Future<Result<Kitchen, AppFailure>> update(String id, KitchenDraft draft);
  Future<Result<void, AppFailure>> delete(String id);
}
