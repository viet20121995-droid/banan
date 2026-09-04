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
              message: 'Khi chi nhánh đặt hàng nội bộ, bảng tổng số lượng theo '
                  'từng chi nhánh sẽ hiện ở đây.',
              icon: Icons.table_chart_outlined,
            );
          }
          String qty(double v, String unit) => v == 0
              ? '—'
              : '${_fmt.format(v)}${unit == 'cái' ? '' : ' $unit'}';
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    // 4 branches + total fit a 1024px+ screen; phones scroll.
                    final minWidth = 260.0 + 96.0 * (data.stores.length + 1);
                    final table = _SummaryTable(data: data, qty: qty);
                    if (constraints.maxWidth >= minWidth) return table;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: minWidth, child: table),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.data, required this.qty});
  final TransferSummaryDto data;
  final String Function(double, String) qty;

  /// "Banan – Lê Thánh Tôn" → "Lê Thánh Tôn": every column is a Banan branch.
  static String _short(String name) =>
      name.replaceFirst(RegExp(r'^Banan\s*[–-]\s*'), '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.dividerTheme.color ?? Colors.black12;
    Widget cell(Widget child, {bool head = false}) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BananSpacing.sm,
            vertical: BananSpacing.sm,
          ),
          child: DefaultTextStyle.merge(
            style: head
                ? theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700)
                : theme.textTheme.bodyMedium,
            child: child,
          ),
        );
    Widget num(String v, {bool bold = false}) => cell(
          Text(
            v,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : null,
              color: v == '—' ? theme.colorScheme.outline : null,
            ),
          ),
        );
    return Table(
      columnWidths: {
        0: const FlexColumnWidth(3),
        for (var i = 1; i <= data.stores.length + 1; i++)
          i: const FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(horizontalInside: BorderSide(color: border)),
      children: [
        TableRow(
          decoration:
              BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
          children: [
            cell(const Text('Món / vật tư'), head: true),
            for (final s in data.stores)
              cell(Text(_short(s.name), textAlign: TextAlign.end), head: true),
            cell(const Text('Tổng', textAlign: TextAlign.end), head: true),
          ],
        ),
        for (final r in data.rows)
          TableRow(
            children: [
              cell(
                Row(
                  children: [
                    if (r.isSupply) ...[
                      Tooltip(
                        message: r.isDrinkIngredient
                            ? 'Nguyên liệu pha chế'
                            : 'Vật tư kho',
                        child: Icon(
                          r.isDrinkIngredient
                              ? Icons.local_cafe_outlined
                              : Icons.inventory_2_outlined,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(child: Text(r.label, softWrap: true)),
                  ],
                ),
              ),
              for (final s in data.stores)
                num(qty(r.byStore[s.id] ?? 0, r.unit)),
              num(qty(r.total, r.unit), bold: true),
            ],
          ),
      ],
    );
  }
}
