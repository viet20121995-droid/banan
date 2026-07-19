import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../notifications/notifications_controller.dart';
import 'mo_list_screen.dart' show mfgStateColor, mfgStateLabels;
import 'production_providers.dart';

/// Entry point of the "Sản xuất" section — a production workspace: KPI strip,
/// today's scheduled work, a workflow-ordered quick-action grid, and the
/// expiring-lot warning list. Kept separate from the orders Kanban (that's `/`).
class ProductionDashboardScreen extends ConsumerWidget {
  const ProductionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(moCountsProvider);
    final expiring = ref.watch(expiringLotsProvider);
    final alerts = ref.watch(qualityAlertsProvider);
    final schedule = ref.watch(scheduleProvider);
    final unread =
        ref.watch(notificationsControllerProvider.select((s) => s.unread));
    final canProduce = ref.watch(canProduceProvider);
    // Intl.defaultLocale is vi_VN (set in main) — weekday renders in Vietnamese.
    final today = DateFormat('EEEE, dd/MM').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sản xuất'),
            Text(
              today,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Thông báo',
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Bảng đơn (bếp)',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(moCountsProvider)
            ..invalidate(expiringLotsProvider)
            ..invalidate(qualityAlertsProvider)
            ..invalidate(scheduleProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            // ── KPI strip ──
            counts.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => _ErrorLine(e),
              data: (rows) {
                final byState = {for (final r in rows) r.state: r.count};
                final alertCount = alerts.valueOrNull?.length;
                final expiringCount = expiring.valueOrNull?.length;
                return Wrap(
                  spacing: BananSpacing.sm,
                  runSpacing: BananSpacing.sm,
                  children: [
                    for (final e in const [
                      ('DRAFT', Icons.edit_note),
                      ('CONFIRMED', Icons.fact_check_outlined),
                      ('PROGRESS', Icons.autorenew),
                      ('DONE', Icons.check_circle_outline),
                    ])
                      _KpiCard(
                        label: mfgStateLabels[e.$1] ?? e.$1,
                        count: byState[e.$1] ?? 0,
                        icon: e.$2,
                        color: mfgStateColor(e.$1),
                        onTap: () =>
                            context.push('/production/orders?state=${e.$1}'),
                      ),
                    // count null (still loading / fetch failed) renders '—',
                    // never a reassuring green 0.
                    _KpiCard(
                      label: 'Cảnh báo QC',
                      count: alertCount,
                      icon: Icons.warning_amber_outlined,
                      color: alertCount == null
                          ? BananColors.outline
                          : alertCount > 0
                              ? BananColors.danger
                              : BananColors.success,
                      onTap: () => context.push('/production/alerts'),
                    ),
                    _KpiCard(
                      label: 'Lô sắp hết hạn',
                      count: expiringCount,
                      icon: Icons.schedule,
                      color: expiringCount == null
                          ? BananColors.outline
                          : expiringCount > 0
                              ? BananColors.gold
                              : BananColors.success,
                      onTap: () => context.push('/production/stock'),
                    ),
                  ],
                );
              },
            ),

            // ── Hôm nay ──
            const SizedBox(height: BananSpacing.xl),
            _SectionHeader(
              title: 'Việc hôm nay',
              actionLabel: 'Lịch đầy đủ',
              onAction: () => context.push('/production/schedule'),
            ),
            const SizedBox(height: BananSpacing.sm),
            schedule.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => _ErrorLine(e),
              data: (items) => _TodayList(items: items),
            ),

            // ── Thao tác nhanh (theo luồng làm việc) ──
            const SizedBox(height: BananSpacing.xl),
            const _SectionHeader(title: 'Thao tác nhanh'),
            const SizedBox(height: BananSpacing.sm),
            _QuickActionsGrid(canProduce: canProduce),

