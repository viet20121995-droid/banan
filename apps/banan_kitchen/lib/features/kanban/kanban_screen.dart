import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'kanban_controller.dart';

/// Simplified 4-column kanban: **Pending → Preparing → Ready → Completed**.
/// The first three are the live kitchen workflow; "Completed" is a virtual
/// column populated from today's dispatched orders so staff can see the
/// running tally without leaving the board.
class KanbanScreen extends ConsumerWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kanbanControllerProvider);
    final controller = ref.read(kanbanControllerProvider.notifier);
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.productionBoard),
        actions: [
          // Narrow phones can't fit the labeled button next to the other
          // actions — fall back to the compact icon there.
          if (MediaQuery.sizeOf(context).width >= 480)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: BananSpacing.sm,
                horizontal: BananSpacing.xs,
              ),
              child: FilledButton.tonalIcon(
                onPressed: () => context.push('/production'),
                icon: const Icon(Icons.factory_outlined, size: 18),
                label: const Text('Sản xuất'),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.factory_outlined),
              tooltip: 'Sản xuất',
              onPressed: () => context.push('/production'),
            ),
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Tổng đặt nội bộ',
            onPressed: () => context.push('/transfer-summary'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: s.analytics,
            onPressed: () => context.push('/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: s.refresh,
            onPressed: controller.refresh,
          ),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              switch (value) {
                case 'change-password':
                  context.push('/change-password');
                case 'logout':
                  ref.read(authControllerProvider.notifier).logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change-password',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_reset_outlined),
                  title: Text('Đổi mật khẩu'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout),
                  title: Text(s.signOut),
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.loading && state.orders.isEmpty
          ? const _BoardSkeleton()
          : (state.failure != null && state.orders.isEmpty)
              ? ErrorState(
                  message: authFailureMessage(state.failure!),
                  onRetry: controller.refresh,
                )
              : _Board(state: state, controller: controller),
    );
  }
}

/// Loading placeholder shaped like the real board (stats bar + 4 columns
/// with ghost cards) so the layout doesn't jump when data arrives.
class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    final ghost =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);

    Widget block(double h, {double? w}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: ghost, borderRadius: BananRadii.rmd),
        );

    return Padding(
      padding: const EdgeInsets.all(BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          block(72),
          const SizedBox(height: BananSpacing.lg),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < 4; c++) ...[
                  if (c > 0) const SizedBox(width: BananSpacing.lg),
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        block(20),
                        const SizedBox(height: BananSpacing.md),
                        block(96),
                        const SizedBox(height: BananSpacing.sm),
                        block(96),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.state, required this.controller});

  final KanbanState state;
  final KanbanController controller;

  @override
  Widget build(BuildContext context) {
    final byColumn = state.activeByColumn;
    final completed = state.completedToday;

    return Padding(
      padding: const EdgeInsets.all(BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatsBar(state: state),
          const SizedBox(height: BananSpacing.lg),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Column(
                    title: 'Chờ nhận',
                    subtitle: 'Đơn mới, chờ bếp nhận',
                    accent: BananColors.warning,
                    cards: byColumn[KitchenStatus.pendingAck] ?? const [],
                    cardBuilder: (order) => _PendingCard(
                      order: order,
                      controller: controller,
                    ),
                  ),
                  const SizedBox(width: BananSpacing.lg),
                  _Column(
                    title: 'Đang làm',
                    subtitle: 'Đang trong bếp',
                    accent: BananColors.gold,
                    cards: byColumn[KitchenStatus.preparing] ?? const [],
                    cardBuilder: (order) => _PreparingCard(
                      order: order,
                      controller: controller,
                    ),
                  ),
                  const SizedBox(width: BananSpacing.lg),
                  _Column(
                    title: 'Sẵn sàng giao',
                    subtitle: 'Chờ giao đi / khách lấy',
                    accent: BananColors.success,
                    cards: byColumn[KitchenStatus.readyDispatch] ?? const [],
                    cardBuilder: (order) => _ReadyCard(
                      order: order,
                      controller: controller,
                    ),
                  ),
                  const SizedBox(width: BananSpacing.lg),
                  _Column(
                    title: 'Xong hôm nay',
                    subtitle: 'Đã xuất khỏi bếp trong ngày',
                    accent: BananColors.cocoaSoft,
                    cards: completed,
                    cardBuilder: (order) => _CompletedCard(order: order),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.state});
  final KanbanState state;

  @override
  Widget build(BuildContext context) {
    final byColumn = state.activeByColumn;
    final pending = byColumn[KitchenStatus.pendingAck]?.length ?? 0;
    final preparing = byColumn[KitchenStatus.preparing]?.length ?? 0;
    final ready = byColumn[KitchenStatus.readyDispatch]?.length ?? 0;
    final completed = state.completedToday.length;

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          _Stat(
            label: 'Chờ nhận',
            value: pending.toString(),
            icon: Icons.notifications_active_outlined,
            color: BananColors.warning,
            emphasize: pending > 0,
          ),
          _StatDivider(),
          _Stat(
            label: 'Đang làm',
            value: preparing.toString(),
            icon: Icons.cake_outlined,
            color: BananColors.gold,
          ),
          _StatDivider(),
          _Stat(
            label: 'Sẵn sàng',
            value: ready.toString(),
            icon: Icons.local_shipping_outlined,
            color: BananColors.success,
            emphasize: ready > 0,
          ),
          _StatDivider(),
          _Stat(
            label: 'Xong hôm nay',
            value: completed.toString(),
            icon: Icons.task_alt,
            color: BananColors.cocoaSoft,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(BananSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BananRadii.rmd,
              color: color.withValues(alpha: emphasize ? 0.18 : 0.10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: BananSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: emphasize ? color : null,
                ),
              ),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: BananSpacing.md),
      color: Theme.of(context).dividerTheme.color ?? Colors.black12,
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.cards,
    required this.cardBuilder,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final List<Order> cards;
  final Widget Function(Order) cardBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: BananColors.surfaceDim.withValues(alpha: 0.6),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                ),
              ),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BananSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rPill,
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Text(
                  '${cards.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Text(subtitle, style: theme.textTheme.bodySmall),
          ),
          const SizedBox(height: BananSpacing.md),
          if (cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BananSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 28,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  Text(
                    'Chưa có đơn',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (final order in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: BananSpacing.sm),
                child: cardBuilder(order),
              ),
        ],
      ),
    );
  }
}

