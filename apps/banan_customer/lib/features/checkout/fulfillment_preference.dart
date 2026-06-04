import 'package:banan_domain/banan_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-scoped Pickup vs Delivery choice.
///
/// The customer picks this up-front on the menu screen; it persists across
/// navigation (browsing, product detail, cart) for the whole app session
/// and pre-selects the fulfillment option at checkout. Defaults to pickup.
///
/// In-memory only — a fresh page load resets to the default, which is the
/// desired behaviour for a kiosk-style ordering flow.
final fulfillmentPreferenceProvider =
    StateProvider<FulfillmentType>((ref) => FulfillmentType.pickup);
