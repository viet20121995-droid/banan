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
  });

  final String productId;
  final String variantId;
  final String productName;
  final String variantLabel;
  final String? coverImage;
  final double unitPrice;
  final int quantity;
  final String? customMessage;

  String get key => '$productId:$variantId';
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
      );
}

@immutable
class CartState {
  const CartState({this.items = const []});
  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);
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

  void clear() => state = const CartState();
}

final cartControllerProvider =
    StateNotifierProvider<CartController, CartState>((ref) {
  return CartController();
});
