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
                loading: () => const Center(child: CircularProgressIndicator()),
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
                  final list = aggregateKitchenStock(
                    rows,
                    type: _type,
                    query: _query,
                  );
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

/// Pure aggregation behind the counter stock screen, kept top-level so it is
/// unit-testable. Counts ONLY the kitchen's STOCK location: the other
/// locations (SUPPLIER, PRODUCTION, STORE, SCRAP) are the negative side of
/// stock moves — summing them with STOCK cancels real on-hand out to 0.
/// Lots of one product inside STOCK are still summed; free = qty − reserved.
List<KitchenStockRow> aggregateKitchenStock(
  List<MfgOnHand> rows, {
  String? type,
  String query = '',
}) {
  final byCode = <String, KitchenStockRow>{};
  for (final r in rows) {
    if (r.locationCode != 'STOCK') continue;
    if (type != null && r.productType != type) continue;
    final acc = byCode.putIfAbsent(
      r.productCode,
      () => KitchenStockRow(
        code: r.productCode,
        name: r.productNameVi,
        uomCode: r.uomCode,
      ),
    );
    acc.qty += r.quantity;
    acc.free += r.freeQty;
  }
  final q = query.trim().toLowerCase();
  return byCode.values
      .where(
        (r) =>
            q.isEmpty ||
            r.name.toLowerCase().contains(q) ||
            r.code.toLowerCase().contains(q),
      )
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}

class KitchenStockRow {
  KitchenStockRow({
    required this.code,
    required this.name,
    required this.uomCode,
  });
  final String code;
  final String name;
  final String uomCode;
  double qty = 0;
  double free = 0;
}
