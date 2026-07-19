import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'production_providers.dart';

/// Master-data list: every manufacturing product (NVL / bao bì / bán thành
/// phẩm / thành phẩm) with type filter + search. Managers create and edit;
/// staff can look up codes and units.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

const mfgTypeLabels = {
  'RAW': 'NVL',
  'PACKAGING': 'Bao bì',
  'SEMI': 'Bán TP',
  'FINISHED': 'Thành phẩm',
};

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String? _type; // null = all
  String _search = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(adminProductsProvider);
    final canEdit = ref.watch(canProduceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sản phẩm & NVL')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/production/products/new'),
              icon: const Icon(Icons.add),
              label: const Text('Thêm'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminProductsProvider),
        child: products.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: ErrorState(
              title: 'Không tải được danh sách',
              message: '$e',
              onRetry: () => ref.invalidate(adminProductsProvider),
            ),
          ),
          data: (rows) {
            final q = _search.trim().toLowerCase();
            final filtered = rows.where((p) {
              if (!_showArchived && !p.active) return false;
              if (_type != null && p.type != _type) return false;
              if (q.isNotEmpty &&
                  !p.nameVi.toLowerCase().contains(q) &&
                  !p.code.toLowerCase().contains(q)) {
                return false;
              }
              return true;
            }).toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(BananSpacing.md),
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm theo tên hoặc mã…',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: BananSpacing.sm),
                Wrap(
                  spacing: BananSpacing.xs,
                  runSpacing: BananSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: _type == null,
                      onSelected: (_) => setState(() => _type = null),
                    ),
                    for (final e in mfgTypeLabels.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: _type == e.key,
                        onSelected: (_) => setState(() => _type = e.key),
                      ),
                    FilterChip(
                      label: const Text('Đã lưu trữ'),
                      selected: _showArchived,
                      onSelected: (v) => setState(() => _showArchived = v),
                    ),
                  ],
                ),
                const SizedBox(height: BananSpacing.md),
                if (filtered.isEmpty)
                  EmptyState(
                    title: q.isEmpty && _type != null
                        ? 'Chưa có ${mfgTypeLabels[_type]}'
                        : 'Không tìm thấy sản phẩm',
                    message: canEdit
                        ? 'Thêm sản phẩm để bắt đầu quản lý kho và công thức.'
                        : null,
                    icon: Icons.inventory_2_outlined,
                    action: canEdit
                        ? PrimaryButton(
                            label: 'Thêm sản phẩm',
                            icon: Icons.add,
                            onPressed: () =>
                                context.push('/production/products/new'),
                          )
                        : null,
                  )
                else
                  for (final p in filtered)
                    _ProductTile(product: p, canEdit: canEdit),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.canEdit});
  final MfgProduct product;
  final bool canEdit;

  static final _money = NumberFormat.decimalPattern('vi_VN');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = product.avgCost > 0 ? product.avgCost : product.standardCost;
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rsm,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: ListTile(
        dense: true,
        shape: const RoundedRectangleBorder(borderRadius: BananRadii.rsm),
        onTap: canEdit
            ? () => context.push('/production/products/${product.id}/edit')
            : null,
        title: Row(
          children: [
            Flexible(
              child: Text(
                product.nameVi,
                overflow: TextOverflow.ellipsis,
                style: product.active
                    ? null
                    : TextStyle(
                        color: theme.colorScheme.outline,
                        decoration: TextDecoration.lineThrough,
                      ),
              ),
            ),
            const SizedBox(width: BananSpacing.xs),
            StatusBadge(
              label: mfgTypeLabels[product.type] ?? product.type,
              intent: switch (product.type) {
                'RAW' => StatusIntent.info,
                'PACKAGING' => StatusIntent.neutral,
                'SEMI' => StatusIntent.progress,
                _ => StatusIntent.success,
              },
              dense: true,
            ),
            if (!product.active) ...[
              const SizedBox(width: BananSpacing.xs),
              const StatusBadge(
                label: 'Lưu trữ',
                intent: StatusIntent.warning,
                dense: true,
              ),
            ],
          ],
        ),
        subtitle: Text(
          [
            product.code,
            product.uomCode,
            if (product.tracking == 'LOT')
              product.useExpiration
                  ? 'Lô + HSD ${product.expirationDays}d'
                  : 'Theo lô',
            if (cost > 0) '${_money.format(cost)} đ/${product.uomCode}',
          ].join(' · '),
        ),
        trailing: canEdit ? const Icon(Icons.chevron_right, size: 18) : null,
      ),
    );
  }
}
