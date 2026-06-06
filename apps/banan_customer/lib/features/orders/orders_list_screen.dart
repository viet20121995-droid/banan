import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'order_status_visuals.dart';
import 'reorder_helper.dart';

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

/// Client-side status filter for the orders list. "Đang xử lý" = any
/// non-terminal status; "Hoàn thành" = COMPLETED; "Đã hủy" = CANCELLED.
enum _OrderFilter {
  all('Tất cả'),
  processing('Đang xử lý'),
  completed('Hoàn thành'),
  cancelled('Đã hủy');

  const _OrderFilter(this.label);
  final String label;

  bool matches(OrderStatus status) {
    switch (this) {
      case _OrderFilter.all:
        return true;
      case _OrderFilter.completed:
        return status == OrderStatus.completed;
      case _OrderFilter.cancelled:
        return status == OrderStatus.cancelled;
      case _OrderFilter.processing:
        // Everything that isn't completed or cancelled (incl. refunded,
        // pending, accepted, in-prep, delivering, …) counts as "in progress".
        return status != OrderStatus.completed &&
            status != OrderStatus.cancelled;
    }
  }
}

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  _OrderFilter _filter = _OrderFilter.all;

  @override
  Widget build(BuildContext context) {
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
          final filtered =
              orders.where((o) => _filter.matches(o.status)).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myOrdersProvider),
            child: Column(
              children: [
                _FilterChips(
                  selected: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                Expanded(
                  child: filtered.isEmpty
                      // Keep the list scrollable so pull-to-refresh still works
                      // even when the active filter has no matching orders.
                      ? ListView(
                          children: [
                            const SizedBox(height: BananSpacing.xxl),
                            EmptyState(
                              title: 'Không có đơn',
                              message:
                                  'Không có đơn hàng nào ở mục "${_filter.label}".',
                              icon: Icons.filter_list_off_outlined,
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(BananSpacing.lg),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: BananSpacing.md),
                          itemBuilder: (context, i) {
                            final o = filtered[i];
                            return _OrderRow(
                              order: o,
                              fmt: fmt,
                              onTap: () => context.push('/orders/${o.id}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Horizontally-scrolling status filter chips above the orders list.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final _OrderFilter selected;
  final ValueChanged<_OrderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.lg,
        vertical: BananSpacing.sm,
      ),
      child: Row(
        children: [
          for (final f in _OrderFilter.values) ...[
            ChoiceChip(
              label: Text(f.label),
              selected: selected == f,
              onSelected: (_) => onChanged(f),
            ),
            if (f != _OrderFilter.values.last)
              const SizedBox(width: BananSpacing.sm),
          ],
        ],
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
                  onPressed: () => reorderOrder(context, ref, order),
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
