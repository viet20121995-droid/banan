import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                  onDayChanged: controller.setDay,
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
    required this.onDayChanged,
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
  final ValueChanged<DateTime> onDayChanged;
  final TextEditingController searchController;
  final String source;
  final bool urgentOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<bool> onUrgentChanged;

  List<Order> _ordersFor(KitchenBoardTab t) {
    switch (t) {
      case KitchenBoardTab.all:
        // Work first: pending, preparing, ready, then what's done.
        final sorted = List.of(state.orders)
          ..sort((a, b) {
            final byStage = KitchenBoardTab.stageOf(a).index
                .compareTo(KitchenBoardTab.stageOf(b).index);
            return byStage != 0 ? byStage : a.updatedAt.compareTo(b.updatedAt);
          });
        return sorted;
      case KitchenBoardTab.done:
        return state.done;
      case KitchenBoardTab.pending:
      case KitchenBoardTab.preparing:
      case KitchenBoardTab.ready:
        return state.activeByColumn[t.kitchenStatus] ?? const [];
    }
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
            day: state.day,
            onDayChanged: onDayChanged,
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
                ? _EmptyStage(tab: tab, day: state.day)
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: orders.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: BananSpacing.sm),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final stage = tab == KitchenBoardTab.all
                          ? KitchenBoardTab.stageOf(order)
                          : tab;
                      return KitchenOrderRow(
                        key: ValueKey(order.id),
                        order: order,
                        stage: stage,
                        showStage: tab == KitchenBoardTab.all,
                        onAccept: () => controller.accept(order.id),
                        onReady: () => controller.markReady(order.id),
                        onDispatch: () => controller.dispatch(order.id),
                        onAdjust: order.source == 'INTERNAL_TRANSFER'
                            ? () => showDialog<void>(
                                  context: context,
                                  builder: (_) => _AdjustTransferDialog(
                                    order: order,
                                    controller: controller,
                                  ),
                                )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStage extends StatelessWidget {
  const _EmptyStage({required this.tab, required this.day});
  final KitchenBoardTab tab;
  final DateTime day;

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
            'Không có đơn nào ở "${tab.label}" · ${kitchenDayLabel(day)}',
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
    required this.day,
    required this.onDayChanged,
    required this.searchController,
    required this.source,
    required this.urgentOnly,
    required this.onSearchChanged,
    required this.onSourceChanged,
    required this.onUrgentChanged,
  });

  final DateTime day;
  final ValueChanged<DateTime> onDayChanged;
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
        final dayBar = KitchenDayBar(day: day, onChanged: onDayChanged);
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
