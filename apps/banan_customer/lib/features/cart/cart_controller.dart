import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class CartItem {
  const CartItem({
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantLabel,
    required this.unitPrice,
    required this.quantity,
    this.coverImage,
    this.customMessage,
    this.personalization,
    this.isBirthdayCake = false,
    this.leadTimeHours,
    this.availableDaysOfWeek = const [],
  });

  final String productId;
  final String variantId;
  final String productName;
  final String variantLabel;
  final String? coverImage;
  final double unitPrice;
  final int quantity;
  final String? customMessage;

  /// Advance-notice (in hours) this product needs before it can be picked up
  /// / delivered — mirrors `Product.leadTimeHours`. Null / 0 = available
  /// right away. The cart uses the max across all lines to warn the customer
  /// and default the schedule to the earliest valid time, matching the
  /// backend's PRODUCT_LEAD_TIME guard so they never hit a rejected order.
  final int? leadTimeHours;

  /// Days of week (0=Sun..6=Sat) this product is sold — mirrors
  /// `Product.availableDaysOfWeek`. Empty = sold every day. The cart
  /// intersects these across all lines so the schedule picker can disable
  /// days the order can't be fulfilled, matching the backend's
  /// ORDER_ITEMS_TIMELINE (DAY_UNAVAILABLE) guard.
  final List<int> availableDaysOfWeek;

  /// Cake personalization payload from the customer wizard (text on
  /// cake, candle count, reference image URL, note). Null for items
  /// that aren't birthday cakes or weren't customised.
  final Map<String, dynamic>? personalization;

  /// True when this line is a birthday-collection cake. Lets the cart
  /// surface the "Cá nhân hoá / Sửa" wizard button on the row even when
  /// the customer added it quickly without customising. Defaults false.
  final bool isBirthdayCake;

  /// Cart-key must vary by personalization so two configurations of the
  /// same product don't collapse into one line.
  String get key {
    if (personalization == null || personalization!.isEmpty) {
      return '$productId:$variantId';
    }
    // Stable hash of the personalization payload — same order ↔ same key.
    final sorted = (personalization!.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}=${e.value}')
        .join('|');
    return '$productId:$variantId:${sorted.hashCode}';
  }

  double get lineTotal => unitPrice * quantity;

  CartItem copyWith({int? quantity, String? customMessage}) => CartItem(
        productId: productId,
        variantId: variantId,
        productName: productName,
        variantLabel: variantLabel,
        coverImage: coverImage,
        unitPrice: unitPrice,
        quantity: quantity ?? this.quantity,
        customMessage: customMessage ?? this.customMessage,
        personalization: personalization,
        isBirthdayCake: isBirthdayCake,
        leadTimeHours: leadTimeHours,
        availableDaysOfWeek: availableDaysOfWeek,
      );

  /// Returns a copy carrying a different personalization payload. Empty or
  /// null payloads normalise to null so the cart key collapses back to the
  /// plain `productId:variantId` form. Used by the cart's edit-cake flow.
  CartItem withPersonalization(Map<String, dynamic>? next) => CartItem(
        productId: productId,
        variantId: variantId,
        productName: productName,
        variantLabel: variantLabel,
        coverImage: coverImage,
        unitPrice: unitPrice,
        quantity: quantity,
        customMessage: customMessage,
        isBirthdayCake: isBirthdayCake,
        leadTimeHours: leadTimeHours,
        availableDaysOfWeek: availableDaysOfWeek,
        personalization: (next == null || next.isEmpty) ? null : next,
      );
}

