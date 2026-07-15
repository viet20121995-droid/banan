import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../cart/cart_controller.dart';

/// The customer's ~5 most recent orders, used to power the storefront
/// "Đặt lại / Order Again" strip. Returns an empty list for guests (so the
/// section hides itself) and on any error — this surface is best-effort and
/// should never block the home page.
final recentOrdersProvider =
    FutureProvider.autoDispose<List<Order>>((ref) async {
  // Guests have no order history — bail out immediately so the section
  // collapses instead of hitting an endpoint that would 401.
  final session = ref.watch(authRepositoryProvider).currentSession ??
      ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return const <Order>[];

  // Refetch when a new order is placed so a fresh order shows up at the
  // top of the strip without a manual reload.
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (event.event == 'order.created') {
        ref.invalidateSelf();
      }
    });
  });

  final repo = ref.watch(orderRepositoryProvider);
  final result = await repo.myOrders(perPage: 5);
  return result.when(
    success: (page) => page.items,
    // Swallow failures: the strip is optional, never a hard error surface.
    failure: (_) => const <Order>[],
  );
});

/// Current menu products keyed by id, used to check whether each line of a
/// past order is still orderable before reordering. Built from the public
/// catalog so the lookup is independent of any active category/search filter
/// on the menu screen. Empty map (treat everything as unavailable) on error.
final _menuProductsByIdProvider =
    FutureProvider.autoDispose<Map<String, Product>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final res = await repo.products(perPage: 200);
  return res.when(
    success: (page) => {for (final p in page.items) p.id: p},
    failure: (_) => const <String, Product>{},
  );
});

/// ChowNow-style, availability-aware reorder. Looks up every line of [order]
/// in the current menu and only re-adds items whose product still exists,
/// is available and is not sold out. Shows a Vietnamese SnackBar summarising
/// the result and navigates to /cart when at least one item was added.
///
/// Shared by the storefront "Đặt lại" cards and the orders list / detail
/// screens so reorder behaves identically everywhere.
Future<void> reorderOrder(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  // Resolve the current menu so we can filter out anything no longer for
  // sale. `.future` so we always reorder against fresh availability even if
  // the provider hasn't been read yet on this screen.
  Map<String, Product> menu;
  try {
    menu = await ref.read(_menuProductsByIdProvider.future);
  } catch (_) {
    menu = const <String, Product>{};
  }
  if (!context.mounted) return;

  final available = <OrderItem>[];
  var skipped = 0;
  for (final item in order.items) {
    final product = menu[item.productId];
    final orderable =
        product != null && product.isAvailable && !product.isSoldOut;
    if (orderable) {
      available.add(item);
    } else {
      skipped++;
    }
  }

  final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();

  if (available.isEmpty) {
    // Nothing left to add — tell the customer and stay put (no navigation).
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Các món trong đơn này hiện không còn'),
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

  final added = ref.read(cartControllerProvider.notifier).reorder(
        items: [
          for (final i in available)
            (
              productId: i.productId,
              variantId: i.variantId,
              productName: i.productName,
              variantLabel: i.variantLabel,
              unitPrice: i.unitPrice,
              quantity: i.quantity,
              customMessage: i.customMessage,
              personalization: i.personalization,
            ),
        ],
      );

  // `reorder` itself skips any line missing a variantId, so account for
  // those in the "không còn bán" tally too.
  final notAdded = skipped + (available.length - added);

  if (added == 0) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Các món trong đơn này hiện không còn'),
        duration: Duration(seconds: 3),
      ),
    );
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        notAdded == 0
            ? 'Đã thêm $added món vào giỏ'
            : 'Đã thêm $added món · $notAdded món không còn bán',
      ),
      duration: const Duration(seconds: 3),
    ),
  );

  if (!context.mounted) return;
  context.go('/checkout');
}
