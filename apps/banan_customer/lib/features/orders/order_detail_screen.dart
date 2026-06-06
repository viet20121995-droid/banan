import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/alert_sound.dart';
import '../cart/cart_controller.dart';
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
        // Audible cue while the customer is watching their order.
        playOrderUpdateChime();
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
    final s = ref.watch(stringsProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.orderTitle),
        // Use a Home leading icon so the customer always has a way out —
        // they arrived here via `context.go(...)` which resets the stack,
        // so the default back button wouldn't be reliable.
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: s.backToMenu,
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: s.myOrders,
            onPressed: () => context.go('/orders'),
          ),
        ],
      ),
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

  /// Adds every line from this order back to the cart, then jumps to /cart.
  /// Items already in the cart get their quantity bumped instead of
  /// duplicated (handled by CartController.add → merge by key).
  void _reorder(BuildContext context, WidgetRef ref) {
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
    // Clear pending snackbars before navigating so the message doesn't
    // tail the customer into the cart screen.
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

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.cancelOrderQ),
        content: Text(s.cannotUndo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.keep),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.cancelOrder),
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
    final s = ref.watch(stringsProvider);
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
                      label: s.orderStatusLabel(order.status),
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
                        label: 'Bếp · ${order.kitchenStatus!.label}',
                        intent: order.kitchenStatus == KitchenStatus.readyDispatch
                            ? StatusIntent.success
                            : StatusIntent.progress,
                        dense: true,
                      ),
                    ],
                  ),
                ],
                if (order.scheduledFor != null) ...[
                  const SizedBox(height: BananSpacing.md),
                  _ScheduledForBanner(scheduledFor: order.scheduledFor!),
                ],
                const SizedBox(height: BananSpacing.md),
                _PrepDepartmentBanner(order: order),
                _DeliveryStatusBanner(order: order),
                const SizedBox(height: BananSpacing.md),
                _OrderProgressTracker(order: order),
                const SizedBox(height: BananSpacing.sm),
                Text(
                  '${order.fulfillmentType == FulfillmentType.delivery ? s.delivery : s.pickup} · '
                  '${DateFormat.yMMMd().add_jm().format(order.createdAt.toLocal())}',
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
                if (order.isGift) ...[
                  const SizedBox(height: BananSpacing.xl),
                  _GiftBlock(order: order),
                ],
                if (order.requestVatInvoice) ...[
                  const SizedBox(height: BananSpacing.xl),
                  _VatInvoiceBlock(order: order),
                ],
                const SizedBox(height: BananSpacing.xl),
                Text(s.items, style: theme.textTheme.titleLarge),
                const SizedBox(height: BananSpacing.sm),
                for (final item in order.items)
                  _OrderItemRow(
                    order: order,
                    item: item,
                    fmt: fmt,
                  ),
                const Divider(height: BananSpacing.xl),
                _Line(label: s.subtotal, value: fmt.format(order.subtotal)),
                if (order.campaignDiscount > 0)
                  _Line(
                    label: s.campaignDiscount,
                    value: '−${fmt.format(order.campaignDiscount)}',
                  ),
                if (order.pointsDiscount > 0)
                  _Line(
                    label: s.pointsDiscount,
                    value: '−${fmt.format(order.pointsDiscount)}',
                  ),
                _Line(
                  label: s.deliveryFee,
                  value: fmt.format(order.deliveryFee),
                ),
                const SizedBox(height: BananSpacing.xs),
                _Line(
                  label: s.total,
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
                Text(s.timeline, style: theme.textTheme.titleLarge),
                const SizedBox(height: BananSpacing.sm),
                for (final event in order.statusEvents)
                  _TimelineRow(event: event),
                const SizedBox(height: BananSpacing.xxl),
                if (order.status.customerCanCancel) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(s.cancelOrder),
                    onPressed: () => _cancel(context, ref),
                  ),
                  const SizedBox(height: BananSpacing.md),
                ],
                // One-tap reorder — populates the cart with every line
                // from this order and jumps to checkout. Available on any
                // status (even cancelled/completed) so customers can
                // re-buy a past favorite quickly.
                FilledButton.icon(
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Đặt lại đơn này'),
                  onPressed: () => _reorder(context, ref),
                ),
                const SizedBox(height: BananSpacing.md),
                // Always offer a clear next-action. The customer arrived
                // via `context.go(...)` which reset the stack, so a normal
                // back button wouldn't get them anywhere useful.
                OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(s.orderMoreCakes),
                  onPressed: () => context.go('/'),
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

