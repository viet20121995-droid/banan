import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

final _fmt = NumberFormat.decimalPattern('vi_VN');

/// Read-only kitchen on-hand for the counter: the cashier answers "còn mấy
/// cái?" from here instead of calling the kitchen. Grouped per product,
/// summed across lots, with the finished cakes tab first.
final _kitchenOnHandProvider =
    FutureProvider.autoDispose<List<MfgOnHand>>((ref) async {
  final res = await ref.watch(manufacturingApiProvider).onHand();
  return res.when(
    success: (v) => v,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class KitchenStockScreen extends ConsumerStatefulWidget {
  const KitchenStockScreen({super.key});

  @override
  ConsumerState<KitchenStockScreen> createState() => _KitchenStockScreenState();
}

class _KitchenStockScreenState extends ConsumerState<KitchenStockScreen> {
  String _query = '';
  String? _type = 'FINISHED';

  static const _typeLabels = <String?, String>{
    'FINISHED': 'Bánh thành phẩm',
    'RAW': 'Nguyên liệu',
    'PACKAGING': 'Bao bì',
    null: 'Tất cả',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onHand = ref.watch(_kitchenOnHandProvider);
    return MerchantShell(
      title: 'Tồn kho bếp',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BananSpacing.lg,
              BananSpacing.lg,
              BananSpacing.lg,
              0,
            ),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm theo tên hoặc mã…',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: BananSpacing.lg,
              vertical: BananSpacing.sm,
            ),
            child: Row(
              children: [
                for (final entry in _typeLabels.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: BananSpacing.xs),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _type == entry.key,
                      onSelected: (_) => setState(() => _type = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(_kitchenOnHandProvider.future),
              child: onHand.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  children: [
                    Text(
                      'Lỗi: $e',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
                data: (rows) {
                  // Sum per product across lots/locations; keep uom + type.
                  final byCode = <String, _StockRow>{};
                  for (final r in rows) {
                    if (_type != null && r.productType != _type) continue;
                    final acc = byCode.putIfAbsent(
                      r.productCode,
                      () => _StockRow(
                        code: r.productCode,
                        name: r.productNameVi,
                        uomCode: r.uomCode,
                      ),
                    );
                    acc.qty += r.quantity;
                    acc.free += r.freeQty;
                  }
                  final list = byCode.values
                      .where(
                        (r) =>
                            _query.isEmpty ||
                            r.name.toLowerCase().contains(_query) ||
                            r.code.toLowerCase().contains(_query),
                      )
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));
                  if (list.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        EmptyState(
                          title: 'Không có hàng tồn',
                          message:
                              'Không tìm thấy sản phẩm nào khớp bộ lọc hiện tại.',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(BananSpacing.lg),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = list[i];
                      final low = r.free <= 0;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.name),
                        subtitle: Text(r.code),
                        trailing: Text(
                          '${_fmt.format(r.free)} ${r.uomCode}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: low
                                ? theme.colorScheme.error
                                : BananColors.success,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRow {
  _StockRow({required this.code, required this.name, required this.uomCode});
  final String code;
  final String name;
  final String uomCode;
  double qty = 0;
  double free = 0;
}
