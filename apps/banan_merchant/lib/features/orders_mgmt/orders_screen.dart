import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';
import 'alert_sound.dart';
import 'order_status_visuals.dart';

@immutable
class StoreOrdersState {
  const StoreOrdersState({
    this.orders = const [],
    this.loading = false,
    this.failure,
    this.statusFilter,
    this.scheduledOnly = false,
    this.newOrderCount = 0,
    this.storeIdFilter,
  });

  final List<Order> orders;
  final bool loading;
  final AppFailure? failure;
  final OrderStatus? statusFilter;
  /// When true, only orders with `scheduledFor != null` are shown — sorted
  /// by upcoming pickup/delivery time.
  final bool scheduledOnly;

  /// Orders that arrived via realtime since the merchant last acknowledged.
  /// Drives the attention banner; cleared when the merchant taps it.
  final int newOrderCount;

  /// Admin-only client-side filter: when set, only show orders from this
  /// store. Merchants are already server-scoped to their own store so this
  /// stays null for them.
  final String? storeIdFilter;

  /// Orders after applying the in-memory filters (scheduled + store).
  List<Order> get visibleOrders {
    Iterable<Order> list = orders;
    if (scheduledOnly) {
      list = list.where((o) => o.scheduledFor != null);
    }
    if (storeIdFilter != null) {
      list = list.where((o) => o.storeId == storeIdFilter);
    }
    final out = list.toList();
    if (scheduledOnly) {
      out.sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));
    }
    return out;
  }

  StoreOrdersState copyWith({
    List<Order>? orders,
    bool? loading,
    Object? failure = _sentinel,
    Object? statusFilter = _sentinel,
    bool? scheduledOnly,
    int? newOrderCount,
    Object? storeIdFilter = _sentinel,
  }) =>
      StoreOrdersState(
        orders: orders ?? this.orders,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
        statusFilter: statusFilter == _sentinel
            ? this.statusFilter
            : statusFilter as OrderStatus?,
        scheduledOnly: scheduledOnly ?? this.scheduledOnly,
        newOrderCount: newOrderCount ?? this.newOrderCount,
        storeIdFilter: storeIdFilter == _sentinel
            ? this.storeIdFilter
            : storeIdFilter as String?,
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

  /// Called from the realtime listener when a brand-new order lands.
  /// Bumps the attention counter; the UI plays a chime + shows a banner.
  void onNewOrder() {
    state = state.copyWith(newOrderCount: state.newOrderCount + 1);
  }

  /// Merchant tapped the banner — clear the badge and refresh the list.
  Future<void> acknowledgeNewOrders() async {
    state = state.copyWith(newOrderCount: 0);
    await refresh();
  }

  Future<void> setFilter(OrderStatus? status) async {
    state = state.copyWith(statusFilter: status, scheduledOnly: false);
    await refresh();
  }

  /// Toggle the "Scheduled" pseudo-filter. We don't have a backend `scheduled`
  /// query param, so we fetch all PENDING orders and filter client-side.
  Future<void> setScheduledOnly(bool on) async {
    state = state.copyWith(
      statusFilter: on ? OrderStatus.pending : null,
      scheduledOnly: on,
    );
    await refresh();
  }

  /// Admin-only client-side branch filter. Pass null to clear (show all).
  /// Doesn't refetch — the admin view already has every store's orders.
  void setStoreFilter(String? storeId) {
    state = state.copyWith(storeIdFilter: storeId);
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
      if (event.event == 'order.created') {
        // New order — chime + bump the attention counter, then refresh.
        playNewOrderChime();
        controller.onNewOrder();
        controller.refresh();
      } else if (event.event == 'order.status_changed' ||
          event.event == 'order.due_soon') {
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

    final s = ref.watch(stringsProvider);
    final isAdmin = ref
            .watch(authSessionProvider)
            .valueOrNull
            ?.user
            .role
            .isAdmin ??
        false;

    return MerchantShell(
      title: s.orders,
      onRefresh: controller.refresh,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.newOrderCount > 0)
            _NewOrderBanner(
              count: state.newOrderCount,
              onTap: controller.acknowledgeNewOrders,
            ),
          // Branch filter — admin only. Merchants only see their own
          // store's orders so the row would be redundant for them.
          if (isAdmin)
            _StoreFilter(
              orders: state.orders,
              selected: state.storeIdFilter,
              onSelect: controller.setStoreFilter,
            ),
          if (isAdmin) const SizedBox(height: BananSpacing.sm),
          _Filter(
            selected: state.statusFilter,
            scheduledOnly: state.scheduledOnly,
            onSelect: controller.setFilter,
            onScheduledToggle: () =>
                controller.setScheduledOnly(!state.scheduledOnly),
          ),
          const SizedBox(height: BananSpacing.lg),
          Expanded(
            child: _Body(state: state, fmt: fmt, controller: controller),
          ),
        ],
      ),
    );
  }
}

/// Pulsing call-to-action that appears the moment new orders arrive over
/// realtime. Impossible to miss during a busy shift; tap clears it and
/// refreshes the list.
class _NewOrderBanner extends StatefulWidget {
  const _NewOrderBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  State<_NewOrderBanner> createState() => _NewOrderBannerState();
}

