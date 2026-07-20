import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/print_ticket.dart';
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
      appBar: AppBar(title: const Text('Đơn hàng')),
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
        ref
          ..invalidate(_orderProvider(order.id))
          ..invalidate(storeOrdersControllerProvider);
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

  /// Receive dialog: per-line received qty (defaults to ordered) + note, then
  /// POST receive-transfer → COMPLETED with a structured receipt.
  Future<void> _receiveTransfer(BuildContext context, WidgetRef ref) async {
    final qtyCtls = {
      for (final i in order.items)
        i.id: TextEditingController(text: '${i.quantity}'),
    };
    final noteCtl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận nhận hàng'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final i in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: BananSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            i.productName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: qtyCtls[i.id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              isDense: true,
                              suffixText: '/${i.quantity}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: noteCtl,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (thiếu/hỏng…)',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận nhận hàng'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final received = <Map<String, dynamic>>[];
    for (final i in order.items) {
      final qty = int.tryParse(qtyCtls[i.id]!.text.trim()) ?? i.quantity;
      if (qty != i.quantity) {
        received.add({'orderItemId': i.id, 'receivedQty': qty});
      }
    }
    final res = await ref.read(ordersApiProvider).receiveTransfer(
          order.id,
          note: noteCtl.text.trim(),
          receivedItems: received,
        );
    if (!context.mounted) return;
    res.when(
      success: (_) {
        ref.invalidate(_orderProvider(order.id));
        ref.invalidate(storeOrdersControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Đã ghi nhận nhận hàng, đơn hoàn tất.')),
        );
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authFailureMessage(f))),
      ),
    );
  }

  Future<void> _markCounterPaid(BuildContext context, WidgetRef ref) async {
    final res = await ref.read(ordersApiProvider).markCounterPaid(order.id);
    if (!context.mounted) return;
    res.when(
      success: (_) {
        ref.invalidate(_orderProvider(order.id));
        ref.invalidate(storeOrdersControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ghi nhận thanh toán tại quầy.')),
        );
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
                const SizedBox(height: BananSpacing.sm),
                Text(
                  '${order.fulfillmentType == FulfillmentType.delivery ? 'Giao hàng' : 'Tự đến lấy'} · '
                  'Đặt lúc ${DateFormat.yMMMd().add_jm().format(order.createdAt.toLocal())}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: BananSpacing.sm),
                Wrap(
                  spacing: BananSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => printReceipt(order),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('In phiếu'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => printKitchenTicket(order),
                      icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
                      label: const Text('Phiếu bếp'),
                    ),
                  ],
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
                  Text(
                    'Ghi chú của khách',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(order.notes!, style: theme.textTheme.bodyMedium),
                ],
                if (order.isGift) ...[
                  const SizedBox(height: BananSpacing.lg),
                  _GiftBlock(order: order),
                ],
                if (order.requestVatInvoice) ...[
                  const SizedBox(height: BananSpacing.lg),
                  _VatInvoiceBlock(order: order),
                ],
                const SizedBox(height: BananSpacing.xl),
                Text('Món trong đơn', style: theme.textTheme.titleLarge),
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
                              if (item.customMessage != null &&
                                  item.customMessage!.isNotEmpty)
                                Text(
                                  '“${item.customMessage}”',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              if (item.personalization != null &&
                                  item.personalization!.isNotEmpty)
                                _MerchantPersonalizationBlock(
                                  payload: item.personalization!,
                                ),
                            ],
                          ),
                        ),
                        Text(fmt.format(item.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(height: BananSpacing.xl),
                _Line(label: 'Tạm tính', value: fmt.format(order.subtotal)),
                if (order.bundleDiscount > 0)
                  _Line(
                    label: 'Giảm combo',
                    value: '−${fmt.format(order.bundleDiscount)}',
                  ),
                if (order.campaignDiscount > 0)
                  _Line(
                    label: 'Khuyến mãi',
                    value: '−${fmt.format(order.campaignDiscount)}',
                  ),
                _Line(
                  label: 'Phí giao hàng',
                  value: fmt.format(order.deliveryFee),
                ),
                const SizedBox(height: BananSpacing.xs),
                _Line(
                  label: 'Tổng cộng',
                  value: fmt.format(order.total),
                  bold: true,
                ),
                const SizedBox(height: BananSpacing.xxl),
                if (order.source == 'STAFF_COUNTER' &&
                    order.settlementMode == 'COUNTER_UNPAID' &&
                    order.status != OrderStatus.cancelled &&
                    order.status != OrderStatus.refunded) ...[
                  FilledButton.icon(
                    onPressed: () => _markCounterPaid(context, ref),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Xác nhận đã thu tiền tại quầy'),
                  ),
                  const SizedBox(height: BananSpacing.md),
                ],
                // Destination branch signs for an internal transfer after the
                // kitchen dispatched it — the only path to COMPLETED for it.
                if (order.source == 'INTERNAL_TRANSFER' &&
                    (order.status == OrderStatus.readyForPickup ||
                        order.status == OrderStatus.delivering)) ...[
                  Builder(
                    builder: (context) {
                      final user =
                          ref.watch(authSessionProvider).valueOrNull?.user;
                      final canReceive = user != null &&
                          (user.role.isAdmin ||
                              (user.storeId != null &&
                                  user.storeId == order.destinationStoreId));
                      if (!canReceive) return const SizedBox.shrink();
                      return FilledButton.icon(
                        onPressed: () => _receiveTransfer(context, ref),
                        icon: const Icon(Icons.inventory_outlined),
                        label: const Text('Đã nhận hàng tại chi nhánh'),
                      );
                    },
                  ),
                  const SizedBox(height: BananSpacing.md),
                ],
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
    Widget btn(
      String label,
      IconData icon,
      OrderStatus to, {
      bool primary = true,
    }) {
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
          btn('Nhận đơn', Icons.check, OrderStatus.accepted),
          btn('Từ chối', Icons.close, OrderStatus.cancelled, primary: false),
        ];
      case OrderStatus.accepted:
        // Merchant decides where the order is made: in-house counter prep,
        // or routed to the central kitchen with its own kanban workflow.
        return [
          btn(
            'Làm tại quầy',
            Icons.storefront_outlined,
            OrderStatus.inPreparation,
          ),
          FilledButton.tonalIcon(
            onPressed: () => _transferToKitchen(context, ref),
            icon: const Icon(Icons.factory_outlined),
            label: const Text('Gửi tới bếp'),
          ),
          btn(
            'Huỷ',
            Icons.cancel_outlined,
            OrderStatus.cancelled,
            primary: false,
          ),
        ];
      case OrderStatus.inPreparation:
        final readyTo = order.fulfillmentType == FulfillmentType.delivery
            ? OrderStatus.delivering
            : OrderStatus.readyForPickup;
        final readyLabel = order.fulfillmentType == FulfillmentType.delivery
            ? 'Đang giao'
            : 'Sẵn sàng lấy';
        return [
          btn(readyLabel, Icons.local_shipping_outlined, readyTo),
          OutlinedButton.icon(
            onPressed: () => _transferToKitchen(context, ref),
            icon: const Icon(Icons.factory_outlined),
            label: const Text('Chuyển sang bếp'),
          ),
          btn(
            'Huỷ',
            Icons.cancel_outlined,
            OrderStatus.cancelled,
            primary: false,
          ),
        ];
      case OrderStatus.sentToKitchen:
        // Kitchen owns the order — only cancel is available to the merchant
        // until the kitchen dispatches it back.
        return [
          btn(
            'Huỷ',
            Icons.cancel_outlined,
            OrderStatus.cancelled,
            primary: false,
          ),
        ];
      case OrderStatus.readyForPickup:
        return [
          btn('Đã giao cho khách', Icons.task_alt, OrderStatus.completed),
          _CopyTrackingLinkButton(orderId: order.id),
        ];
      case OrderStatus.delivering:
        return [
          btn('Đã giao xong', Icons.task_alt, OrderStatus.completed),
          _CopyTrackingLinkButton(orderId: order.id),
        ];
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        return const [];
    }
  }
}

/// Copies the customer-facing tracking URL (e.g. for the merchant to text
/// the customer or paste into a chat) to the clipboard.
class _CopyTrackingLinkButton extends StatelessWidget {
  const _CopyTrackingLinkButton({required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    // /track/:id is the public, guest-accessible tracking page — the customer
    // this link is texted to has no session. (/orders/:id is auth-gated.)
    final url = '${Env.customerAppUrl}/track/$orderId';
    return OutlinedButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã sao chép link theo dõi: $url')),
        );
      },
      icon: const Icon(Icons.link_outlined),
      label: const Text('Sao chép link theo dõi'),
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

/// Prominent gift block on the merchant order detail — tells staff to
/// prepare a greeting card + wrapping. Shows the message, recipient
/// (name + phone) and the "Gói quà" / "Ẩn giá" flags. Gold-accented so it
/// stands out from the rest of the order. Rendered only when `order.isGift`.
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
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: BananColors.gold.withValues(alpha: 0.12),
        border: Border.all(
          color: BananColors.gold.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: BananSpacing.xs),
              Text(
                'ĐƠN QUÀ TẶNG',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: BananColors.cocoa,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.xs),
          Wrap(
            spacing: BananSpacing.xs,
            runSpacing: BananSpacing.xs,
            children: [
              if (order.giftWrap) const _GiftFlagChip(label: 'Gói quà'),
              if (order.hidePrice)
                const _GiftFlagChip(label: 'Ẩn giá trên phiếu'),
            ],
          ),
          if (order.giftMessage != null && order.giftMessage!.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.sm),
            Text(
              'Lời chúc (in lên thiệp):',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '“${order.giftMessage!}”',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (hasRecipient) ...[
            const SizedBox(height: BananSpacing.sm),
            Text(
              'Người nhận:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${order.giftRecipientName ?? '—'}'
              '${(order.giftRecipientPhone?.isNotEmpty ?? false) ? ' · ${order.giftRecipientPhone}' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Small gold pill used inside the merchant gift block for the wrap / hide
/// flags.
class _GiftFlagChip extends StatelessWidget {
  const _GiftFlagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: BananColors.gold.withValues(alpha: 0.28),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BananColors.cocoa,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Merchant-side VAT invoice block — purely informational. Surfaces the
/// company-invoice info the customer entered at checkout so the merchant
/// can issue the invoice on their external tax platform. The app does NOT
/// track issuance status — once info is captured, merchant handles the
/// rest outside the app.
class _VatInvoiceBlock extends StatelessWidget {
  const _VatInvoiceBlock({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
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
              const Icon(Icons.receipt_long_outlined, size: 18),
              const SizedBox(width: BananSpacing.xs),
              Text(
                'Yêu cầu xuất hoá đơn VAT',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.xs),
          if (order.invoiceCompanyName != null)
            Text(
              order.invoiceCompanyName!,
              style: theme.textTheme.bodyLarge,
            ),
          if (order.invoiceTaxId != null)
            Text(
              'MST: ${order.invoiceTaxId}',
              style: theme.textTheme.bodySmall,
            ),
          if (order.invoiceAddress != null)
            Text(
              order.invoiceAddress!,
              style: theme.textTheme.bodySmall,
            ),
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

/// Renders the cake-wizard payload as kitchen instructions on the
/// merchant order row. Same payload shape as the customer view, but
/// laid out for production read-back (bold "Chữ trên bánh", explicit
/// candle count, link to reference image, free-text note).
class _MerchantPersonalizationBlock extends StatelessWidget {
  const _MerchantPersonalizationBlock({required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = payload['textOnCake'] as String?;
    final candle = candleTicketLabel(payload);
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
              const Icon(
                Icons.cake_outlined,
                size: 14,
                color: BananColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Cá nhân hoá · Hướng dẫn bếp',
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
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Chữ trên bánh: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: '"$text"'),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (candle != null)
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Nến: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: candle),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
          if (flavorLine != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Vị macaron: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: flavorLine),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (note != null && note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Ghi chú: ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: note),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
