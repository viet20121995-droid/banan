import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fulfillment_preference.dart';

/// In-progress fulfillment choices the customer makes on the Toast-style cart
/// screen, carried forward so checkout can pre-fill them instead of asking
/// twice. In-memory only (like the cart itself) — a page refresh resets it,
/// which is fine for the kiosk-style flow.
@immutable
class OrderDraft {
  const OrderDraft({
    required this.fulfillment,
    this.pickupStoreId,
    this.deliveryAddressId,
    this.scheduledFor,
  });

  final FulfillmentType fulfillment;

  /// Branch chosen for PICKUP. Null until the picker auto-selects one.
  final String? pickupStoreId;

  /// Id of the saved address chosen for DELIVERY (logged-in customers only).
  /// Null = none picked yet / guest who'll type one at checkout.
  final String? deliveryAddressId;

  /// `null` = ASAP. Otherwise the customer-chosen pickup / delivery moment.
  final DateTime? scheduledFor;

  OrderDraft copyWith({
    FulfillmentType? fulfillment,
    String? pickupStoreId,
    bool clearPickupStoreId = false,
    String? deliveryAddressId,
    bool clearDeliveryAddressId = false,
    DateTime? scheduledFor,
    bool clearScheduledFor = false,
  }) {
    return OrderDraft(
      fulfillment: fulfillment ?? this.fulfillment,
      pickupStoreId:
          clearPickupStoreId ? null : (pickupStoreId ?? this.pickupStoreId),
      deliveryAddressId: clearDeliveryAddressId
          ? null
          : (deliveryAddressId ?? this.deliveryAddressId),
      scheduledFor:
          clearScheduledFor ? null : (scheduledFor ?? this.scheduledFor),
    );
  }
}

class OrderDraftController extends StateNotifier<OrderDraft> {
  OrderDraftController(FulfillmentType initial)
      : super(OrderDraft(fulfillment: initial));

  void setFulfillment(FulfillmentType value) =>
      state = state.copyWith(fulfillment: value);

  void setPickupStoreId(String? value) => state = value == null
      ? state.copyWith(clearPickupStoreId: true)
      : state.copyWith(pickupStoreId: value);

  void setDeliveryAddressId(String? value) => state = value == null
      ? state.copyWith(clearDeliveryAddressId: true)
      : state.copyWith(deliveryAddressId: value);

  void setScheduledFor(DateTime? value) => state = value == null
      ? state.copyWith(clearScheduledFor: true)
      : state.copyWith(scheduledFor: value);
}

/// Shared order draft. Seeded from the session-wide pickup/delivery
/// preference so the cart's fulfillment toggle starts on the same choice the
/// customer made on the menu.
final orderDraftProvider =
    StateNotifierProvider<OrderDraftController, OrderDraft>((ref) {
  return OrderDraftController(ref.read(fulfillmentPreferenceProvider));
});
