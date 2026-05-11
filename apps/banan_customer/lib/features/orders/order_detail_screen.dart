import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'order_status_visuals.dart';
import 'orders_list_screen.dart';

final _orderProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, id) async {
  // Subscribe to live updates for this order. The gateway joins us to the
  // `order:{id}` room; on `order.status_changed` we refetch.
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      final eventOrderId = event.data['orderId'] as String?;
      if (eventOrderId == id &&
          (event.event == 'order.status_changed' ||
              event.event == 'order.kitchen_status_changed')) {
        ref.invalidateSelf();
        ref.invalidate(myOrdersProvider);
      }
    });
  });

  final socket = ref.read(socketClientProvider);
  socket?.subscribeToOrder(id);

  final repo = ref.read(orderRepositoryProvider);
  final result = await repo.order(id);
  return result.when(
    success: (o) => o,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(_orderProvider(orderId));
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(_orderProvider(orderId)),
        ),
        data: (order) => _Body(order: order, fmt: fmt),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order, required this.fmt});

  final Order order;
  final NumberFormat fmt;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirm ?? false) {
      final repo = ref.read(orderRepositoryProvider);
      final res = await repo.cancel(order.id);
      if (!context.mounted) return;
      res.when(
        success: (_) => ref.invalidate(_orderProvider(order.id)),
        failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authFailureMessage(f))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.code,
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    StatusBadge(
                      label: order.status.label,
                      intent: intentForStatus(order.status),
                    ),
                  ],
                ),
                if (order.kitchenStatus != null) ...[
                  const SizedBox(height: BananSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      StatusBadge(
                        label: 'Kitchen · ${order.kitchenStatus!.label}',
                        intent: order.kitchenStatus == KitchenStatus.readyDispatch
                            ? StatusIntent.success
                            : StatusIntent.progress,
                        dense: true,
                      ),
                    ],
                  ),
                ],
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
                                Text(
                                  item.variantLabel!,
                                  style: theme.textTheme.bodySmall,
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
                if (order.currentRefund != null) ...[
                  const SizedBox(height: BananSpacing.xl),
                  _RefundBanner(refund: order.currentRefund!, fmt: fmt),
                ],
                if (order.currentPayment != null) ...[
                  const SizedBox(height: BananSpacing.md),
                  _PaymentBanner(
                    payment: order.currentPayment!,
                    fmt: fmt,
                  ),
                ],
                const SizedBox(height: BananSpacing.xxl),
                Text('Timeline', style: theme.textTheme.titleLarge),
                const SizedBox(height: BananSpacing.sm),
                for (final event in order.statusEvents)
                  _TimelineRow(event: event),
                const SizedBox(height: BananSpacing.xxl),
                if (order.status.customerCanCancel)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel order'),
                    onPressed: () => _cancel(context, ref),
                  ),
                const SizedBox(height: BananSpacing.huge),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentBanner extends StatelessWidget {
  const _PaymentBanner({required this.payment, required this.fmt});
  final PaymentSummary payment;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intent = switch (payment.status) {
      PaymentStatus.captured => StatusIntent.success,
      PaymentStatus.refunded => StatusIntent.danger,
      PaymentStatus.failed => StatusIntent.danger,
      PaymentStatus.voided => StatusIntent.neutral,
      PaymentStatus.authorized => StatusIntent.info,
      PaymentStatus.initiated => StatusIntent.warning,
    };
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          Icon(
            payment.provider == PaymentMethod.cash
                ? Icons.payments_outlined
                : Icons.credit_card,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Text(
              '${payment.provider.label} · ${fmt.format(payment.amount)}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          StatusBadge(label: payment.status.label, intent: intent, dense: true),
        ],
      ),
    );
  }
}

class _RefundBanner extends StatelessWidget {
  const _RefundBanner({required this.refund, required this.fmt});
  final Refund refund;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intent = switch (refund.status) {
      RefundStatus.requested => StatusIntent.warning,
      RefundStatus.approved => StatusIntent.progress,
      RefundStatus.processing => StatusIntent.progress,
      RefundStatus.completed => StatusIntent.success,
      RefundStatus.rejected => StatusIntent.danger,
    };
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_return_outlined,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Text(
                  'Refund · ${fmt.format(refund.amount)}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StatusBadge(label: refund.status.label, intent: intent, dense: true),
            ],
          ),
          if (refund.reason.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(refund.reason, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
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

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});
  final OrderStatusEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: BananSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.toStatus.label,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(event.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall,
                ),
                if (event.note != null && event.note!.isNotEmpty)
                  Text(event.note!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
