import 'package:banan_customer/features/cart/cart_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cart decides what the customer is charged, when the order can be made,
/// and which products the delivery quote is priced against. All of it is pure
/// state, so it can be pinned down without a widget in sight.

CartItem _item({
  String productId = 'p1',
  String variantId = 'v1',
  String name = 'Mango Pudding',
  double price = 105000,
  int qty = 1,
  int? leadTimeHours,
  List<int> availableDays = const [],
  bool isBundle = false,
  List<String> bundleProductIds = const [],
  Map<String, dynamic>? personalization,
}) =>
    CartItem(
      productId: productId,
      variantId: variantId,
      productName: name,
      variantLabel: 'M',
      unitPrice: price,
      quantity: qty,
      leadTimeHours: leadTimeHours,
      availableDaysOfWeek: availableDays,
      isBundle: isBundle,
      bundleProductIds: bundleProductIds,
      personalization: personalization,
    );

void main() {
  group('CartState money', () {
    test('subtotal and itemCount sum every line', () {
      final cart = CartState(
        items: [
          _item(price: 105000, qty: 2),
          _item(productId: 'p2', price: 65000, qty: 3),
        ],
      );
      expect(cart.subtotal, 105000 * 2 + 65000 * 3);
      expect(cart.itemCount, 5);
    });

    test('an empty cart is free, not null', () {
      const cart = CartState();
      expect(cart.isEmpty, isTrue);
      expect(cart.subtotal, 0);
      expect(cart.itemCount, 0);
    });
  });

  group('CartState.orderedProductIds', () {
    test('expands a combo into its parts, deduped', () {
      // The delivery quote keys off this. If a combo reported only its own
      // bundle id, a birthday cake hidden inside it would be quoted at the
      // standard tier and under-charge against what the backend bills.
      final cart = CartState(
        items: [
          _item(productId: 'bundle1', isBundle: true, bundleProductIds: ['a', 'b']),
          _item(productId: 'b'),
        ],
      );
      expect(cart.orderedProductIds, ['a', 'b']);
    });
  });

  group('CartState prep time', () {
    test('takes the longest lead in the cart, ignoring items without one', () {
      final cart = CartState(
        items: [
          _item(),
          _item(productId: 'p2', name: 'Birthday Cake', leadTimeHours: 48),
          _item(productId: 'p3', name: 'Tart', leadTimeHours: 24),
        ],
      );
      expect(cart.maxLeadHours, 48);
      expect(cart.leadProductNames, ['Birthday Cake', 'Tart']);
    });

    test('a cart of same-day items needs no notice', () {
      final cart = CartState(items: [_item(), _item(productId: 'p2')]);
      expect(cart.maxLeadHours, 0);
      expect(cart.leadProductNames, isEmpty);
    });
  });

  group('CartState day constraints', () {
    test('an unconstrained cart allows every day', () {
      final cart = CartState(items: [_item()]);
      expect(cart.allowedDaysOfWeek, [0, 1, 2, 3, 4, 5, 6]);
      expect(cart.hasDayConflict, isFalse);
    });

    test('intersects constraints; unconstrained lines do not narrow', () {
      final cart = CartState(
        items: [
          _item(availableDays: const [1, 2, 3]),
          _item(productId: 'p2', availableDays: const [2, 3, 4]),
          _item(productId: 'p3'),
        ],
      );
      expect(cart.allowedDaysOfWeek, [2, 3]);
      expect(cart.hasDayConflict, isFalse);
    });

    test('conflicting days are a conflict, not "any day"', () {
      // Sat-only + Sun-only. The intersection is empty, which must NOT read as
      // unconstrained — that would let the customer submit an order the backend
      // rejects.
      final cart = CartState(
        items: [
          _item(name: 'Sat cake', availableDays: const [6]),
          _item(productId: 'p2', name: 'Sun cake', availableDays: const [0]),
        ],
      );
      expect(cart.allowedDaysOfWeek, isEmpty);
      expect(cart.hasDayConflict, isTrue);
      expect(cart.dayConstrainedNames, ['Sat cake', 'Sun cake']);
    });
  });

  group('CartController', () {
    test('adding the same variant merges quantity instead of duplicating', () {
      final c = CartController()
        ..add(_item(qty: 2))
        ..add(_item(qty: 3));
      expect(c.state.items.length, 1);
      expect(c.state.items.single.quantity, 5);
    });

    test('different personalization stays a separate line', () {
      final c = CartController()
        ..add(_item(personalization: {'msg': 'Happy Birthday'}))
        ..add(_item(personalization: {'msg': 'Congrats'}));
      expect(c.state.items.length, 2);
    });

    test('personalization key is order-independent', () {
      final a = _item(personalization: {'msg': 'hi', 'color': 'pink'});
      final b = _item(personalization: {'color': 'pink', 'msg': 'hi'});
      expect(a.key, b.key);

      final c = CartController()..add(a)..add(b);
      expect(c.state.items.length, 1, reason: 'same config must merge');
    });

    test('setQuantity(0) removes the line — the checkout stepper relies on it',
        () {
      final item = _item();
      final c = CartController()..add(item);
      c.setQuantity(item.key, 0);
      expect(c.state.isEmpty, isTrue);
    });

    test('setQuantity replaces, never accumulates', () {
      final item = _item(qty: 1);
      final c = CartController()..add(item);
      c.setQuantity(item.key, 4);
      expect(c.state.items.single.quantity, 4);
      expect(c.state.subtotal, 105000 * 4);
    });

    test('removeProducts matches a combo by its constituent ids', () {
      // Checkout's "remove the cakes that don't fit the timeline" gets REAL
      // product ids from the backend; a combo's own id never appears in them.
      final c = CartController()
        ..add(_item(productId: 'bundle1', isBundle: true, bundleProductIds: ['a', 'b']))
        ..add(_item(productId: 'c'));
      c.removeProducts({'a'});
      expect(c.state.items.length, 1);
      expect(c.state.items.single.productId, 'c');
    });

    test('removeProducts ignores ids that are not in the cart', () {
      final c = CartController()..add(_item(productId: 'c'));
      c.removeProducts({'nope'});
      expect(c.state.items.length, 1);
    });

    test('re-personalising into an existing config merges the two lines', () {
      final plain = _item(qty: 1);
      final fancy = _item(qty: 2, personalization: {'msg': 'hi'});
      final c = CartController()..add(plain)..add(fancy);
      expect(c.state.items.length, 2);

      c.setPersonalization(plain.key, {'msg': 'hi'});

      expect(c.state.items.length, 1);
      expect(c.state.items.single.quantity, 3);
    });

    test('clearing empties the cart', () {
      final c = CartController()..add(_item());
      c.clear();
      expect(c.state.isEmpty, isTrue);
    });
  });
}