@immutable
class CartState {
  const CartState({this.items = const []});
  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);

  /// The largest advance-notice (in hours) any line in the cart needs before
  /// it can be ready. 0 = everything is available right away.
  int get maxLeadHours => items.fold(
        0,
        (m, i) => (i.leadTimeHours ?? 0) > m ? (i.leadTimeHours ?? 0) : m,
      );

  /// Distinct product names that need advance notice — used to tell the
  /// customer exactly which cakes require preparation time.
  List<String> get leadProductNames => <String>{
        for (final i in items)
          if ((i.leadTimeHours ?? 0) > 0) i.productName,
      }.toList();

  /// Days of week (0=Sun..6=Sat) on which the WHOLE cart can be fulfilled —
  /// the intersection of every line's day constraint. Unconstrained lines
  /// (empty list) don't narrow it. Returns all 7 days when nothing is
  /// constrained. May be empty when constraints conflict (no single day works
  /// for every cake) — callers should treat empty as "don't restrict" and let
  /// the per-line badges + backend guard surface the conflict.
  List<int> get allowedDaysOfWeek {
    final constrained = [
      for (final i in items)
        if (i.availableDaysOfWeek.isNotEmpty) i.availableDaysOfWeek,
    ];
    if (constrained.isEmpty) return const [0, 1, 2, 3, 4, 5, 6];
    return [
      for (var d = 0; d <= 6; d++)
        if (constrained.every((days) => days.contains(d))) d,
    ];
  }

  /// Distinct names of cakes that are only sold on certain days — used to tell
  /// the customer which items drive the day restriction.
  List<String> get dayConstrainedNames => <String>{
        for (final i in items)
          if (i.availableDaysOfWeek.isNotEmpty) i.productName,
      }.toList();

  /// True when day constraints CONFLICT — some items are day-restricted yet no
  /// single day works for all of them ([allowedDaysOfWeek] is empty). The order
  /// can't be fulfilled in one go; the customer must drop some items. Distinct
  /// from "unconstrained" (which yields all 7 days), so the UI can warn instead
  /// of silently treating it as "any day".
  bool get hasDayConflict {
    final anyConstrained =
        items.any((i) => i.availableDaysOfWeek.isNotEmpty);
    return anyConstrained && allowedDaysOfWeek.isEmpty;
  }
}

/// In-memory cart. Lost on app refresh / restart — Hive persistence lands
/// alongside offline mode in the hardening milestone.
class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState());

  void add(CartItem item) {
    final idx = state.items.indexWhere((i) => i.key == item.key);
    if (idx >= 0) {
      final updated = [...state.items];
      updated[idx] = updated[idx]
          .copyWith(quantity: updated[idx].quantity + item.quantity);
      state = CartState(items: updated);
    } else {
      state = CartState(items: [...state.items, item]);
    }
  }

  void setQuantity(String key, int qty) {
    if (qty <= 0) {
      remove(key);
      return;
    }
    state = CartState(
      items: [
        for (final item in state.items)
          if (item.key == key) item.copyWith(quantity: qty) else item,
      ],
    );
  }

  void remove(String key) {
    state = CartState(
      items: state.items.where((i) => i.key != key).toList(),
    );
  }

  /// Removes every line for any of [productIds] — used by checkout's "remove
  /// the cakes that don't fit the timeline" action. No-op for ids not in cart.
  void removeProducts(Set<String> productIds) {
    state = CartState(
      items:
          state.items.where((i) => !productIds.contains(i.productId)).toList(),
    );
  }

  /// Replaces the personalization on the line at [key]. Because the cart
  /// key is derived from the personalization payload, the line is removed
  /// and re-inserted under its new key — merging into an identical
  /// configuration if one already exists, otherwise staying in place.
  void setPersonalization(String key, Map<String, dynamic>? personalization) {
    final idx = state.items.indexWhere((i) => i.key == key);
    if (idx < 0) return;
    final updated = state.items[idx].withPersonalization(personalization);
    final rest = [...state.items]..removeAt(idx);
    final mergeIdx = rest.indexWhere((i) => i.key == updated.key);
    if (mergeIdx >= 0) {
      rest[mergeIdx] = rest[mergeIdx]
          .copyWith(quantity: rest[mergeIdx].quantity + updated.quantity);
      state = CartState(items: rest);
    } else {
      rest.insert(idx, updated);
      state = CartState(items: rest);
    }
  }

  void clear() => state = const CartState();

  /// One-tap reorder — adds every line from a past order back into the
  /// cart. Items are merged by key, so reordering twice doubles the
  /// quantity instead of duplicating rows. Skips lines missing a variant
  /// (defensive; should never happen on a real order).
  ///
  /// Returns the number of distinct lines that were added.
  int reorder({
    required List<({
      String productId,
      String? variantId,
      String productName,
      String? variantLabel,
      double unitPrice,
      int quantity,
      String? customMessage,
      Map<String, dynamic>? personalization,
    })> items,
  }) {
    var added = 0;
    for (final i in items) {
      if (i.variantId == null) continue;
      add(
        CartItem(
          productId: i.productId,
          variantId: i.variantId!,
          productName: i.productName,
          variantLabel: i.variantLabel ?? '',
          unitPrice: i.unitPrice,
          quantity: i.quantity,
          customMessage: i.customMessage,
          personalization: i.personalization,
        ),
      );
      added++;
    }
    return added;
  }
}

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>((ref) {
  return CartController();
});
