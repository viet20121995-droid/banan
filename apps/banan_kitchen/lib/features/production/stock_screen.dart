import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'production_providers.dart';

/// Read-only stock view for the Sản xuất section: on-hand by product/lot/
/// location, plus the near-expiry list. Scrap + adjustments land in a later
/// increment; this makes what the produce flow changed visible.
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
          ref.invalidate(onHandProvider);
          ref.invalidate(expiringLotsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: [
            Text('Tồn kho', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: BananSpacing.sm),
            onHand.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (rows) {
                // Only the internal STOCK location matters to the kitchen;
                // supplier/production/scrap are plumbing.
                final stock = rows.where((r) => r.locationCode == 'STOCK').toList();
                if (stock.isEmpty) return const Text('Kho trống.');
                return Column(
                  children: [
                    for (final r in stock)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.productNameVi),
                        subtitle: r.lotName == null ? null : Text('Lô: ${r.lotName}'),
                        trailing: Text(r.quantity.toStringAsFixed(0)),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: BananSpacing.xl),
            Text('Lô sắp hết hạn', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: BananSpacing.sm),
            expiring.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi: $e'),
              data: (lots) => lots.isEmpty
                  ? Text('Không có lô sắp hết hạn.',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),)
                  : Column(
                      children: [
                        for (final lot in lots)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule, color: BananColors.gold),
                            title: Text('${lot.productNameVi} · ${lot.name}'),
                            trailing: Text(lot.expiryDate == null
                                ? '—'
                                : DateFormat('dd/MM/yyyy').format(lot.expiryDate!),),
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
