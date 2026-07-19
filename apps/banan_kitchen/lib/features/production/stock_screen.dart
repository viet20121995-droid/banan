import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'production_providers.dart';
import 'products_screen.dart' show mfgTypeLabels;

/// Stock view for the Sản xuất section: on-hand by product/lot with unit,
/// expiry and reserved-vs-free, grouped by product type, plus the near-expiry
/// list. Receipt/scrap live in their own forms.
class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onHand = ref.watch(onHandProvider);
    final expiring = ref.watch(expiringLotsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tồn kho & lô')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(onHandProvider)
            ..invalidate(expiringLotsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            onHand.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (rows) {
                // Only the internal STOCK location matters to the kitchen;
                // supplier/production/scrap are plumbing.
                final stock =
                    rows.where((r) => r.locationCode == 'STOCK').toList();
                if (stock.isEmpty) {
                  return EmptyState(
                    title: 'Kho trống',
                    message: 'Nhập kho NVL để bắt đầu.',
                    icon: Icons.inventory_2_outlined,
                    action: PrimaryButton(
                      label: 'Nhập kho NVL',
                      icon: Icons.add_box_outlined,
                      onPressed: () => context.push('/production/receipt'),
                    ),
                  );
                }
                // Group by product type in workflow order.
                final byType = <String, List<MfgOnHand>>{};
                for (final r in stock) {
                  byType.putIfAbsent(r.productType, () => []).add(r);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final type in const [
                      'RAW',
                      'PACKAGING',
                      'SEMI',
                      'FINISHED',
                      '',
                    ])
                      if (byType[type] case final group?) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: BananSpacing.md,
                            bottom: BananSpacing.xs,
                          ),
                          child: Text(
                            mfgTypeLabels[type] ?? 'Khác',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        for (final r in group) _StockTile(row: r),
                      ],
                  ],
                );
              },
            ),
            const SizedBox(height: BananSpacing.xl),
            Text(
              'Lô sắp hết hạn',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: BananSpacing.sm),
            expiring.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (lots) => lots.isEmpty
                  ? Text(
                      'Không có lô sắp hết hạn.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    )
                  : Column(
                      children: [
                        for (final lot in lots)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.schedule,
                              color: BananColors.gold,
                            ),
                            title: Text('${lot.productNameVi} · ${lot.name}'),
                            trailing: Text(
                              lot.expiryDate == null
                                  ? '—'
                                  : DateFormat('dd/MM/yyyy')
                                      .format(lot.expiryDate!),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.row});
  final MfgOnHand row;

  @override
  Widget build(BuildContext context) {
    final qty = row.quantity.toStringAsFixed(0);
    final negative = row.quantity < 0;
    final reserved = row.reservedQty > 0;
    final expiry = row.expiryDate;
    final expirySoon = expiry != null &&
        expiry.isBefore(DateTime.now().add(const Duration(days: 3)));

    final parts = [
      if (row.lotName != null) 'Lô ${row.lotName}',
      if (expiry != null) 'HSD ${DateFormat('dd/MM').format(expiry)}',
      if (reserved)
        'Giữ ${row.reservedQty.toStringAsFixed(0)} · Trống ${row.freeQty.toStringAsFixed(0)}',
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(row.productNameVi),
      subtitle: parts.isEmpty
          ? null
          : Text(
              parts.join(' · '),
              style: TextStyle(
                color: expirySoon ? BananColors.danger : null,
              ),
            ),
      trailing: Text(
        '$qty ${row.uomCode}'.trim(),
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: negative
              ? BananColors.danger
              : reserved
                  ? BananColors.gold
                  : null,
        ),
      ),
    );
  }
}
