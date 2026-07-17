import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';
import 'xlsx_download.dart';

/// Merchant + admin report center. The date range is the source of truth
/// for every panel on the screen — change it once, every section refetches.
///
/// Today's behaviour:
///   - Picks last 30 days by default.
///   - 3 panels (KPIs, daily revenue table, best-sellers).
///   - "Xuất Excel" downloads a 4-sheet workbook for the same range.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  /// Both `from` and `to` are ICT-local calendar days. We don't carry a
  /// time-of-day — the backend snaps to 00:00 / 23:59 ICT on each end.
  late DateTime _from;
  late DateTime _to;
  bool _downloading = false;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 30));
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      locale: const Locale('vi'),
      helpText: 'Chọn khoảng ngày',
      saveText: 'Áp dụng',
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  Future<void> _downloadExcel() async {
    setState(() {
      _downloading = true;
      _downloadError = null;
    });
    final res = await ref.read(reportsApiProvider).exportXlsx(
          from: _ymd(_from),
          to: _ymd(_to),
        );
    // Awaited: the success branch writes the file, so without this the
    // `_downloading = false` below fired while the save was still running —
    // spinner off, button live again, mid-download.
    await res.when(
      success: (bytes) async {
        try {
          await saveXlsx(bytes, 'banan-report-${_ymd(_from)}_${_ymd(_to)}.xlsx');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tải file Excel.')),
          );
        } catch (e) {
          if (!mounted) return;
          setState(() => _downloadError = e.toString());
        }
      },
      failure: (f) async {
        if (!mounted) return;
        setState(() => _downloadError = f.message ?? f.code);
      },
    );
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd/MM/yyyy');
    final summaryAsync = ref.watch(
      _summaryProvider((from: _ymd(_from), to: _ymd(_to))),
    );
    final productsAsync = ref.watch(
      _productsProvider((from: _ymd(_from), to: _ymd(_to))),
    );

    return MerchantShell(
      title: 'Báo cáo',
      onRefresh: () async {
        ref.invalidate(_summaryProvider);
        ref.invalidate(_productsProvider);
      },
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          // ── Header — date range + download button ──────────────────
          Wrap(
            spacing: BananSpacing.md,
            runSpacing: BananSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text('${df.format(_from)} → ${df.format(_to)}'),
              ),
              FilledButton.icon(
                onPressed: _downloading ? null : _downloadExcel,
                icon: _downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined, size: 16),
                label: const Text('Xuất Excel'),
              ),
              Text(
                'File gồm 4 sheet: Tổng quan · Sản phẩm bán chạy · Đơn hàng · Hoàn tiền',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          if (_downloadError != null) ...[
            const SizedBox(height: BananSpacing.sm),
            Text(
              'Lỗi tải file: $_downloadError',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: BananSpacing.xl),

          // ── KPIs ───────────────────────────────────────────────────
          summaryAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(BananSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Text(
              'Không tải được tổng quan: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            data: (s) => _SummaryGrid(summary: s),
          ),
          const SizedBox(height: BananSpacing.xxl),

          // ── Daily revenue table ────────────────────────────────────
          Text('Doanh thu theo ngày', style: theme.textTheme.titleLarge),
          const SizedBox(height: BananSpacing.md),
          summaryAsync.maybeWhen(
            orElse: () => const SizedBox(height: 80),
            data: (s) => _DailyTable(rows: s.daily),
          ),
          const SizedBox(height: BananSpacing.xxl),

          // ── Best sellers ───────────────────────────────────────────
          Text('Sản phẩm bán chạy', style: theme.textTheme.titleLarge),
          const SizedBox(height: BananSpacing.md),
          productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Không tải được: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            data: (items) => _ProductsTable(items: items),
          ),
          const SizedBox(height: BananSpacing.xxxl),
        ],
      ),
    );
  }
}

typedef _RangeKey = ({String from, String to});

final _summaryProvider =
    FutureProvider.autoDispose.family<ReportSummary, _RangeKey>(
  (ref, key) async {
    final api = ref.watch(reportsApiProvider);
    final res = await api.summary(from: key.from, to: key.to);
    return res.when(
      success: (s) => s,
      failure: (f) => throw Exception(f.message ?? f.code),
    );
  },
);

