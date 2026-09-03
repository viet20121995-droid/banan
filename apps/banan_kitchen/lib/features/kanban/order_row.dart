import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ── board tabs ──────────────────────────────────────────────────────────────

/// The four stages a kitchen order moves through. The first three are the
/// live kitchen workflow (`kitchenStatus`); [done] is "dispatched today".
enum KitchenBoardTab {
  pending('Chờ nhận', 'Đơn mới, chờ bếp nhận', Icons.notifications_active_outlined, BananColors.warning),
  preparing('Đang làm', 'Đang trong bếp', Icons.cake_outlined, BananColors.info),
  ready('Sẵn sàng giao', 'Chờ giao đi / khách lấy', Icons.local_shipping_outlined, BananColors.success),
  done('Xong hôm nay', 'Đã xuất khỏi bếp trong ngày', Icons.task_alt, BananColors.outline);

  const KitchenBoardTab(this.label, this.subtitle, this.icon, this.accent);

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;

  /// Kitchen-owned stage for this tab, null for the virtual "done" tab.
  KitchenStatus? get kitchenStatus => switch (this) {
        KitchenBoardTab.pending => KitchenStatus.pendingAck,
        KitchenBoardTab.preparing => KitchenStatus.preparing,
        KitchenBoardTab.ready => KitchenStatus.readyDispatch,
        KitchenBoardTab.done => null,
      };
}

/// Top status bar: one tab per stage with its live count. Replaces the old
/// side-by-side columns — the whole width goes to the order rows below.
class KitchenStatusTabs extends StatelessWidget {
  const KitchenStatusTabs({
    required this.selected,
    required this.counts,
    required this.onSelected,
    super.key,
  });