class _NewOrderBannerState extends State<_NewOrderBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.count;
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.md),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.75, end: 1).animate(_pulse),
        child: Material(
          color: BananColors.primary,
          borderRadius: BananRadii.rlg,
          child: InkWell(
            borderRadius: BananRadii.rlg,
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(BananSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active,
                      color: Colors.white,),
                  const SizedBox(width: BananSpacing.md),
                  Expanded(
                    child: Text(
                      n == 1
                          ? 'Vừa có 1 đơn hàng mới!'
                          : 'Vừa có $n đơn hàng mới!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Text(
                    'Bấm để xem',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: BananSpacing.xs),
                  const Icon(Icons.arrow_forward, color: Colors.white,
                      size: 18,),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.selected,
    required this.scheduledOnly,
    required this.onSelect,
    required this.onScheduledToggle,
  });
  final OrderStatus? selected;
  final bool scheduledOnly;
  final ValueChanged<OrderStatus?> onSelect;
  final VoidCallback onScheduledToggle;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, OrderStatus?)>[
      ('Tất cả', null),
      ('Chờ duyệt', OrderStatus.pending),
      ('Đã nhận', OrderStatus.accepted),
      ('Đang làm', OrderStatus.inPreparation),
      ('Sẵn sàng', OrderStatus.readyForPickup),
      ('Đang giao', OrderStatus.delivering),
      ('Hoàn thành', OrderStatus.completed),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Distinct pseudo-filter — pickups & deliveries scheduled for later.
          Padding(
            padding: const EdgeInsets.only(right: BananSpacing.sm),
            child: ChoiceChip(
              avatar: const Icon(Icons.event_outlined, size: 18),
              label: const Text('Lên lịch'),
              selected: scheduledOnly,
              onSelected: (_) => onScheduledToggle(),
            ),
          ),
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: BananSpacing.sm),
              child: ChoiceChip(
                label: Text(f.$1),
                selected: !scheduledOnly && selected == f.$2,
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
    final visible = state.visibleOrders;
    if (state.loading && visible.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && visible.isEmpty) {
      return ErrorState(
        message: authFailureMessage(state.failure!),
        onRetry: controller.refresh,
      );
    }
    if (visible.isEmpty) {
      return EmptyState(
        title: state.scheduledOnly
            ? 'Chưa có đơn lên lịch'
            : 'Chưa có đơn ở đây',
        message: state.scheduledOnly
            ? 'Đơn đặt trước cho ngày sau sẽ hiển thị ở đây.'
            : 'Đơn hàng mới sẽ xuất hiện theo thời gian thực.',
        icon: state.scheduledOnly
            ? Icons.event_outlined
            : Icons.receipt_long_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: BananSpacing.huge),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.md),
        itemBuilder: (context, i) {
          final o = visible[i];
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                o.code,
                                style: Theme.of(context).textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Branch label — important context for admin
                            // (chain-wide view) and helpful for staff who
                            // jump between branches. Hidden when the order
                            // has no store info attached.
                            if ((o.storeName ?? '').isNotEmpty) ...[
                              const SizedBox(width: BananSpacing.xs),
                              _StorePill(name: o.storeName!),
                            ],
                            if (o.requestVatInvoice) ...[
                              const SizedBox(width: BananSpacing.xs),
                              const StatusBadge(
                                label: 'VAT',
                                intent: StatusIntent.info,
                                dense: true,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${o.itemCount} món · '
                          '${fmt.format(o.total)} · '
                          '${DateFormat.jm().format(o.createdAt.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (o.scheduledFor != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.event,
                                    size: 13, color: BananColors.gold,),
                                const SizedBox(width: 4),
                                Text(
                                  'Cho ${DateFormat.MMMd().add_jm().format(o.scheduledFor!.toLocal())}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: BananColors.gold),
                                ),
                              ],
                            ),
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

/// Tiny branch-name pill shown next to the order code. Surface so admin
/// (who sees every store's queue) and floating staff always know which
/// store an action will affect.
class _StorePill extends StatelessWidget {
  const _StorePill({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Drop the "Banan – " prefix on display — it's redundant in a tight
    // pill and eats horizontal room. We keep it in the underlying value
    // for analytics / accessibility.
    final short = name.replaceFirst(RegExp(r'^Banan\s*[–-]\s*'), '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        short,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Branch filter chips for the admin order queue. Derives the option set
/// from the actual `state.orders` so a branch only appears in the row
/// once an order from it shows up — avoids cluttering admins with empty
/// stores during quiet hours.
class _StoreFilter extends StatelessWidget {
  const _StoreFilter({
    required this.orders,
    required this.selected,
    required this.onSelect,
  });

  final List<Order> orders;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    // Unique (id, name) pairs in order-of-appearance. We don't sort —
    // branches show up in the same order admin would see in the order
    // queue itself.
    final seen = <String>{};
    final stores = <({String id, String name})>[];
    for (final o in orders) {
      if (o.storeName == null || o.storeName!.isEmpty) continue;
      if (seen.add(o.storeId)) {
        stores.add((id: o.storeId, name: o.storeName!));
      }
    }
    if (stores.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: BananSpacing.sm),
            child: ChoiceChip(
              avatar: const Icon(Icons.storefront_outlined, size: 16),
              label: const Text('Tất cả chi nhánh'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          for (final s in stores)
            Padding(
              padding: const EdgeInsets.only(right: BananSpacing.sm),
              child: ChoiceChip(
                label: Text(
                  s.name.replaceFirst(RegExp(r'^Banan\s*[–-]\s*'), ''),
                ),
                selected: selected == s.id,
                onSelected: (_) => onSelect(s.id),
              ),
            ),
        ],
      ),
    );
  }
}