final _productsProvider =
    FutureProvider.autoDispose.family<List<ProductSalesRow>, _RangeKey>(
  (ref, key) async {
    final api = ref.watch(reportsApiProvider);
    final res = await api.productSales(from: key.from, to: key.to);
    return res.when(
      success: (s) => s,
      failure: (f) => throw Exception(f.message ?? f.code),
    );
  },
);

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final ReportSummary summary;

  String _vnd(double v) => NumberFormat.currency(
        locale: 'vi_VN',
        symbol: '₫',
        decimalDigits: 0,
      ).format(v);

  @override
  Widget build(BuildContext context) {
    final t = summary.totals;
    final cards = <_KpiData>[
      _KpiData('Doanh thu (hoàn tất)', _vnd(t.revenue),
          icon: Icons.payments_outlined,),
      _KpiData('Đơn hoàn tất', '${t.completed}',
          icon: Icons.check_circle_outline,),
      _KpiData('Đơn huỷ', '${t.cancelled}', icon: Icons.cancel_outlined),
      _KpiData('Tổng đơn (cả huỷ)', '${t.orders}',
          icon: Icons.receipt_long_outlined,),
      _KpiData('Giá trị TB / đơn', _vnd(t.avgOrderValue),
          icon: Icons.trending_up,),
      _KpiData('Phí giao thu', _vnd(t.deliveryFees),
          icon: Icons.delivery_dining_outlined,),
      _KpiData('Khuyến mãi áp', _vnd(t.coupons),
          icon: Icons.local_offer_outlined,),
      _KpiData('Điểm đã đổi', _vnd(t.pointsBurned),
          icon: Icons.stars_outlined,),
      _KpiData('Đã hoàn tiền', _vnd(t.refundedAmount),
          icon: Icons.assignment_return_outlined,),
      _KpiData(
        'Pickup vs Delivery',
        '${summary.fulfillment.pickup} · ${summary.fulfillment.delivery}',
        icon: Icons.swap_horiz_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100
            ? 5
            : c.maxWidth >= 800
                ? 4
                : c.maxWidth >= 520
                    ? 3
                    : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisExtent: 92,
            crossAxisSpacing: BananSpacing.md,
            mainAxisSpacing: BananSpacing.md,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => _KpiCard(data: cards[i]),
        );
      },
    );
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, {required this.icon});
  final String label;
  final String value;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          Icon(data.icon, color: theme.colorScheme.primary),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  data.value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTable extends StatelessWidget {
  const _DailyTable({required this.rows});
  final List<DailyRevenue> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    if (rows.isEmpty) {
      return Text(
        'Không có đơn nào trong khoảng ngày này.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: DataTable(
        headingTextStyle: theme.textTheme.titleSmall,
        columns: const [
          DataColumn(label: Text('Ngày')),
          DataColumn(label: Text('Số đơn'), numeric: true),
          DataColumn(label: Text('Doanh thu'), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text(r.date)),
              DataCell(Text('${r.orders}')),
              DataCell(Text(fmt.format(r.revenue))),
            ],),
        ],
      ),
    );
  }
}

class _ProductsTable extends StatelessWidget {
  const _ProductsTable({required this.items});
  final List<ProductSalesRow> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    if (items.isEmpty) {
      return Text(
        'Chưa có sản phẩm nào bán được trong kỳ.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: DataTable(
        headingTextStyle: theme.textTheme.titleSmall,
        columns: const [
          DataColumn(label: Text('Hạng'), numeric: true),
          DataColumn(label: Text('Sản phẩm')),
          DataColumn(label: Text('Số lượng'), numeric: true),
          DataColumn(label: Text('Doanh thu'), numeric: true),
        ],
        rows: [
          for (var i = 0; i < items.length; i++)
            DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(items[i].productName)),
              DataCell(Text('${items[i].unitsSold}')),
              DataCell(Text(fmt.format(items[i].revenue))),
            ],),
        ],
      ),
    );
  }
}