  final KitchenBoardTab selected;
  final Map<KitchenBoardTab, int> counts;
  final ValueChanged<KitchenBoardTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabs = [
            for (final tab in KitchenBoardTab.values)
              _StatusTab(
                tab: tab,
                count: counts[tab] ?? 0,
                selected: tab == selected,
                onTap: () => onSelected(tab),
              ),
          ];
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [for (final t in tabs) Expanded(child: t)],
            );
          }
          // Phone / narrow tablet: fixed-width tabs, scroll sideways.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [for (final t in tabs) SizedBox(width: 200, child: t)],
            ),
          );
        },
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.tab,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final KitchenBoardTab tab;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tab.accent;
    final live = count > 0 && tab != KitchenBoardTab.done;
    return Semantics(
      button: true,
      selected: selected,
      label: '${tab.label}: $count đơn',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            BananSpacing.md,
            BananSpacing.md,
            BananSpacing.md,
            BananSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.08) : null,
            border: Border(
              bottom: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(BananSpacing.sm),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rmd,
                  color: accent.withValues(alpha: live || selected ? 0.18 : 0.10),
                ),
                child: Icon(tab.icon, color: accent, size: 20),
              ),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    Text(
                      tab.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BananSpacing.sm),
              Text(
                '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: live ? accent : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── priority ────────────────────────────────────────────────────────────────

class KitchenPriority {
  const KitchenPriority(this.reason, {required this.overdue});

  final String reason;
  final bool overdue;
}

/// Operational priority is intentionally derived from timestamps already on
/// the order, so every kitchen client applies the same deterministic rule:
/// a scheduled order due within 2h (or past due), or a new order nobody has
/// accepted for 15 minutes.
KitchenPriority? kitchenPriority(Order order, [DateTime? clock]) {
  if (order.status != OrderStatus.sentToKitchen) return null;
  final now = clock ?? DateTime.now();
  final scheduled = order.scheduledFor?.toLocal();
  if (scheduled != null) {
    final remaining = scheduled.difference(now);
    if (remaining <= Duration.zero) {
      return KitchenPriority('quá giờ ${shortDuration(-remaining)}', overdue: true);
    }
    if (remaining <= const Duration(hours: 2)) {
      return KitchenPriority('còn ${shortDuration(remaining)}', overdue: false);
    }
  }
  if (order.kitchenStatus == KitchenStatus.pendingAck) {
    final waiting = now.difference(order.createdAt.toLocal());
    if (waiting >= const Duration(minutes: 15)) {
      return KitchenPriority('chờ nhận ${shortDuration(waiting)}', overdue: true);
    }
  }
  return null;
}

String shortDuration(Duration duration) {
  final minutes = duration.inMinutes.abs();
  if (minutes < 60) return '${minutes.clamp(1, 59)} phút';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '$hours giờ' : '$hours giờ $remainder phút';
}

// ── order row ───────────────────────────────────────────────────────────────

/// ONE order = ONE row. The header line carries identity, channel, timing
/// and — on the same line — the action for its current stage; the items the
/// baker has to make sit right underneath, inside the same row.
class KitchenOrderRow extends StatefulWidget {
  const KitchenOrderRow({
    required this.order,
    required this.tab,
    super.key,
    this.onAccept,
    this.onReady,
    this.onDispatch,
    this.onAdjust,
    this.clock,
  });

  final Order order;
  final KitchenBoardTab tab;

  /// Stage actions; each returns whether the server accepted the change.
  final Future<bool> Function()? onAccept;
  final Future<bool> Function()? onReady;
  final Future<bool> Function()? onDispatch;

  /// Internal transfers only — edit quantities before handover.
  final VoidCallback? onAdjust;

  /// Injectable "now" so tests can pin the priority signal.
  final DateTime? clock;

  @override
  State<KitchenOrderRow> createState() => _KitchenOrderRowState();
}

class _KitchenOrderRowState extends State<KitchenOrderRow> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action, String failMessage) async {
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.tab.accent;
    final border = theme.dividerTheme.color ?? Colors.black12;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      // Stack (not IntrinsicHeight): the header's LayoutBuilder can't
      // report intrinsics, and a Positioned strip needs none.
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BananSpacing.md,
                    BananSpacing.sm,
                    BananSpacing.md,
                    BananSpacing.sm,
                  ),
                  child: _header(theme),
                ),
                Divider(height: 1, color: border),
                Container(
                  color: theme.colorScheme.surfaceContainerLow,
                  padding: const EdgeInsets.fromLTRB(
                    BananSpacing.md,
                    BananSpacing.sm,
                    BananSpacing.md,
                    BananSpacing.md,
                  ),
                  child: _items(theme),
                ),
              ],
            ),
          ),
          // Stage color strip — readable from across the kitchen.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 5, color: accent),
          ),
        ],
      ),
    );
  }

  Widget _header(ThemeData theme) {
    final order = widget.order;
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BananRadii.rmd,
            color: widget.tab.accent.withValues(alpha: 0.12),
          ),
          child: Icon(
            order.fulfillmentType == FulfillmentType.delivery
                ? Icons.delivery_dining_outlined
                : Icons.storefront_outlined,
            size: 20,
            color: widget.tab.accent,
          ),
        ),
        const SizedBox(width: BananSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wrap, not Row: on a phone the code + timing flow onto a
              // second line instead of clipping.
              Wrap(
                spacing: BananSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    order.code,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    DateFormat.jm().format(order.updatedAt.toLocal()),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (order.scheduledFor != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 2),
                        Text(
                          'hẹn ${DateFormat('HH:mm dd/MM').format(order.scheduledFor!.toLocal())}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _meta(theme),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = _actions(theme);
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              if (actions != null) ...[
                const SizedBox(height: BananSpacing.sm),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: identity),
            if (actions != null) ...[
              const SizedBox(width: BananSpacing.md),
              actions,
            ],
          ],
        );
      },
    );
  }

  /// Channel + branch + fulfillment + priority, one wrapping line.
  Widget _meta(ThemeData theme) {
    final order = widget.order;
    final priority = kitchenPriority(order, widget.clock);
    final (sourceLabel, sourceColor, sourceIcon) = switch (order.source) {
      'STAFF_COUNTER' => ('Tại quầy', BananColors.info, Icons.point_of_sale_outlined),
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
    final destination = switch (order.source) {
      'INTERNAL_TRANSFER' when order.destinationStoreName != null => 'Giao về ${order.destinationStoreName}'
          '${order.requestingStoreName != null && order.requestingStoreName != order.destinationStoreName ? ' (yêu cầu: ${order.requestingStoreName})' : ''}',
      'WHOLESALE' when order.wholesaleDeliveryAddress != null => 'Giao đến ${order.wholesaleDeliveryAddress}',
      _ => null,
    };

    return Wrap(
      spacing: BananSpacing.sm,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Pill(icon: sourceIcon, label: sourceLabel, color: sourceColor),
        if (order.storeName != null)
          _Pill(icon: Icons.storefront_outlined, label: order.storeName!, color: BananColors.info),
        Text(
          order.fulfillmentType == FulfillmentType.delivery ? 'Giao hàng' : 'Đến lấy',
          style: theme.textTheme.labelSmall,
        ),
        if (destination != null)
          Text(
            destination,
            style: theme.textTheme.labelSmall?.copyWith(
              color: BananColors.info,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (priority != null)
          _Pill(
            icon: priority.overdue ? Icons.error_outline : Icons.schedule_outlined,
            label: 'Ưu tiên · ${priority.reason}',
            color: priority.overdue ? BananColors.danger : BananColors.warning,
            strong: true,
          ),
      ],
    );
  }

  /// The stage action(s) — null on the done tab, where a status label shows.
  Widget? _actions(ThemeData theme) {
    final order = widget.order;
    switch (widget.tab) {
      case KitchenBoardTab.pending:
        final accept = widget.onAccept;
        if (accept == null) return null;
        return FilledButton.icon(
          onPressed: _busy ? null : () => _run(accept, 'Chưa nhận được đơn, thử lại.'),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Nhận đơn'),
        );
      case KitchenBoardTab.preparing:
        final ready = widget.onReady;
        if (ready == null) return null;
        return FilledButton.icon(
          onPressed: _busy ? null : () => _run(ready, 'Chưa cập nhật được, thử lại.'),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Làm xong'),
        );
      case KitchenBoardTab.ready:
        final dispatch = widget.onDispatch;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (order.source == 'INTERNAL_TRANSFER' && widget.onAdjust != null) ...[
              OutlinedButton.icon(
                onPressed: _busy ? null : widget.onAdjust,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Sửa số lượng'),
              ),
              const SizedBox(width: BananSpacing.sm),
            ],
            if (dispatch != null)
              FilledButton.icon(
                onPressed: _busy ? null : () => _run(dispatch, 'Chưa xuất được đơn, thử lại.'),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Xuất khỏi bếp'),
              ),
          ],
        );
      case KitchenBoardTab.done:
        return _Pill(
          icon: Icons.check_circle_outline,
          label: _doneLabel(order.status),
          color: BananColors.success,
          strong: true,
        );
    }
  }

  static String _doneLabel(OrderStatus s) => switch (s) {
        OrderStatus.readyForPickup => 'Chờ khách lấy',
        OrderStatus.delivering => 'Đang giao',
        OrderStatus.completed => 'Hoàn tất',
        _ => s.label,
      };

  /// What to make: product lines first, then the supply lines a branch
  /// ordered from the warehouse (packed with the delivery). Lays out in as
  /// many columns as fit so a 12-line order stays one glance tall.
  Widget _items(ThemeData theme) {
    final order = widget.order;
    final lines = <Widget>[
      for (final i in order.items)
        _ItemLine(
          qty: '${i.quantity}',
          name: i.productName,
          detail: [
            if (i.variantLabel != null) i.variantLabel!,
            if (i.customMessage != null && i.customMessage!.trim().isNotEmpty)
              '“${i.customMessage!.trim()}”',
          ].join(' · '),
        ),
      for (final m in order.mfgItems)
        _ItemLine(
          qty: '${m.qty == m.qty.roundToDouble() ? m.qty.round() : m.qty} ${m.uomCode}',
          name: m.name,
          detail: 'vật tư',
          muted: true,
        ),
    ];
    final notes = order.notes?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = BananSpacing.md;
        final columns = (constraints.maxWidth / 300).floor().clamp(1, 4);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: gap,
              runSpacing: BananSpacing.xs,
              children: [for (final l in lines) SizedBox(width: width, child: l)],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: BananSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 16, color: BananColors.warning),
                  const SizedBox(width: BananSpacing.xs),
                  Expanded(
                    child: Text(
                      notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ItemLine extends StatelessWidget {
  const _ItemLine({
    required this.qty,
    required this.name,
    this.detail = '',
    this.muted = false,
  });

  final String qty;
  final String name;
  final String detail;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BananRadii.rsm,
              color: muted
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.06)
                  : theme.colorScheme.primary.withValues(alpha: 0.10),
            ),
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: muted ? theme.colorScheme.onSurface : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: muted ? theme.textTheme.bodySmall?.color : null,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(detail, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    this.strong = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BananSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: color.withValues(alpha: strong ? 0.14 : 0.10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