            // ── HSD sắp hết ──
            const SizedBox(height: BananSpacing.xl),
            const _SectionHeader(title: 'Lô sắp hết hạn (3 ngày)'),
            const SizedBox(height: BananSpacing.sm),
            expiring.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => _ErrorLine(e),
              data: (lots) => lots.isEmpty
                  ? const _EmptyNote('Không có lô nào sắp hết hạn.')
                  : Column(
                      children: [
                        for (final lot in lots) _ExpiringTile(lot: lot),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── sections ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;

  /// null = unknown (loading/error) — rendered as '—', not a fake 0.
  final int? count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BananRadii.rsm,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rsm,
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const Spacer(),
                Text(
                  count == null ? '—' : '$count',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: BananSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayList extends StatelessWidget {
  const _TodayList({required this.items});
  final List<MfgScheduleItem> items;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final today = _day(DateTime.now());
    final todays = <MfgScheduleItem>[];
    final overdue = <MfgScheduleItem>[];
    var backlog = 0;
    for (final it in items) {
      final d = it.scheduledDate;
      if (d == null) {
        backlog++;
      } else if (_day(d) == today) {
        todays.add(it);
      } else if (_day(d).isBefore(today)) {
        overdue.add(it);
      }
    }

    if (todays.isEmpty && overdue.isEmpty && backlog == 0) {
      return const _EmptyNote('Không có lệnh nào cần làm hôm nay.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in [...overdue, ...todays].take(6))
          _TodayTile(item: it, overdue: overdue.contains(it)),
        if (overdue.length + todays.length > 6)
          Padding(
            padding: const EdgeInsets.only(top: BananSpacing.xs),
            child: Text(
              '+${overdue.length + todays.length - 6} lệnh khác trong lịch',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        if (backlog > 0)
          Padding(
            padding: const EdgeInsets.only(top: BananSpacing.xs),
            child: Text(
              '$backlog lệnh chưa lên lịch',
              style: const TextStyle(color: BananColors.warning),
            ),
          ),
      ],
    );
  }
}

class _TodayTile extends StatelessWidget {
  const _TodayTile({required this.item, required this.overdue});
  final MfgScheduleItem item;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rsm,
        color: theme.colorScheme.surface,
        border: Border.all(
          color: overdue
              ? BananColors.danger.withValues(alpha: 0.5)
              : theme.dividerTheme.color ?? Colors.black12,
        ),
      ),
      child: ListTile(
        dense: true,
        shape: const RoundedRectangleBorder(borderRadius: BananRadii.rsm),
        onTap: () => context.push('/production/orders/${item.id}'),
        leading: Icon(
          overdue ? Icons.error_outline : Icons.play_circle_outline,
          color: overdue ? BananColors.danger : mfgStateColor(item.state),
          size: 20,
        ),
        title: Text(
          '${item.code} · ${item.productNameVi}',
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            '${item.qtyToProduce.toStringAsFixed(0)}${item.uomCode}',
            mfgStateLabels[item.state] ?? item.state,
            if (item.responsibleName != null) item.responsibleName!,
            if (overdue) 'QUÁ HẠN',
          ].join(' · '),
          style: overdue ? const TextStyle(color: BananColors.danger) : null,
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }
}

// ── quick actions ───────────────────────────────────────────────────────────

class _QuickAction {
  const _QuickAction(
    this.label,
    this.icon,
    this.route, {
    this.writeOnly = false,
  });
  final String label;
  final IconData icon;
  final String route;
  final bool writeOnly;
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.canProduce});
  final bool canProduce;

  // Workflow order: master data → recipe → inbound → order → boards → analysis.
  static const _actions = [
    _QuickAction(
      'Sản phẩm & NVL',
      Icons.category_outlined,
      '/production/products',
    ),
    _QuickAction(
      'Công thức (BoM)',
      Icons.menu_book_outlined,
      '/production/boms',
    ),
    _QuickAction(
      'Nhập kho NVL',
      Icons.add_box_outlined,
      '/production/receipt',
      writeOnly: true,
    ),
    _QuickAction('Lệnh sản xuất', Icons.list_alt, '/production/orders'),
    _QuickAction(
      'Lịch sản xuất',
      Icons.calendar_month_outlined,
      '/production/schedule',
    ),
    _QuickAction(
      'Xưởng (WO + QC)',
      Icons.precision_manufacturing_outlined,
      '/production/shop-floor',
    ),
    _QuickAction(
      'Tồn kho & lô',
      Icons.inventory_2_outlined,
      '/production/stock',
    ),
    _QuickAction(
      'Ghi hao hụt',
      Icons.delete_outline,
      '/production/scrap',
      writeOnly: true,
    ),
    _QuickAction('Báo cáo', Icons.bar_chart_outlined, '/production/reports'),
    _QuickAction(
      'Gợi ý mua hàng',
      Icons.shopping_cart_outlined,
      '/production/replenishment',
    ),
    _QuickAction('OEE thiết bị', Icons.speed_outlined, '/production/oee'),
    _QuickAction('Bảo trì', Icons.build_outlined, '/production/maintenance'),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _actions.where((a) => canProduce || !a.writeOnly).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 180).floor().clamp(2, 6);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: BananSpacing.sm,
          crossAxisSpacing: BananSpacing.sm,
          childAspectRatio: 2.6,
          children: [
            for (final a in visible) _QuickActionCard(action: a),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push(action.route),
      borderRadius: BananRadii.rsm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.md,
          vertical: BananSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rsm,
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          children: [
            Icon(action.icon, size: 20, color: BananColors.primary),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: Text(
                action.label,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── shared bits ─────────────────────────────────────────────────────────────

class _ExpiringTile extends StatelessWidget {
  const _ExpiringTile({required this.lot});
  final MfgExpiringLot lot;

  @override
  Widget build(BuildContext context) {
    final expiry = lot.expiryDate;
    final label =
        expiry == null ? '—' : DateFormat('dd/MM/yyyy').format(expiry);
    final soon = expiry != null &&
        expiry.isBefore(DateTime.now().add(const Duration(days: 1)));
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.schedule,
        color: soon ? BananColors.danger : BananColors.gold,
      ),
      title: Text('${lot.productNameVi} · ${lot.name}'),
      trailing: Text(
        'HSD $label',
        style: TextStyle(color: soon ? BananColors.danger : null),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.error);
  final Object error;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
        child: Text(
          'Lỗi: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
}