/// Shared frame used by all 4 card variants.
class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.order, required this.child});
  final Order order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = [
      ...order.items.map((i) => '${i.quantity}× ${i.productName}'),
      // Supply lines the branch ordered from the kitchen warehouse — the baker
      // packs these with the delivery.
      ...order.mfgItems.map((m) => '${m.qty} ${m.uomCode} ${m.name} (vật tư)'),
    ].join('\n');

    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                order.fulfillmentType == FulfillmentType.delivery
                    ? Icons.delivery_dining_outlined
                    : Icons.storefront_outlined,
                size: 16,
              ),
              const SizedBox(width: BananSpacing.xs),
              Expanded(
                child: Text(order.code, style: theme.textTheme.titleSmall),
              ),
              Text(
                DateFormat.jm().format(order.updatedAt.toLocal()),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          // Which branch sent this order + which CHANNEL it came from. The
          // source badge reads Order.source (backend truth, never inferred
          // from notes); internal transfers also show requesting → receiving
          // branch, wholesale shows the buyer's company.
          const SizedBox(height: BananSpacing.xs),
          Wrap(
            spacing: BananSpacing.xs,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _sourceBadge(theme),
              if (order.storeName != null)
                _pill(
                  theme,
                  icon: Icons.storefront_outlined,
                  label: order.storeName!,
                  bg: BananColors.gold.withValues(alpha: 0.15),
                  fg: BananColors.cocoa,
                ),
              Text(
                order.fulfillmentType == FulfillmentType.delivery
                    ? 'Giao hàng'
                    : 'Đến lấy',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          if (order.source == 'INTERNAL_TRANSFER' &&
              order.destinationStoreName != null) ...[
            const SizedBox(height: 2),
            Text(
              'Giao về: ${order.destinationStoreName}'
              '${order.requestingStoreName != null && order.requestingStoreName != order.destinationStoreName ? ' (yêu cầu: ${order.requestingStoreName})' : ''}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: BananColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (order.source == 'WHOLESALE' &&
              order.wholesaleDeliveryAddress != null) ...[
            const SizedBox(height: 2),
            Text(
              'Giao đến: ${order.wholesaleDeliveryAddress}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: BananColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: BananSpacing.xs),
          Text(summary, style: theme.textTheme.bodySmall),
          const SizedBox(height: BananSpacing.sm),
          child,
        ],
      ),
    );
  }

  /// Channel badge from `Order.source`. WEB is the default channel and shows
  /// a neutral label; operational channels get their own color.
  Widget _sourceBadge(ThemeData theme) {
    final (label, color, icon) = switch (order.source) {
      'STAFF_COUNTER' => (
          'Tại quầy',
          BananColors.accent,
          Icons.point_of_sale_outlined,
        ),
      'WHOLESALE' => (
          order.wholesaleCompanyName == null
              ? 'Wholesale'
              : 'Wholesale · ${order.wholesaleCompanyName}',
          BananColors.primary,
          Icons.business_outlined,
        ),
      'INTERNAL_TRANSFER' => ('Nội bộ', BananColors.info, Icons.swap_horiz),
      _ => ('Web', BananColors.outline, Icons.public),
    };
    return _pill(
      theme,
      icon: icon,
      label: label,
      bg: color.withValues(alpha: 0.14),
      fg: color,
    );
  }

  Widget _pill(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(borderRadius: BananRadii.rPill, color: bg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.order, required this.controller});
  final Order order;
  final KanbanController controller;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      order: order,
      child: FilledButton.icon(
        onPressed: () async {
          final ok = await controller.accept(order.id);
          if (!context.mounted) return;
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chưa nhận được đơn, thử lại.')),
            );
          }
        },
        icon: const Icon(Icons.play_arrow, size: 16),
        label: const Text('Nhận đơn, bắt đầu làm'),
      ),
    );
  }
}

