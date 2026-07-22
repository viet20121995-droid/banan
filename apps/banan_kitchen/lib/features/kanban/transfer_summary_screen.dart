import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _fmt = NumberFormat.decimalPattern('vi_VN');

/// Aggregated picking sheet: every live internal transfer on the board,
/// one row per item, one column per receiving branch + a bold total —
/// the baker batches production off this instead of opening each card.
final _transferSummaryProvider =
    FutureProvider.autoDispose<TransferSummaryDto>((ref) async {
  final res = await ref.watch(ordersApiProvider).transferSummary();
  return res.when(
    success: (v) => v,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class TransferSummaryScreen extends ConsumerWidget {
  const TransferSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(_transferSummaryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng đặt nội bộ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: () => ref.invalidate(_transferSummaryProvider),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Lỗi: $e',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        data: (data) {
          if (data.rows.isEmpty) {
            return const EmptyState(
              title: 'Không có đơn nội bộ nào đang chờ',
              message:
                  'Khi chi nhánh đặt hàng nội bộ, bảng tổng số lượng theo '
                  'từng chi nhánh sẽ hiện ở đây.',
              icon: Icons.table_chart_outlined,
            );
          }
          String qty(double v, String unit) =>
              v == 0 ? '—' : '${_fmt.format(v)}${unit == 'cái' ? '' : ' $unit'}';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gộp từ ${data.orderCount} đơn nội bộ đang trên bảng bếp '
                  '(chưa xuất). Cột = chi nhánh nhận.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                const SizedBox(height: BananSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                    columns: [
                      const DataColumn(label: Text('Món / vật tư')),
                      for (final s in data.stores)
                        DataColumn(label: Text(s.name)),
                      const DataColumn(
                        label: Text(
                          'Tổng',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    rows: [
                      for (final r in data.rows)
                        DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (r.isSupply) ...[
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 260),
                                    child: Text(
                                      r.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final s in data.stores)
                              DataCell(
                                Text(qty(r.byStore[s.id] ?? 0, r.unit)),
                              ),
                            DataCell(
                              Text(
                                qty(r.total, r.unit),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
