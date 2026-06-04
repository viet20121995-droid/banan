import 'package:equatable/equatable.dart';

class Address extends Equatable {
  const Address({
    required this.id,
    required this.label,
    required this.recipient,
    required this.phone,
    required this.line1,
    required this.city,
    this.line2,
    this.district,
    this.wardCode,
    this.wardName,
    this.postalCode,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String recipient;
  final String phone;
  final String line1;
  final String? line2;
  final String city;

  /// Legacy district label — kept for pre-HCMC-reform addresses.
  final String? district;

  /// HCMC ward catalog code (post-2025 reform). Drives the delivery
  /// distance check on the backend.
  final String? wardCode;

  /// Display name of the ward (resolved client-side from the catalog when
  /// `wardCode` is set). Persisted to the entity so list views don't need
  /// a second lookup.
  final String? wardName;

  final String? postalCode;
  final bool isDefault;

  String get oneLine {
    final parts = <String>[
      line1,
      if (line2 != null && line2!.isNotEmpty) line2!,
      if (wardName != null && wardName!.isNotEmpty) wardName!,
      if (district != null && district!.isNotEmpty) district!,
      city,
    ];
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [
        id,
        label,
        recipient,
        phone,
        line1,
        line2,
        city,
        district,
        wardCode,
        wardName,
        postalCode,
        isDefault,
      ];
}

/// Lightweight catalog entry returned by `GET /geo/hcm-wards`. The customer
/// app caches this for the session and renders it as the ward dropdown
/// during checkout / address-book editing.
class HcmWard extends Equatable {
  const HcmWard({
    required this.code,
    required this.name,
    required this.lat,
    required this.lng,
    this.oldArea,
  });

  final String code;
  final String name;
  final double lat;
  final double lng;

  /// Pre-reform district hint ("Q1", "Bình Thạnh", …) — purely informational
  /// for the dropdown so customers can find their ward by old district.
  final String? oldArea;

  @override
  List<Object?> get props => [code, name, lat, lng, oldArea];
}

/// Lightweight summary of the branch the backend picked to fulfill a
/// delivery — surfaced to the checkout so the customer can see exactly
/// which Banan store will be serving them.
class RoutedStore extends Equatable {
  const RoutedStore({
    required this.id,
    required this.name,
    required this.address,
  });

  final String id;
  final String name;
  final String address;

  @override
  List<Object?> get props => [id, name, address];
}

/// Which fee tier the backend applied. Mirrors the union in the API
/// response — drives the "Bánh sinh nhật" badge in the checkout breakdown.
enum DeliveryFeeTier { standard, birthdayCake }

/// Ward equality between customer and routed store. Drives the new
/// "Cùng phường / Phường khác" copy in the checkout breakdown.
enum DeliveryWardMatch { same, other }

/// Live quote shape returned by `POST /geo/delivery-quote`. The checkout
/// summary uses this to render "Phí giao hàng" with a per-tier breakdown.
class DeliveryQuote extends Equatable {
  const DeliveryQuote({
    required this.totalVnd,
    required this.wardKnown,
    required this.tier,
    required this.wardMatch,
    required this.hasBirthdayCake,
    this.distanceKm,
    this.store,
    this.noStoreAvailable = false,
  });

  /// Final delivery fee in ₫ (already applies tier + ward match).
  final int totalVnd;

  /// Distance from store to ward centroid (km) — informational display
  /// only; the fee math is now ward-equality based, not distance.
  final double? distanceKm;
  final bool wardKnown;

  /// Tier used to compute the fee.
  final DeliveryFeeTier tier;

  /// Same ward as the routed store, or different ward.
  final DeliveryWardMatch wardMatch;

  /// True if any cart item is in the birthday-cake collection.
  final bool hasBirthdayCake;

  /// Nearest open Banan branch — drives "Giao từ: <name>" on the checkout
  /// and is sent back as `deliveryStoreId` when the order is placed.
  final RoutedStore? store;

  /// True when no branch can deliver (all paused or missing coords).
  final bool noStoreAvailable;

  bool get isOtherWard => wardMatch == DeliveryWardMatch.other;

  @override
  List<Object?> get props => [
        totalVnd,
        distanceKm,
        wardKnown,
        tier,
        wardMatch,
        hasBirthdayCake,
        store,
        noStoreAvailable,
      ];
}

/// Admin-tunable config returned by `GET /geo/delivery-config`. Mirrors the
/// `DeliveryConfig` table column-for-column.
///
/// Pricing rule (2026-05): fee depends on whether the customer's ward
/// matches the routed store's ward. Distance is no longer used.
class DeliveryConfig extends Equatable {
  const DeliveryConfig({
    required this.standardFeeSameWardVnd,
    required this.standardFeeOtherWardVnd,
    required this.birthdayCakeFeeSameWardVnd,
    required this.birthdayCakeFeeOtherWardVnd,
    required this.birthdayCakeCollectionSlug,
  });

  /// Standard products, customer ward == store ward (often free).
  final int standardFeeSameWardVnd;

  /// Standard products, customer ward differs from store ward.
  final int standardFeeOtherWardVnd;

  /// Birthday cakes, same ward.
  final int birthdayCakeFeeSameWardVnd;

  /// Birthday cakes, different ward.
  final int birthdayCakeFeeOtherWardVnd;

  final String birthdayCakeCollectionSlug;

  @override
  List<Object?> get props => [
        standardFeeSameWardVnd,
        standardFeeOtherWardVnd,
        birthdayCakeFeeSameWardVnd,
        birthdayCakeFeeOtherWardVnd,
        birthdayCakeCollectionSlug,
      ];
}
