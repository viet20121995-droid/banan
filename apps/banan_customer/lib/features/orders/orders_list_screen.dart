import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myOrdersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              title: 'No orders yet',
              message: 'Your cake adventures will appear here.',
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

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.fmt,
    required this.onTap,
  });

  final Order order;
  final NumberFormat fmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            StatusBadge(
              label: order.status.label,
              intent: intentForStatus(order.status),
              dense: true,
            ),
            const SizedBox(width: BananSpacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
