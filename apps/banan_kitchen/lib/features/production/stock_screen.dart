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
enum _StockFilter { all, attention, reserved, expiring }

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _searchController = TextEditingController();
  _StockFilter _filter = _StockFilter.all;
  String _type = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(MfgOnHand row) {
    if (_type != 'ALL' && row.productType != _type) return false;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      final value = [row.productNameVi, row.productCode, row.lotName]
          .whereType<String>()
          .join(' ')
          .toLowerCase();
      if (!value.contains(query)) return false;
    }
    final expiresSoon = row.expiryDate != null &&
        row.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 3)));
    return switch (_filter) {
      _StockFilter.all => true,
      _StockFilter.attention => row.freeQty <= 0,
      _StockFilter.reserved => row.reservedQty > 0,
      _StockFilter.expiring => expiresSoon,
    };
  }

  @override
  Widget build(BuildContext context) {
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
                final visible = stock.where(_matches).toList();
                final productCount = stock
                    .map((row) => row.productCode)
                    .where((code) => code.isNotEmpty)
                    .toSet()
                    .length;
                String productKey(MfgOnHand row) => row.productCode.isEmpty
                    ? row.productNameVi
                    : row.productCode;
                final unavailable = stock
                    .where((row) => row.freeQty <= 0)
                    .map(productKey)
                    .toSet()
                    .length;
                final reserved = stock
                    .where((row) => row.reservedQty > 0)
                    .map(productKey)
                    .toSet()
                    .length;
                final expiringSoon = stock.where((row) {
                  final expiry = row.expiryDate;
                  return expiry != null &&
                      expiry.isBefore(
                        DateTime.now().add(const Duration(days: 3)),
                      );
                }).length;

                final byType = <String, List<MfgOnHand>>{};
                for (final r in visible) {
                  byType.putIfAbsent(r.productType, () => []).add(r);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StockSummary(
                      productCount: productCount,
                      unavailable: unavailable,
                      reserved: reserved,
                      expiring: expiringSoon,
                    ),
                    const SizedBox(height: BananSpacing.md),
                    _StockFilters(
                      searchController: _searchController,
                      filter: _filter,
                      type: _type,
                      onSearchChanged: (_) => setState(() {}),
                      onFilterChanged: (value) =>
                          setState(() => _filter = value),
                      onTypeChanged: (value) => setState(() => _type = value),
                    ),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('Không có tồn kho phù hợp bộ lọc.'),
                        ),
                      ),
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
                              color: BananColors.warning,
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

class _StockSummary extends StatelessWidget {
  const _StockSummary({
    required this.productCount,
    required this.unavailable,
    required this.reserved,
    required this.expiring,
  });

  final int productCount;
  final int unavailable;
  final int reserved;
  final int expiring;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Mặt hàng', productCount, Icons.category_outlined, BananColors.primary),
      (
        'Không còn tồn trống',
        unavailable,
        Icons.error_outline,
        BananColors.danger,
      ),
      (
        'Đã phân bổ cho SX',
        reserved,
        Icons.assignment_turned_in_outlined,
        BananColors.info,
      ),
      ('Lô sắp hết hạn', expiring, Icons.schedule, BananColors.warning),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.sm,
          children: [
            for (final item in items)
              Container(
                width: constraints.maxWidth < 620
                    ? (constraints.maxWidth - BananSpacing.sm) / 2
                    : 190,
                padding: const EdgeInsets.all(BananSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BananRadii.rsm,
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(item.$3, color: item.$4, size: 20),
                    const SizedBox(width: BananSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.$2}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            item.$1,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StockFilters extends StatelessWidget {
  const _StockFilters({
    required this.searchController,
    required this.filter,
    required this.type,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onTypeChanged,
  });

  final TextEditingController searchController;
  final _StockFilter filter;
  final String type;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_StockFilter> onFilterChanged;
  final ValueChanged<String> onTypeChanged;

  static const _types = <String, String>{
    'ALL': 'Tất cả loại',
    'RAW': 'Nguyên liệu',
    'PACKAGING': 'Bao bì',
    'SEMI': 'Bán thành phẩm',
    'FINISHED': 'Thành phẩm',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm tên, mã sản phẩm hoặc số lô',
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
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            );
            final typeMenu = DropdownButtonFormField<String>(
              initialValue: type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nhóm hàng',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final entry in _types.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) onTypeChanged(value);
              },
            );
            if (constraints.maxWidth < 620) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: BananSpacing.sm),
                  typeMenu,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: BananSpacing.sm),
                SizedBox(width: 210, child: typeMenu),
              ],
            );
          },
        ),
        const SizedBox(height: BananSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChoice(
                label: 'Tất cả',
                value: _StockFilter.all,
                selected: filter,
                onChanged: onFilterChanged,
              ),
              _FilterChoice(
                label: 'Không còn tồn trống',
                value: _StockFilter.attention,
                selected: filter,
                onChanged: onFilterChanged,
              ),
              _FilterChoice(
                label: 'Đã phân bổ cho lệnh SX',
                value: _StockFilter.reserved,
                selected: filter,
                onChanged: onFilterChanged,
              ),
              _FilterChoice(
                label: 'Sắp hết hạn',
                value: _StockFilter.expiring,
                selected: filter,
                onChanged: onFilterChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final _StockFilter value;
  final _StockFilter selected;
  final ValueChanged<_StockFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: BananSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onChanged(value),
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
    final unavailable = row.freeQty <= 0;
    final reserved = row.reservedQty > 0;
    final expiry = row.expiryDate;
    final expirySoon = expiry != null &&
        expiry.isBefore(DateTime.now().add(const Duration(days: 3)));

    final parts = [
      if (row.lotName != null) 'Lô ${row.lotName}',
      if (expiry != null) 'HSD ${DateFormat('dd/MM').format(expiry)}',
      if (reserved) 'Phân bổ cho SX ${row.reservedQty.toStringAsFixed(0)}',
      'Còn trống ${row.freeQty.toStringAsFixed(0)}',
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(row.productNameVi),
      subtitle: Text(
        parts.join(' · '),
        style: TextStyle(
          color: expirySoon ? BananColors.danger : null,
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$qty ${row.uomCode}'.trim(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: unavailable
                  ? BananColors.danger
                  : reserved
                      ? BananColors.info
                      : null,
            ),
          ),
          Text(
            'Tồn thực tế',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
