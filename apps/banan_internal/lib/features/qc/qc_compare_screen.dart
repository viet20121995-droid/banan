import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/internal_shell.dart';
import '../../shared/widgets.dart';

/// Side-by-side QC numbers for the 4 branches over a week or month.
class QcCompareScreen extends ConsumerStatefulWidget {
  const QcCompareScreen({super.key});

  @override
  ConsumerState<QcCompareScreen> createState() => _QcCompareScreenState();
}

class _QcCompareScreenState extends ConsumerState<QcCompareScreen> {
  Result<List<QcCompareRow>, AppFailure>? _state;
  bool _byMonth = false;
  DateTime _anchor = DateTime.now();

  (DateTime, DateTime) get _rangeBounds {
    if (_byMonth) {
      final start = DateTime(_anchor.year, _anchor.month);
      return (start, DateTime(_anchor.year, _anchor.month + 1, 0));
    }
    final monday = _anchor.subtract(Duration(days: (_anchor.weekday + 6) % 7));
    final start = DateTime(monday.year, monday.month, monday.day);
    return (start, start.add(const Duration(days: 6)));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = null);
    final (from, to) = _rangeBounds;
    final res = await ref.read(internalApiProvider).qcCompare(from, to);
    if (mounted) setState(() => _state = res);
  }

  void _shift(int direction) {
    setState(() {
      _anchor = _byMonth
          ? DateTime(_anchor.year, _anchor.month + direction, 1)
          : _anchor.add(Duration(days: 7 * direction));
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final (from, to) = _rangeBounds;
    return InternalShell(
      title: 'So sánh QC 4 chi nhánh',
      subtitle: '${vnDate.format(from)} – ${vnDate.format(to)}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: Wrap(
              spacing: BananSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Theo tuần')),
                    ButtonSegment(value: true, label: Text('Theo tháng')),
                  ],
                  selected: {_byMonth},
                  showSelectedIcon: false,
                  onSelectionChanged: (sel) {
                    setState(() => _byMonth = sel.first);
                    _load();
                  },
                ),
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FetchBody<List<QcCompareRow>>(
              state: _state,
              onRetry: _load,
              builder: (rows) {
                if (rows.every((r) => r.inspections == 0)) {
                  return const EmptyState(
                    icon: Icons.stacked_bar_chart_outlined,
                    title: 'Chưa có phiên QC hoàn tất trong khoảng này',
                    message: 'Chọn tuần/tháng khác hoặc hoàn tất một phiên kiểm tra.',
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Chi nhánh')),
                        DataColumn(label: Text('Số phiên'), numeric: true),
                        DataColumn(label: Text('Điểm TB'), numeric: true),
                        DataColumn(label: Text('Đạt'), numeric: true),
                        DataColumn(label: Text('Không đạt'), numeric: true),
                        DataColumn(label: Text('Critical'), numeric: true),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(
                            cells: [
                              DataCell(Text(r.store.name)),
                              DataCell(Text('${r.inspections}')),
                              DataCell(
                                Text(
                                  r.avgPercent == null ? '—' : '${r.avgPercent}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: r.avgPercent == null
                                        ? null
                                        : r.avgPercent! >= 80
                                            ? BananColors.success
                                            : BananColors.danger,
                                  ),
                                ),
                              ),
                              DataCell(Text('${r.pass}')),
                              DataCell(Text('${r.fail}')),
                              DataCell(
                                Text(
                                  '${r.criticalFail}',
                                  style: TextStyle(
                                    color: r.criticalFail > 0 ? BananColors.danger : null,
                                    fontWeight: r.criticalFail > 0 ? FontWeight.w700 : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
