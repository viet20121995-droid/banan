import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'production_providers.dart';

final _fmt = NumberFormat.decimalPattern('vi_VN');
String _money(num v) => '${_fmt.format(v)} đ';
String _qty(num v, String uom) => '${_fmt.format(v)} $uom';

/// Replenishment suggestion: raw materials whose open-MO demand outruns free
/// stock. Advisory only — it says what to buy and roughly what it costs; the
/// actual order goes through "Đơn mua hàng" (purchase orders).
class ReplenishmentScreen extends ConsumerWidget {
  const ReplenishmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rep = ref.watch(replenishmentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gợi ý mua hàng')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(replenishmentProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(BananSpacing.lg),
          children: rep.when(
            loading: () => const [
              Center(
                child: Padding(
                  padding: EdgeInsets.only(top: BananSpacing.xxl),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
            error: (e, _) => [
              Text(
                'Lỗi: $e',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            data: (r) {
              if (r.rows.isEmpty) {
                return [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: BananSpacing.xl),
                    child: Text(
                      'Đủ nguyên liệu cho các lệnh đang mở.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ];
              }
              return [
                Text(
                  'Cần mua để đủ cho các lệnh đang mở (nháp/đã xác nhận/đang làm). '
                  'Ước tính theo giá vốn bình quân — đặt hàng thật ở mục Đơn mua hàng.',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: BananSpacing.md),
                Container(
                  padding: const EdgeInsets.all(BananSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BananRadii.rmd,
                    border: Border.all(
                      color: Theme.of(context).dividerTheme.color ??
                          Colors.black12,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ước tính chi phí mua',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _money(r.estCost),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: BananColors.warning,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BananSpacing.lg),
                for (final row in r.rows)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      row.kind == 'MAKE'
                          ? Icons.cake_outlined
                          : Icons.shopping_cart_outlined,
                      color: BananColors.warning,
                    ),
                    title: Text('${row.productNameVi} (${row.productCode})'),
                    subtitle: Text(
                      'Cần ${_qty(row.demand, row.uomCode)} · Còn ${_qty(row.available, row.uomCode)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          row.kind == 'MAKE'
                              ? 'Làm thêm ${_qty(row.shortfall, row.uomCode)}'
                              : 'Mua ${_qty(row.shortfall, row.uomCode)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '~ ${_money(row.estCost)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ),
      ),
    );
  }
}
