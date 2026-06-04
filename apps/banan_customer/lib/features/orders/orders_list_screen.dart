import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../cart/cart_controller.dart';
import 'order_status_visuals.dart';

final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  // Refresh on any realtime event we care about — list is small enough that
  // a full refetch is cheaper than diffing in place.
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (event.event == 'order.created' ||
          event.event == 'order.status_changed') {
        ref.invalidateSelf();
      }
    });
  });

  final repo = ref.watch(orderRepositoryProvider);
  final result = await repo.myOrders();
  return result.when(
    success: (page) => page.items,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider);
    final s = ref.watch(stringsProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.myOrders)),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myOrdersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return EmptyState(
              title: s.noOrdersTitle,
              message: s.noOrdersMsg,
              icon: Icons.receipt_long_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myOrdersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(BananSpacing.lg),
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.md),
              itemBuilder: (context, i) {
                final o = orders[i];
                return _OrderRow(
                  order: o,
                  fmt: fmt,
                  onTap: () => context.push('/orders/${o.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  const _OrderRow({
    required this.order,
    required this.fmt,
    required this.onTap,
  });

  final Order order;
  final NumberFormat fmt;
  final VoidCallback onTap;

  void _reorder(BuildContext context, WidgetRef ref, Order order) {
    final added = ref.read(cartControllerProvider.notifier).reorder(
          items: [
            for (final i in order.items)
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
    // Snackbar would otherwise linger across the navigation push and
    // overlap the cart's bottom bar. Clear pending then go.
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã thêm $added món vào giỏ hàng.'),
          duration: const Duration(seconds: 2),
        ),
      );
    context.push('/cart');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    return InkWell(
      onTap: onTap,
      borderRadius: BananRadii.rlg,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rlg,
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          children: [
            Icon(
              order.fulfillmentType == FulfillmentType.delivery
                  ? Icons.delivery_dining_outlined
                  : Icons.storefront_outlined,
              size: 28,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.code, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} · ${fmt.format(order.total)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  label: s.orderStatusLabel(order.status),
                  intent: intentForStatus(order.status),
                  dense: true,
                ),
                const SizedBox(height: 4),
                // One-tap reorder — adds items to cart + jumps to /cart
                // without leaving the list.
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Đặt lại', style: TextStyle(fontSize: 12)),
                  onPressed: () => _reorder(context, ref, order),
                ),
              ],
            ),
            const SizedBox(width: BananSpacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