class _PreparingCard extends StatelessWidget {
  const _PreparingCard({required this.order, required this.controller});
  final Order order;
  final KanbanController controller;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      order: order,
      child: FilledButton.tonalIcon(
        onPressed: () async {
          final ok = await controller.markReady(order.id);
          if (!context.mounted) return;
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chưa cập nhật được, thử lại.')),
            );
          }
        },
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Làm xong'),
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.order, required this.controller});
  final Order order;
  final KanbanController controller;

  @override
  Widget build(BuildContext context) {
    final dispatchButton = FilledButton.icon(
      onPressed: () async {
        final ok = await controller.dispatch(order.id);
        if (!context.mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa xuất được đơn, thử lại.')),
          );
        }
      },
      icon: const Icon(Icons.local_shipping_outlined, size: 16),
      label: const Text('Xuất khỏi bếp'),
    );
    if (order.source != 'INTERNAL_TRANSFER') {
      return _CardFrame(order: order, child: dispatchButton);
    }
    // Internal transfers: the kitchen may trim quantities before handover
    // (thiếu nguyên liệu, hư hỏng…) — the branch then signs on the new numbers.
    return _CardFrame(
      order: order,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  _AdjustTransferDialog(order: order, controller: controller),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Sửa số lượng xuất'),
          ),
          const SizedBox(height: BananSpacing.xs),
          dispatchButton,
        ],
      ),
    );
  }
}

/// Kitchen edits the quantities that will actually ship on an internal
/// transfer. Prefilled with the ordered amounts; a note explains why.
class _AdjustTransferDialog extends ConsumerStatefulWidget {
  const _AdjustTransferDialog({required this.order, required this.controller});
  final Order order;
  final KanbanController controller;

  @override
  ConsumerState<_AdjustTransferDialog> createState() =>
      _AdjustTransferDialogState();
}

class _AdjustTransferDialogState extends ConsumerState<_AdjustTransferDialog> {
  late final Map<String, TextEditingController> _itemQty = {
    for (final i in widget.order.items)
      i.id: TextEditingController(text: '${i.quantity}'),
  };
  late final Map<String, TextEditingController> _mfgQty = {
    for (final m in widget.order.mfgItems)
      m.id: TextEditingController(
        text: m.qty == m.qty.roundToDouble() ? '${m.qty.round()}' : '${m.qty}',
      ),
  };
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _itemQty.values) {
      c.dispose();
    }
    for (final c in _mfgQty.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final items = <Map<String, dynamic>>[];
    for (final i in widget.order.items) {
      final qty = int.tryParse(_itemQty[i.id]!.text.trim());
      if (qty == null || qty < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Số lượng "${i.productName}" không hợp lệ.')),
        );
        return;
      }
      if (qty != i.quantity) {
        items.add({'orderItemId': i.id, 'quantity': qty});
      }
    }
    final mfgItems = <Map<String, dynamic>>[];
    for (final m in widget.order.mfgItems) {
      final qty = double.tryParse(_mfgQty[m.id]!.text.trim());
      if (qty == null || qty < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Số lượng "${m.name}" không hợp lệ.')),
        );
        return;
      }
      if (qty != m.qty) {
        mfgItems.add({'itemId': m.id, 'qty': qty});
      }
    }
    if (items.isEmpty && mfgItems.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final res = await ref.read(ordersApiProvider).adjustTransfer(
          widget.order.id,
          items: items,
          mfgItems: mfgItems,
          note: _note.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (_) {
        Navigator.of(context).pop();
        widget.controller.refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật số lượng xuất.')),
        );
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return AlertDialog(
      title: Text('Sửa số lượng xuất — ${order.code}'),
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
                        width: 80,
                        child: TextField(
                          controller: _itemQty[i.id],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
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
              for (final m in order.mfgItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: BananSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${m.name} (vật tư)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _mfgQty[m.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp('[0-9.]')),
                          ],
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            suffixText: '/${m.qty} ${m.uomCode}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Lý do (thiếu nguyên liệu, hư hỏng…)',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      order: order,
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: BananColors.success,
          ),
          const SizedBox(width: BananSpacing.xs),
          Text(
            _statusLabel(order.status),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.readyForPickup:
        return 'Chờ khách lấy';
      case OrderStatus.delivering:
        return 'Đang giao';
      case OrderStatus.completed:
        return 'Hoàn tất';
      default:
        return s.label;
    }
  }
}
