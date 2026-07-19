import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'mo_list_screen.dart' show mfgStateColor, mfgStateLabels;
import 'production_providers.dart';

final _fmt = NumberFormat.decimalPattern('vi_VN');

/// One manufacturing order: status, components with Available / Not-available
/// badges, and the state-driven action buttons that walk it Draft → Confirmed →
/// Produced. Writes are gated to managers; everyone else sees a read-only card.
class MoDetailScreen extends ConsumerWidget {
  const MoDetailScreen({required this.moId, super.key});
  final String moId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(moDetailProvider(moId));
    final canProduce = ref.watch(canProduceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lệnh sản xuất')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (mo) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(moDetailProvider(moId)),
          child: ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              _Header(mo: mo),
              const SizedBox(height: BananSpacing.lg),
              Text(
                'Thành phần',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: BananSpacing.sm),
              for (final c in mo.components) _ComponentTile(component: c),
              if (mo.state == 'DONE') ...[
                const SizedBox(height: BananSpacing.lg),
                _DoneCard(mo: mo),
              ],
              const SizedBox(height: BananSpacing.xl),
              if (canProduce)
                _Actions(mo: mo)
              else
                Text(
                  'Chỉ quản lý bếp mới thao tác được lệnh sản xuất.',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.mo});
  final MfgOrderDetail mo;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = mfgStateColor(mo.state);
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
              Expanded(child: Text(mo.code, style: theme.textTheme.titleLarge)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.14),
                  borderRadius: BananRadii.rPill,
                ),
                child: Text(
                  mfgStateLabels[mo.state] ?? mo.state,
                  style: TextStyle(color: c, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${mo.productNameVi} · SL ${mo.qtyToProduce.toStringAsFixed(0)}${mo.uomCode}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.component});
  final MfgComponent component;
  @override
  Widget build(BuildContext context) {
    final ok = component.isAvailable;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(component.productNameVi),
      subtitle: Text('Cần: ${component.qtyToConsume.toStringAsFixed(0)}'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (ok ? BananColors.success : BananColors.danger)
              .withValues(alpha: 0.14),
          borderRadius: BananRadii.rPill,
        ),
        child: Text(
          ok ? 'Đủ hàng' : 'Thiếu',
          style: TextStyle(
            color: ok ? BananColors.success : BananColors.danger,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.mo});
  final MfgOrderDetail mo;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: BananColors.success.withValues(alpha: 0.08),
        border: Border.all(color: BananColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đã sản xuất', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          if (mo.lotName != null) Text('Lô: ${mo.lotName}'),
          Text('Sản lượng: ${mo.qtyProduced.toStringAsFixed(0)}${mo.uomCode}'),
          Text('Giá thành: ${_fmt.format(mo.totalCost)} đ'),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.mo});
  final MfgOrderDetail mo;
  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _busy = false;

  /// Any MO transition (confirm/reserve/produce/cancel) shifts state, counts,
  /// stock and the boards. Invalidate the whole cluster — passing a family
  /// provider bare invalidates every cached filter (e.g. moListProvider for
  /// CONFIRMED as well as null), so a list reached via a state filter can't keep
  /// a stale row.
  void _invalidateRelated() {
    ref
      ..invalidate(moDetailProvider(widget.mo.id))
      ..invalidate(moListProvider)
      ..invalidate(moCountsProvider)
      ..invalidate(scheduleProvider)
      ..invalidate(shopFloorProvider)
      ..invalidate(onHandProvider)
      ..invalidate(expiringLotsProvider);
  }

  Future<void> _run(
    Future<Result<void, AppFailure>> Function() op,
    String ok,
  ) async {
    setState(() => _busy = true);
    final res = await op();
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (_) {
        _invalidateRelated();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok)));
      },
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(manufacturingApiProvider);
    final id = widget.mo.id;
    final state = widget.mo.state;

    final buttons = <Widget>[];
    if (state == 'DRAFT') {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() => api.confirm(id), 'Đã xác nhận lệnh.'),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Xác nhận'),
        ),
      );
    }
    if (state == 'CONFIRMED' || state == 'PROGRESS') {
      buttons.addAll([
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() => api.checkAvailability(id), 'Đã kiểm tra tồn.'),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Kiểm tra tồn'),
        ),
        OutlinedButton.icon(
          onPressed:
              _busy ? null : () => _run(() => api.reserve(id), 'Đã giữ hàng.'),
          icon: const Icon(Icons.bookmark_added_outlined),
          label: const Text('Giữ hàng'),
        ),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                    () => api.produce(id),
                    'Đã sản xuất — sinh lô + nhập kho.',
                  ),
          icon: const Icon(Icons.factory_outlined),
          label: const Text('Sản xuất'),
        ),
      ]);
    }
    if (state != 'DONE' && state != 'CANCEL') {
      buttons.add(
        TextButton.icon(
          onPressed:
              _busy ? null : () => _run(() => api.cancel(id), 'Đã huỷ lệnh.'),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Huỷ lệnh'),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: BananSpacing.sm,
      runSpacing: BananSpacing.sm,
      children: buttons,
    );
  }
}
