import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'order_status_visuals.dart';

@immutable
class StoreOrdersState {
  const StoreOrdersState({
    this.orders = const [],
    this.loading = false,
    this.failure,
    this.statusFilter,
  });

  final List<Order> orders;
  final bool loading;
  final AppFailure? failure;
  final OrderStatus? statusFilter;

  StoreOrdersState copyWith({
    List<Order>? orders,
    bool? loading,
    Object? failure = _sentinel,
    Object? statusFilter = _sentinel,
  }) =>
      StoreOrdersState(
        orders: orders ?? this.orders,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
        statusFilter: statusFilter == _sentinel
            ? this.statusFilter
            : statusFilter as OrderStatus?,
      );
}

const _sentinel = Object();

class StoreOrdersController extends StateNotifier<StoreOrdersState> {
  StoreOrdersController(this._repo) : super(const StoreOrdersState()) {
    refresh();
  }

  final OrderRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.storeOrders(status: state.statusFilter);
    res.when(
      success: (page) =>
          state = state.copyWith(orders: page.items, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  Future<void> setFilter(OrderStatus? status) async {
    state = state.copyWith(statusFilter: status);
    await refresh();
  }
}

/// Provider also wires realtime: any `order.created` / `order.status_changed`
/// event triggers a refresh. The store-room scoping is enforced server-side.
final storeOrdersControllerProvider = StateNotifierProvider.autoDispose<
    StoreOrdersController, StoreOrdersState>((ref) {
  final controller =
      StoreOrdersController(ref.watch(orderRepositoryProvider));
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (event.event == 'order.created' ||
          event.event == 'order.status_changed') {
        controller.refresh();
      }
    });
  });
  return controller;
});

class MerchantOrdersScreen extends ConsumerWidget {
  const MerchantOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storeOrdersControllerProvider);
    final controller = ref.read(storeOrdersControllerProvider.notifier);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Dashboard',
            onPressed: () => context.push('/dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_return_outlined),
            tooltip: 'Refunds',
            onPressed: () => context.push('/refunds'),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Menu',
            onPressed: () => context.push('/menu'),
          ),
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: 'Collections',
            onPressed: () => context.push('/collections'),
          ),
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Threads',
            onPressed: () => context.push('/threads'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: controller.refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Filter(selected: state.statusFilter, onSelect: controller.setFilter),
          const SizedBox(height: BananSpacing.lg),
          Expanded(
            child: _Body(state: state, fmt: fmt, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.selected, required this.onSelect});
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, OrderStatus?)>[
      ('All', null),
      ('Pending', OrderStatus.pending),
      ('Accepted', OrderStatus.accepted),
      ('In preparation', OrderStatus.inPreparation),
      ('Ready', OrderStatus.readyForPickup),
      ('Delivering', OrderStatus.delivering),
      ('Completed', OrderStatus.completed),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: BananSpacing.sm),
              child: ChoiceChip(
                label: Text(f.$1),
                selected: selected == f.$2,
                onSelected: (_) => onSelect(f.$2),
              ),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.fmt,
    required this.controller,
  });

  final StoreOrdersState state;
  final NumberFormat fmt;
  final StoreOrdersController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.orders.isEmpty) {
      return ErrorState(
        message: authFailureMessage(state.failure!),
        onRetry: controller.refresh,
      );
    }
    if (state.orders.isEmpty) {
      return const EmptyState(
        title: 'No orders here',
        message: 'New orders appear in real time.',
        icon: Icons.receipt_long_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: BananSpacing.huge),
        itemCount: state.orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.md),
        itemBuilder: (context, i) {
          final o = state.orders[i];
          return InkWell(
            onTap: () => context.push('/orders/${o.id}'),
            borderRadius: BananRadii.rlg,
            child: Container(
              padding: const EdgeInsets.all(BananSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BananRadii.rlg,
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).dividerTheme.color ??
                      Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    o.fulfillmentType == FulfillmentType.delivery
                        ? Icons.delivery_dining_outlined
                        : Icons.storefront_outlined,
                  ),
                  const SizedBox(width: BananSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.code,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${o.itemCount} item${o.itemCount == 1 ? '' : 's'} · '
                          '${fmt.format(o.total)} · '
                          '${DateFormat.jm().format(o.createdAt.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    label: o.status.label,
                    intent: intentForStatus(o.status),
                    dense: true,
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