/// Highlights the customer-chosen pickup/delivery time on scheduled orders.
/// Shown for the entire lifecycle of the order — turns subtle once we're
/// past the moment.
class _ScheduledForBanner extends StatelessWidget {
  const _ScheduledForBanner({required this.scheduledFor});
  final DateTime scheduledFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMEd().add_jm();
    final local = scheduledFor.toLocal();
    final diff = local.difference(DateTime.now());
    final relative = _relative(diff);
    final past = diff.isNegative;

    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: past
            ? BananColors.surfaceDim
            : BananColors.gold.withValues(alpha: 0.10),
        border: Border.all(
          color: past
              ? (theme.dividerTheme.color ?? Colors.black12)
              : BananColors.gold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event,
            color: past ? BananColors.cocoaSoft : BananColors.gold,
          ),
          const SizedBox(width: BananSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  past ? 'Scheduled for' : 'Scheduled for',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${fmt.format(local)} · $relative',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relative(Duration diff) {
    if (diff.isNegative) return 'was scheduled';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'in ${diff.inHours} hr';
    if (diff.inDays == 1) return 'tomorrow';
    return 'in ${diff.inDays} days';
  }
}

/// Tells the customer which department is preparing the order — counter
/// staff or the central kitchen. Hidden once the order has left preparation
/// (ready / delivering / completed / cancelled).
class _PrepDepartmentBanner extends StatelessWidget {
  const _PrepDepartmentBanner({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wentToKitchen = order.status == OrderStatus.sentToKitchen ||
        order.statusEvents.any((e) => e.toStatus == OrderStatus.sentToKitchen);
    final isPreparing = order.status == OrderStatus.inPreparation ||
        order.status == OrderStatus.sentToKitchen;

    // Once the order has moved past prep, this banner stops being useful.
    if (!isPreparing) return const SizedBox.shrink();

    final icon = wentToKitchen
        ? Icons.factory_outlined
        : Icons.storefront_outlined;
    final headline = wentToKitchen
        ? 'Being prepared in our kitchen'
        : 'Being prepared at the counter';
    final detail = wentToKitchen
        ? _kitchenDetailFor(order.kitchenStatus)
        : "Our team is on it — we'll let you know when it's ready.";

    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(BananSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BananRadii.rmd,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 24, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: BananSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _kitchenDetailFor(KitchenStatus? s) {
    switch (s) {
      case KitchenStatus.pendingAck:
        return 'Waiting for the kitchen team to start.';
      case KitchenStatus.preparing:
        return 'Our bakers are crafting your order right now.';
      case KitchenStatus.readyDispatch:
        return 'Ready and on its way back to the store.';
      case null:
        return "We'll keep you posted as it moves through the kitchen.";
    }
  }
}

/// Big, friendly banner shown when the order is heading to the customer —
/// either out for delivery, or ready to pick up at the store. The merchant
/// triggers each state with a tap; the customer sees the corresponding card
/// here in real time (pushed via WebSocket).
class _DeliveryStatusBanner extends ConsumerWidget {
  const _DeliveryStatusBanner({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final isDelivering = order.status == OrderStatus.delivering;
    final isReady = order.status == OrderStatus.readyForPickup;
    if (!isDelivering && !isReady) return const SizedBox.shrink();

    final headline = isDelivering ? s.deliveryOnWay : s.readyPickupBang;
    final detail = isDelivering ? s.courierNote : s.pickupNote;
    final icon = isDelivering
        ? Icons.delivery_dining_outlined
        : Icons.takeout_dining_outlined;
    const accent = BananColors.success;

    return Padding(
      padding: const EdgeInsets.only(top: BananSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rlg,
          color: accent.withValues(alpha: 0.10),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(BananSpacing.md),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.18),
              ),
              child: Icon(icon, size: 32, color: accent),
            ),
            const SizedBox(width: BananSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: theme.textTheme.bodySmall),
                  if (order.address != null && isDelivering) ...[
                    const SizedBox(height: BananSpacing.sm),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: theme.colorScheme.outline,),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            order.address!.oneLine,
                            style: theme.textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal step indicator showing how far through the order journey we are.
/// Steps adapt to the order's fulfillment type (pickup vs delivery) and route
/// (counter vs central kitchen).
class _OrderProgressTracker extends ConsumerWidget {
  const _OrderProgressTracker({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.refunded) {
      return Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          color: BananColors.danger.withValues(alpha: 0.08),
          border: Border.all(color: BananColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined,
                color: BananColors.danger, size: 18,),
            const SizedBox(width: BananSpacing.sm),
            Text(
              s.orderStatusLabel(order.status),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final isDelivery = order.fulfillmentType == FulfillmentType.delivery;
    final wentToKitchen = order.status == OrderStatus.sentToKitchen ||
        order.statusEvents.any((e) => e.toStatus == OrderStatus.sentToKitchen);

    final steps = <_Step>[
      _Step('Placed', Icons.shopping_bag_outlined,
          _reached(order.status, OrderStatus.pending),),
      _Step('Accepted', Icons.check_circle_outline,
          _reached(order.status, OrderStatus.accepted),),
      _Step(
        wentToKitchen ? 'Kitchen' : 'Counter',
        wentToKitchen ? Icons.factory_outlined : Icons.storefront_outlined,
        _reached(order.status, OrderStatus.inPreparation) ||
            _reached(order.status, OrderStatus.sentToKitchen),
      ),
      _Step(
        isDelivery ? 'On the way' : 'Ready',
        isDelivery
            ? Icons.delivery_dining_outlined
            : Icons.takeout_dining_outlined,
        _reached(order.status,
            isDelivery ? OrderStatus.delivering : OrderStatus.readyForPickup,),
      ),
      _Step('Completed', Icons.task_alt,
          _reached(order.status, OrderStatus.completed),),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.md,
        vertical: BananSpacing.lg,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(child: _StepCell(step: steps[i])),
            if (i < steps.length - 1)
              _Connector(reached: steps[i + 1].reached),
          ],
        ],
      ),
    );
  }

  /// Has the order's progress reached or passed [target]?
  bool _reached(OrderStatus current, OrderStatus target) {
    int rank(OrderStatus s) {
      switch (s) {
        case OrderStatus.pending:
          return 0;
        case OrderStatus.accepted:
          return 1;
        case OrderStatus.inPreparation:
        case OrderStatus.sentToKitchen:
          return 2;
        case OrderStatus.readyForPickup:
        case OrderStatus.delivering:
          return 3;
        case OrderStatus.completed:
          return 4;
        case OrderStatus.cancelled:
        case OrderStatus.refunded:
          return -1;
      }
    }

    return rank(current) >= rank(target);
  }
}

class _Step {
  const _Step(this.label, this.icon, this.reached);
  final String label;
  final IconData icon;
  final bool reached;
}

class _StepCell extends StatelessWidget {
  const _StepCell({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = step.reached
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withValues(alpha: 0.4);
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: step.reached
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(step.icon, size: 16, color: color),
        ),
        const SizedBox(height: BananSpacing.xs),
        Text(
          step.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: step.reached ? FontWeight.w600 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.reached});
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SizedBox(
        width: 16,
        child: Divider(
          thickness: 1.5,
          color: reached
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
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

/// Order-item row with an inline "Đánh giá / Sửa đánh giá" button
/// once the order is in a post-delivery state. Reads my-reviews-for-order
/// so the button reflects existing reviews.
class _OrderItemRow extends ConsumerWidget {
  const _OrderItemRow({
    required this.order,
    required this.item,
    required this.fmt,
  });
  final Order order;
  final OrderItem item;
  final NumberFormat fmt;

  bool get _canReview =>
      order.status == OrderStatus.readyForPickup ||
      order.status == OrderStatus.delivering ||
      order.status == OrderStatus.completed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mineAsync = ref.watch(_myReviewsForOrderProvider(order.id));
    final mine = mineAsync.valueOrNull ?? const <Review>[];
    Review? existing;
    for (final r in mine) {
      if (r.productId == item.productId) {
        existing = r;
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.xs),
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
                if (item.personalization != null &&
                    item.personalization!.isNotEmpty)
                  _PersonalizationSummary(payload: item.personalization!),
                if (_canReview)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.star_border_rounded, size: 14),
                      label: Text(
                        existing == null
                            ? 'Đánh giá sản phẩm'
                            : 'Sửa đánh giá (${existing.rating}★)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _openReviewSheet(context, ref, existing),
                    ),
                  ),
              ],
            ),
          ),
          Text(fmt.format(item.lineTotal)),
        ],
      ),
    );
  }

  Future<void> _openReviewSheet(
    BuildContext context,
    WidgetRef ref,
    Review? existing,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(
        productName: item.productName,
        productId: item.productId,
        orderId: order.id,
        existing: existing,
      ),
    );
    if (result == true) {
      ref.invalidate(_myReviewsForOrderProvider(order.id));
    }
  }
}

