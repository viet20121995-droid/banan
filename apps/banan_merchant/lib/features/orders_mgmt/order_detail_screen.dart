import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'order_status_visuals.dart';
import 'orders_screen.dart';

final _orderProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, id) async {
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (event.data['orderId'] == id &&
          (event.event == 'order.status_changed' ||
              event.event == 'order.kitchen_status_changed')) {
        ref.invalidateSelf();
      }
    });
  });
  final repo = ref.read(orderRepositoryProvider);
  final res = await repo.order(id);
  return res.when(
    success: (o) => o,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class MerchantOrderDetailScreen extends ConsumerWidget {
  const MerchantOrderDetailScreen({required this.orderId, super.key});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(_orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_orderProvider(orderId)),
        ),
        data: (order) => _Body(order: order),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});
  final Order order;

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    OrderStatus to, {
    String? note,
  }) async {
    final repo = ref.read(orderRepositoryProvider);
    final res = await repo.transition(order.id, to, note: note);
    if (!context.mounted) return;
    res.when(
      success: (_) {
        ref.invalidate(_orderProvider(order.id));
        ref.invalidate(storeOrdersControllerProvider);
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  Future<void> _transferToKitchen(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(orderRepositoryProvider);
    final res = await repo.transferToKitchen(order.id);
    if (!context.mounted) return;
    res.when(
      success: (_) {
        ref.invalidate(_orderProvider(order.id));
        ref.invalidate(storeOrdersControllerProvider);
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    final actions = _actionsFor(order, context, ref);

    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(order.code,
                          style: theme.textTheme.headlineSmall,),
                    ),
                    StatusBadge(
                      label: order.status.label,
                      intent: intentForStatus(order.status),
                    ),
                  ],
                ),
                const SizedBox(height: BananSpacing.sm),
                Text(
                  '${order.fulfillmentType == FulfillmentType.delivery ? 'Delivery' : 'Pickup'} · '
                  'Placed ${DateFormat.yMMMd().add_jm().format(order.createdAt.toLocal())}',
                  style: theme.textTheme.bodySmall,
                ),
                if (order.address != null) ...[
                  const SizedBox(height: BananSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(BananSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BananRadii.rmd,
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.dividerTheme.color ?? Colors.black12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.address!.recipient} · ${order.address!.phone}',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          order.address!.oneLine,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: BananSpacing.md),
                  Text('Customer notes',
                      style: theme.textTheme.titleSmall,),
                  Text(order.notes!, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: BananSpacing.xl),
                Text('Items', style: theme.textTheme.titleLarge),
                const SizedBox(height: BananSpacing.sm),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: BananSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.quantity}× ${item.productName}',
                                style: theme.textTheme.bodyLarge,
                              ),
                              if (item.variantLabel != null)
                                Text(item.variantLabel!,
                                    style: theme.textTheme.bodySmall,),
                              if (item.customMessage != null &&
                                  item.customMessage!.isNotEmpty)
                                Text(
                                  '“${item.customMessage}”',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(fmt.format(item.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(height: BananSpacing.xl),
                _Line(label: 'Subtotal', value: fmt.format(order.subtotal)),
                _Line(
                  label: 'Delivery fee',
                  value: fmt.format(order.deliveryFee),
                ),
                const SizedBox(height: BananSpacing.xs),
                _Line(
                  label: 'Total',
                  value: fmt.format(order.total),
                  bold: true,
                ),
                const SizedBox(height: BananSpacing.xxl),
                if (actions.isNotEmpty)
                  Wrap(
                    spacing: BananSpacing.md,
                    runSpacing: BananSpacing.md,
                    children: actions,
                  ),
                const SizedBox(height: BananSpacing.huge),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _actionsFor(Order order, BuildContext context, WidgetRef ref) {
    Widget btn(String label, IconData icon, OrderStatus to,
        {bool primary = true,}) {
      Future<void> onPressed() => _transition(context, ref, to);
      return primary
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            );
    }

    switch (order.status) {
      case OrderStatus.pending:
        return [
          btn('Accept', Icons.check, OrderStatus.accepted),
          btn('Reject', Icons.close, OrderStatus.cancelled, primary: false),
        ];
      case OrderStatus.accepted:
        return [
          btn(
            'Start preparing',
            Icons.kitchen_outlined,
            OrderStatus.inPreparation,
          ),
          btn('Cancel', Icons.cancel_outlined, OrderStatus.cancelled,
              primary: false,),
        ];
      case OrderStatus.inPreparation:
        final readyTo = order.fulfillmentType == FulfillmentType.delivery
            ? OrderStatus.delivering
            : OrderStatus.readyForPickup;
        final readyLabel = order.fulfillmentType == FulfillmentType.delivery
            ? 'Out for delivery'
            : 'Ready for pickup';
        return [
          btn(readyLabel, Icons.local_shipping_outlined, readyTo),
          OutlinedButton.icon(
            onPressed: () => _transferToKitchen(context, ref),
            icon: const Icon(Icons.factory_outlined),
            label: const Text('Transfer to kitchen'),
          ),
          btn('Cancel', Icons.cancel_outlined, OrderStatus.cancelled,
              primary: false,),
        ];
      case OrderStatus.sentToKitchen:
        // Kitchen owns the order — only cancel is available to the merchant
        // until the kitchen dispatches it back.
        return [
          btn('Cancel', Icons.cancel_outlined, OrderStatus.cancelled,
              primary: false,),
        ];
      case OrderStatus.readyForPickup:
      case OrderStatus.delivering:
        return [
          btn('Mark completed', Icons.task_alt, OrderStatus.completed),
        ];
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return const [];
    }
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
