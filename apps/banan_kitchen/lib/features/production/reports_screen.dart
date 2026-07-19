import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'production_providers.dart';

final _fmt = NumberFormat.decimalPattern('vi_VN');
String _money(num v) => '${_fmt.format(v)} đ';
String _qty(num v, String uom) => '${_fmt.format(v)} $uom';

/// Quick date-range presets shared by all three report tabs. "Tất cả" is the
/// whole history (no bounds); the others are the last N days ending today.
enum _RangePreset {
  d7('7 ngày'),
  d30('30 ngày'),
  all('Tất cả');

  const _RangePreset(this.label);
  final String label;

  MfgReportRange range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (this) {
      case _RangePreset.d7:
        return (today.subtract(const Duration(days: 6)), today);
      case _RangePreset.d30:
        return (today.subtract(const Duration(days: 29)), today);
      case _RangePreset.all:
        return (null, null);
    }
  }
}

/// Production reports: what was made, what it cost, and what was scrapped, over
/// a chosen window. All read-only — the numbers come straight from the produce
/// and scrap snapshots on the backend.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _RangePreset _preset = _RangePreset.d30;

  @override
  Widget build(BuildContext context) {
    final range = _preset.range();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Báo cáo sản xuất'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sản xuất'),
              Tab(text: 'Giá thành'),
              Tab(text: 'Hao hụt'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(BananSpacing.md),
              child: SegmentedButton<_RangePreset>(
                segments: [
                  for (final p in _RangePreset.values)
                    ButtonSegment(value: p, label: Text(p.label)),
                ],
                selected: {_preset},
                onSelectionChanged: (s) => setState(() => _preset = s.first),
                showSelectedIcon: false,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ProductionTab(range),
                  _CostTab(range),
                  _ScrapTab(range),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _statCard(
  BuildContext context,
  String label,
  String value, {
  Color? valueColor,
}) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.all(BananSpacing.md),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BananRadii.rmd,
      border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: BananSpacing.xxs),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, color: valueColor),
        ),
      ],
    ),
  );
}

Widget _empty(BuildContext context, String message) => Padding(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.xl),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      ),
    );

/// Wrap the async report body so RefreshIndicator + pull-to-refresh works even
/// on the loading/error states (they need a scrollable child).
Widget _reportBody<T>(
  BuildContext context,
  WidgetRef ref,
  ProviderBase<AsyncValue<T>> provider,
  List<Widget> Function(T data) children,
) {
  final async = ref.watch(provider);
  return RefreshIndicator(
    onRefresh: () async => ref.invalidate(provider),
    child: ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: async.when(
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
        data: children,
      ),
    ),
  );
}

class _ProductionTab extends ConsumerWidget {
  const _ProductionTab(this.range);
  final MfgReportRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _reportBody<MfgProductionReport>(
      context,
      ref,
      productionReportProvider(range),
      (r) => [
        Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.sm,
          children: [
            _statCard(context, 'Số lệnh hoàn tất', '${r.moCount}'),
            _statCard(
              context,
              'Tổng giá thành',
              _money(r.totalCost),
              valueColor: BananColors.success,
            ),
          ],
        ),
        const SizedBox(height: BananSpacing.lg),
        if (r.rows.isEmpty)
          _empty(context, 'Chưa có lệnh hoàn tất trong kỳ.')
        else
          for (final row in r.rows)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(row.productNameVi),
              subtitle: Text(
                '${row.moCount} lệnh · ${_qty(row.qtyProduced, row.uomCode)} · ĐG ${_money(row.avgUnitCost)}',
              ),
              trailing: Text(
                _money(row.totalCost),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
      ],
    );
  }
}

class _CostTab extends ConsumerWidget {
  const _CostTab(this.range);
  final MfgReportRange range;

  static const _cap =
      100; // ponytail: cap rows shown; a bakery's monthly MOs fit well under this

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _reportBody<MfgCostReport>(
      context,
      ref,
      costReportProvider(range),
      (r) {
        final shown = r.rows.take(_cap).toList();
        return [
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              _statCard(context, 'Nguyên liệu', _money(r.materialCost)),
              _statCard(context, 'Nhân công/máy', _money(r.operationCost)),
              _statCard(
                context,
                'Tổng',
                _money(r.totalCost),
                valueColor: BananColors.success,
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.lg),
          if (r.rows.isEmpty)
            _empty(context, 'Chưa có lệnh hoàn tất trong kỳ.')
          else ...[
            for (final row in shown)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${row.code} · ${row.productNameVi}'),
                subtitle: Text(
                  'NL ${_money(row.materialCost)} · NC ${_money(row.operationCost)} · ĐG ${_money(row.unitCost)}/${row.uomCode}',
                ),
                trailing: Text(
                  _money(row.totalCost),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (r.rows.length > _cap)
              Padding(
                padding: const EdgeInsets.only(top: BananSpacing.sm),
                child: Text(
                  'Hiển thị $_cap/${r.rows.length} lệnh mới nhất.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
          ],
        ];
      },
    );
  }
}

class _ScrapTab extends ConsumerWidget {
  const _ScrapTab(this.range);
  final MfgReportRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _reportBody<MfgScrapReport>(
      context,
      ref,
      scrapReportProvider(range),
      (r) => [
        Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.sm,
          children: [
            _statCard(context, 'Số lần hao hụt', '${r.count}'),
            _statCard(
              context,
              'Giá trị hao hụt',
              _money(r.value),
              valueColor: BananColors.danger,
            ),
          ],
        ),
        const SizedBox(height: BananSpacing.lg),
        if (r.byProduct.isEmpty)
          _empty(context, 'Không có hao hụt trong kỳ.')
        else ...[
          Text('Theo sản phẩm', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: BananSpacing.xs),
          for (final row in r.byProduct)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(row.productNameVi),
              subtitle:
                  Text('${_qty(row.qty, row.uomCode)} · ${row.count} lần'),
              trailing: Text(
                _money(row.value),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: BananSpacing.lg),
          Text('Theo lý do', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: BananSpacing.xs),
          for (final row in r.byReason)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(row.reason),
              subtitle: Text('${row.count} lần'),
              trailing: Text(
                _money(row.value),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ],
    );
  }
}