final _myReviewsForOrderProvider =
    FutureProvider.autoDispose.family<List<Review>, String>(
  (ref, orderId) async {
    final api = ref.watch(reviewsApiProvider);
    final res = await api.mineForOrder(orderId);
    return res.when(
      success: (list) => list,
      failure: (f) => throw Exception(f.message ?? f.code),
    );
  },
);

/// Bottom sheet with a 1-5 star picker + optional comment. Pops `true` on
/// successful submit so the parent can refresh.
class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({
    required this.productName,
    required this.productId,
    required this.orderId,
    required this.existing,
  });

  final String productName;
  final String productId;
  final String orderId;
  final Review? existing;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  late int _rating;
  late final TextEditingController _body;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 5;
    _body = TextEditingController(text: widget.existing?.body ?? '');
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await ref.read(reviewsApiProvider).create(
          productId: widget.productId,
          orderId: widget.orderId,
          rating: _rating,
          body: _body.text.trim(),
        );
    if (!mounted) return;
    res.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) {
        setState(() {
          _saving = false;
          _error = f.message ?? f.code;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Đánh giá: ${widget.productName}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: BananSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    iconSize: 36,
                    onPressed: () => setState(() => _rating = i + 1),
                    icon: Icon(
                      i < _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: BananColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BananSpacing.sm),
              TextField(
                controller: _body,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Chia sẻ cảm nhận (tuỳ chọn)',
                  helperText: 'Hương vị, mức độ tươi, đóng gói, …',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: BananSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: BananSpacing.md),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  widget.existing == null ? 'Gửi đánh giá' : 'Cập nhật',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Customer-facing VAT-invoice block — purely informational. Shows the
/// company info captured at checkout so the customer can confirm what
/// was sent to the merchant. Merchant issues the invoice outside the app.
class _VatInvoiceBlock extends StatelessWidget {
  const _VatInvoiceBlock({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      padding: const EdgeInsets.all(BananSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 18),
              const SizedBox(width: BananSpacing.xs),
              Text('Thông tin hoá đơn VAT',
                  style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: BananSpacing.xs),
          if (order.invoiceCompanyName != null)
            Text(order.invoiceCompanyName!,
                style: theme.textTheme.bodyLarge),
          if (order.invoiceTaxId != null)
            Text('MST: ${order.invoiceTaxId}',
                style: theme.textTheme.bodySmall),
          if (order.invoiceAddress != null)
            Text(order.invoiceAddress!,
                style: theme.textTheme.bodySmall),
          if (order.invoiceEmail != null)
            Text(
              order.invoiceEmail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}

/// "🎁 Đơn quà tặng" card on the customer order detail — confirms the
/// greeting message, recipient (name + phone) and shows a "Gói quà" badge
/// when the order was wrapped. Rendered only when `order.isGift` is true.
class _GiftBlock extends StatelessWidget {
  const _GiftBlock({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRecipient = (order.giftRecipientName?.isNotEmpty ?? false) ||
        (order.giftRecipientPhone?.isNotEmpty ?? false);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: BananColors.gold.withValues(alpha: 0.10),
        border: Border.all(color: BananColors.gold.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(BananSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 18)),
              const SizedBox(width: BananSpacing.xs),
              Text('Đơn quà tặng', style: theme.textTheme.titleSmall),
              if (order.giftWrap) ...[
                const SizedBox(width: BananSpacing.sm),
                _GiftFlagChip(label: 'Gói quà'),
              ],
            ],
          ),
          if (order.giftMessage != null &&
              order.giftMessage!.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.sm),
            Text(
              '“${order.giftMessage!}”',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (hasRecipient) ...[
            const SizedBox(height: BananSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.card_giftcard_outlined,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: BananSpacing.xs),
                Expanded(
                  child: Text(
                    'Người nhận: '
                    '${order.giftRecipientName ?? '—'}'
                    '${(order.giftRecipientPhone?.isNotEmpty ?? false) ? ' · ${order.giftRecipientPhone}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          if (order.hidePrice) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(
              'Phiếu giao cho người nhận sẽ ẩn giá tiền.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small pill used inside the gift card for the "Gói quà" flag.
class _GiftFlagChip extends StatelessWidget {
  const _GiftFlagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: BananColors.gold.withValues(alpha: 0.22),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BananColors.cocoa,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Renders an `OrderItem.personalization` payload as a tinted info card
/// under the item title. Same shape on customer + merchant order detail
/// — the merchant uses it as a kitchen-instruction snippet, the
/// customer uses it to confirm what they ordered.
class _PersonalizationSummary extends StatelessWidget {
  const _PersonalizationSummary({required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = payload['textOnCake'] as String?;
    final candles = (payload['candleCount'] as num?)?.toInt();
    final note = payload['note'] as String?;
    final flavors = payload['flavors'] as Map<String, dynamic>?;
    final flavorLine = (flavors != null && flavors.isNotEmpty)
        ? flavors.entries
            .map((e) => '${(e.value as num).toInt()}× ${e.key}')
            .join(', ')
        : null;
    return Container(
      margin: const EdgeInsets.only(top: BananSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: BananColors.primary.withValues(alpha: 0.06),
        border: Border.all(
          color: BananColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cake_outlined,
                  size: 14, color: BananColors.primary),
              const SizedBox(width: 4),
              Text(
                'Cá nhân hoá',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: BananColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (text != null && text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Chữ trên bánh: "$text"',
                  style: theme.textTheme.bodySmall),
            ),
          if (candles != null)
            Text('$candles nến', style: theme.textTheme.bodySmall),
          if (flavorLine != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Vị: $flavorLine',
                  style: theme.textTheme.bodySmall),
            ),
          if (note != null && note.isNotEmpty)
            Text('Ghi chú: $note', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
