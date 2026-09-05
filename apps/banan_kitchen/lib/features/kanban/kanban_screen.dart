import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'day_bar.dart';
import 'kanban_controller.dart';
import 'order_row.dart';

/// Kitchen order board: a day switcher (today on sign-in), a status bar on
/// top (Tất cả · Chờ nhận · Đang làm · Sẵn sàng giao · Đã xong, each with its
/// live count) and, below it, one full-width row per order in the selected
/// stage — identity, timing and the stage action on the header line, the
/// items to make underneath.
class KanbanScreen extends ConsumerStatefulWidget {
  const KanbanScreen({super.key});

  @override
  ConsumerState<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends ConsumerState<KanbanScreen> {
  final _searchController = TextEditingController();
  KitchenBoardTab _tab = KitchenBoardTab.all;
  String _source = 'ALL';
  bool _urgentOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Order order) {
    if (_source != 'ALL' && order.source != _source) return false;
    if (_urgentOnly && kitchenPriority(order) == null) return false;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = [
      order.code,
      order.storeName,
      order.wholesaleCompanyName,
      order.requestingStoreName,
      order.destinationStoreName,
      ...order.items.map((item) => item.productName),
      ...order.mfgItems.map((item) => item.name),
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kanbanControllerProvider);
    final controller = ref.read(kanbanControllerProvider.notifier);
    final s = ref.watch(stringsProvider);
    final filteredState = state.copyWith(
      orders: state.orders.where(_matches).toList(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.productionBoard),
        actions: [
          // Desktop navigation lives in the workspace sidebar. Keep these
          // routes reachable on smaller layouts where the sidebar is absent.
          if (MediaQuery.sizeOf(context).width < 1280) ...[
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
          ],
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
              : _Board(
                  state: filteredState,
                  controller: controller,
                  tab: _tab,
                  onTabChanged: (tab) => setState(() => _tab = tab),
                  onRangeChanged: controller.setRange,
                  searchController: _searchController,
                  source: _source,
                  urgentOnly: _urgentOnly,
                  onSearchChanged: (_) => setState(() {}),
                  onSourceChanged: (value) => setState(() => _source = value),
                  onUrgentChanged: (value) =>
                      setState(() => _urgentOnly = value),
                ),
    );
  }
}

/// Loading placeholder shaped like the real board (status bar + toolbar +
/// ghost rows) so the layout doesn't jump when data arrives.
class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    final ghost =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);

    Widget block(double h) => Container(
          height: h,
          decoration: BoxDecoration(color: ghost, borderRadius: BananRadii.rmd),
        );

    return Padding(
      padding: const EdgeInsets.all(BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          block(76),
          const SizedBox(height: BananSpacing.md),
          block(44),
          const SizedBox(height: BananSpacing.md),
          for (var r = 0; r < 3; r++) ...[
            block(132),
            const SizedBox(height: BananSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.state,
    required this.controller,
    required this.tab,
    required this.onTabChanged,
    required this.onRangeChanged,
    required this.searchController,
    required this.source,
    required this.urgentOnly,
    required this.onSearchChanged,
    required this.onSourceChanged,
    required this.onUrgentChanged,
  });

  final KanbanState state;
  final KanbanController controller;
  final KitchenBoardTab tab;
  final ValueChanged<KitchenBoardTab> onTabChanged;
  final void Function(DateTime from, DateTime to) onRangeChanged;
  final TextEditingController searchController;
  final String source;
  final bool urgentOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<bool> onUrgentChanged;

  /// The sheet an internal transfer is on: its delivery day on the Vietnam
  /// calendar (`yyyy-MM-dd`), matching the backend's `transferDayKey`.
  static String _sheetDay(Order o) {
    final vn =
        (o.scheduledFor ?? o.createdAt).toUtc().add(const Duration(hours: 7));
    return DateFormat('yyyy-MM-dd').format(vn);
  }

  /// The day an order belongs to on the board — when it has to be READY
  /// (scheduled slot), else the day it was placed (walk-in: make now).
  static DateTime _boardDay(Order o) {
    final d = (o.scheduledFor ?? o.createdAt).toLocal();
    return DateTime(d.year, d.month, d.day);
  }

  List<Order> _ordersFor(KitchenBoardTab t) {
    switch (t) {
      case KitchenBoardTab.all:
        // Work first: pending, preparing, ready, then what's done; inside a
        // stage the backend order holds (earliest ready-time first).
        final sorted = List.of(state.orders)
          ..sort(
            (a, b) => KitchenBoardTab.stageOf(a)
                .index
                .compareTo(KitchenBoardTab.stageOf(b).index),
          );
        return sorted;
      case KitchenBoardTab.done:
        return state.done;
      case KitchenBoardTab.pending:
      case KitchenBoardTab.preparing:
      case KitchenBoardTab.ready:
        return state.activeByColumn[t.kitchenStatus] ?? const [];
    }
  }

  /// Rows, with one day divider per calendar day when the range spans more
  /// than a day — so "next week" reads as a schedule, not a pile.
  List<Widget> _rows(BuildContext context, List<Order> orders) {
    final byDay = state.isSingleDay
        ? orders
        : (List.of(orders)
          ..sort((a, b) => _boardDay(a).compareTo(_boardDay(b))));
    final widgets = <Widget>[];
    DateTime? current;
    for (final order in byDay) {
      if (!state.isSingleDay) {
        final day = _boardDay(order);
        if (current == null || day != current) {
          current = day;
          final count = byDay.where((o) => _boardDay(o) == day).length;
          widgets.add(_DayDivider(day: day, count: count));
        }
      }
      final stage =
          tab == KitchenBoardTab.all ? KitchenBoardTab.stageOf(order) : tab;
      widgets.add(
        KitchenOrderRow(
          key: ValueKey(order.id),
          order: order,
          stage: stage,
          showStage: tab == KitchenBoardTab.all,
          onAccept: () => controller.accept(order.id),
          onReady: () => controller.markReady(order.id),
          onDispatch: () => controller.dispatch(order.id),
          onOpenSheet: order.source == 'INTERNAL_TRANSFER'
              ? () => context.go('/transfer-summary?day=${_sheetDay(order)}')
              : null,
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final orders = _ordersFor(tab);
    return Padding(
      padding: const EdgeInsets.all(BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitchenStatusTabs(
            selected: tab,
            counts: {
              for (final t in KitchenBoardTab.values) t: _ordersFor(t).length,
            },
            onSelected: onTabChanged,
          ),
          const SizedBox(height: BananSpacing.md),
          _BoardToolbar(
            from: state.from,
            to: state.to,
            onRangeChanged: onRangeChanged,
            searchController: searchController,
            source: source,
            urgentOnly: urgentOnly,
            onSearchChanged: onSearchChanged,
            onSourceChanged: onSourceChanged,
            onUrgentChanged: onUrgentChanged,
          ),
          const SizedBox(height: BananSpacing.md),
          Expanded(
            child: orders.isEmpty
                ? _EmptyStage(tab: tab, from: state.from, to: state.to)
                : Builder(
                    builder: (context) {
                      final rows = _rows(context, orders);
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: rows.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: BananSpacing.sm),
                        itemBuilder: (_, index) => rows[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.day, required this.count});
  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: BananSpacing.sm),
      child: Row(
        children: [
          Text(
            kitchenDayLabel(day),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: BananSpacing.sm),
          Text('$count đơn', style: theme.textTheme.bodySmall),
          const SizedBox(width: BananSpacing.sm),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _EmptyStage extends StatelessWidget {
  const _EmptyStage({required this.tab, required this.from, required this.to});
  final KitchenBoardTab tab;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tab.icon,
            size: 36,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: BananSpacing.sm),
          Text(
            'Không có đơn nào ở "${tab.label}" · ${kitchenRangeLabel(from, to)}',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(tab.subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BoardToolbar extends StatelessWidget {
  const _BoardToolbar({
    required this.from,
    required this.to,
    required this.onRangeChanged,
    required this.searchController,
    required this.source,
    required this.urgentOnly,
    required this.onSearchChanged,
    required this.onSourceChanged,
    required this.onUrgentChanged,
  });

  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onRangeChanged;
  final TextEditingController searchController;
  final String source;
  final bool urgentOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<bool> onUrgentChanged;

  static const _sources = <String, String>{
    'ALL': 'Tất cả',
    'WEB': 'Website',
    'STAFF_COUNTER': 'Tại quầy',
    'WHOLESALE': 'Wholesale',
    'INTERNAL_TRANSFER': 'Nội bộ',
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayBar =
            KitchenDayBar(from: from, to: to, onChanged: onRangeChanged);
        final search = SizedBox(
          width: constraints.maxWidth < 720 ? constraints.maxWidth : 280,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm mã đơn, sản phẩm, chi nhánh',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: const OutlineInputBorder(),
            ),
          ),
        );
        final filters = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in _sources.entries)
                Padding(
                  padding: const EdgeInsets.only(right: BananSpacing.xs),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: source == entry.key,
                    onSelected: (_) => onSourceChanged(entry.key),
                  ),
                ),
              const SizedBox(width: BananSpacing.xs),
              Tooltip(
                message: 'Đơn chờ nhận quá 15 phút hoặc đơn hẹn đến hạn '
                    'trong 2 giờ',
                child: FilterChip(
                  avatar: const Icon(Icons.priority_high, size: 16),
                  label: const Text('Cần ưu tiên'),
                  selected: urgentOnly,
                  onSelected: onUrgentChanged,
                ),
              ),
            ],
          ),
        );

        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: dayBar),
              const SizedBox(height: BananSpacing.sm),
              search,
              const SizedBox(height: BananSpacing.sm),
              filters,
            ],
          );
        }
        // Day + search + every source chip need ~1400px to share a line;
        // below that the chips get their own row instead of scrolling off.
        if (constraints.maxWidth < 1400) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  dayBar,
                  const SizedBox(width: BananSpacing.md),
                  Expanded(child: search),
                ],
              ),
              const SizedBox(height: BananSpacing.sm),
              filters,
            ],
          );
        }
        return Row(
          children: [
            dayBar,
            const SizedBox(width: BananSpacing.md),
            search,
            const SizedBox(width: BananSpacing.md),
            Expanded(child: filters),
          ],
        );
      },
    );
  }
}
