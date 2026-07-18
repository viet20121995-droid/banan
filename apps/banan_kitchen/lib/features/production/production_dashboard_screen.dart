import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'production_providers.dart';

/// Entry point of the "Sản xuất" section — MO counts by state, a warning strip
/// for lots nearing expiry, and quick links into the order and stock lists.
/// Kept separate from the orders Kanban (that's `/`).
class ProductionDashboardScreen extends ConsumerWidget {
  const ProductionDashboardScreen({super.key});

  static const _stateLabels = {
    'DRAFT': 'Nháp',
    'CONFIRMED': 'Đã xác nhận',
    'PROGRESS': 'Đang làm',
    'DONE': 'Hoàn tất',
    'CANCEL': 'Đã huỷ',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(moCountsProvider);
    final expiring = ref.watch(expiringLotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản xuất'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Bảng đơn (bếp)',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(moCountsProvider);
          ref.invalidate(expiringLotsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            // ── Lệnh sản xuất theo trạng thái ──
            Text('Lệnh sản xuất', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: BananSpacing.sm),
            counts.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => _ErrorLine(e),
              data: (rows) {
                final byState = {for (final r in rows) r.state: r.count};
                return Wrap(
                  spacing: BananSpacing.sm,
                  runSpacing: BananSpacing.sm,
                  children: [
                    for (final entry in _stateLabels.entries)
                      _CountCard(
                        label: entry.value,
                        count: byState[entry.key] ?? 0,
                        onTap: () => context.push('/production/orders?state=${entry.key}'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: BananSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push('/production/shop-floor'),
              icon: const Icon(Icons.precision_manufacturing_outlined),
              label: const Text('Xưởng sản xuất (bắt đầu/hoàn tất + QC)'),
            ),
            const SizedBox(height: BananSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push('/production/schedule'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Lịch sản xuất (lên lịch + phân công)'),
            ),
            const SizedBox(height: BananSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push('/production/orders'),
              icon: const Icon(Icons.list_alt),
              label: const Text('Tất cả lệnh sản xuất'),
            ),
            const SizedBox(height: BananSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push('/production/stock'),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Tồn kho & lô'),
            ),

            const SizedBox(height: BananSpacing.xl),
            // ── HSD sắp hết ──
            Text('Lô sắp hết hạn (3 ngày)',
                style: Theme.of(context).textTheme.titleLarge,),
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

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.count, required this.onTap});
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BananRadii.rmd,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: theme.textTheme.headlineMedium),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ExpiringTile extends StatelessWidget {
  const _ExpiringTile({required this.lot});
  final MfgExpiringLot lot;

  @override
  Widget build(BuildContext context) {
    final expiry = lot.expiryDate;
    final label = expiry == null ? '—' : DateFormat('dd/MM/yyyy').format(expiry);
    final soon = expiry != null &&
        expiry.isBefore(DateTime.now().add(const Duration(days: 1)));
    return ListTile(
      dense: true,
      leading: Icon(Icons.schedule,
          color: soon ? BananColors.danger : BananColors.gold,),
      title: Text('${lot.productNameVi} · ${lot.name}'),
      trailing: Text('HSD $label',
          style: TextStyle(color: soon ? BananColors.danger : null),),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.error);
  final Object error;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
        child: Text('Lỗi: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),),
      );
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: BananSpacing.sm),
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),),
      );
}
