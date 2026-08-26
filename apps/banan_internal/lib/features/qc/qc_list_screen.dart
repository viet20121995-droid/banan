import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/internal_shell.dart';
import '../../shared/widgets.dart';

final storesProvider = FutureProvider<List<StoreRef>>((ref) async {
  final res = await ref.watch(internalApiProvider).stores();
  return res.when(success: (s) => s, failure: (f) => throw Exception(f.message ?? f.code));
});

class QcListScreen extends ConsumerStatefulWidget {
  const QcListScreen({super.key});

  @override
  ConsumerState<QcListScreen> createState() => _QcListScreenState();
}

class _QcListScreenState extends ConsumerState<QcListScreen> {
  Result<List<QcListItem>, AppFailure>? _state;
  String? _storeId;
  String? _status;
  String? _outcome;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = null);
    final res = await ref.read(internalApiProvider).qcList(
          storeId: _storeId,
          status: _status,
          outcome: _outcome,
          from: _range?.start,
          to: _range?.end,
        );
    if (mounted) setState(() => _state = res);
  }

  Future<void> _create() async {
    final stores = ref.read(storesProvider).valueOrNull ?? [];
    if (stores.isEmpty) {
      showSnack(context, 'Chưa tải được danh sách chi nhánh.');
      return;
    }
    var storeId = _storeId ?? stores.first.id;
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo phiên kiểm tra QC'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: storeId,
                decoration: const InputDecoration(labelText: 'Chi nhánh'),
                items: [
                  for (final s in stores)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setLocal(() => storeId = v ?? storeId),
              ),
              const SizedBox(height: BananSpacing.md),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text('Ngày kiểm tra: ${vnDate.format(date)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now().subtract(const Duration(days: 60)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final res = await ref
        .read(internalApiProvider)
        .qcCreate(storeId: storeId, inspectionDate: date);
    if (!mounted) return;
    res.when(
      success: (detail) => context.go('/qc/${detail.id}'),
      failure: (f) => showFailure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(storesProvider).valueOrNull ?? const <StoreRef>[];
    return InternalShell(
      title: 'QC — Kiểm tra chất lượng',
      actions: [
        IconButton(
          tooltip: 'So sánh 4 chi nhánh',
          icon: const Icon(Icons.stacked_bar_chart_outlined),
          onPressed: () => context.go('/qc/compare'),
        ),
        IconButton(tooltip: 'Tải lại', icon: const Icon(Icons.refresh), onPressed: _load),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(BananSpacing.lg),
            child: Wrap(
              spacing: BananSpacing.md,
              runSpacing: BananSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _filterDrop(
                  'Chi nhánh',
                  _storeId,
                  [for (final s in stores) (s.id, s.name)],
                  (v) {
                    _storeId = v;
                    _load();
                  },
                ),
                _filterDrop(
                  'Trạng thái',
                  _status,
                  const [
                    ('DRAFT', 'Nháp'),
                    ('IN_PROGRESS', 'Đang chấm'),
                    ('COMPLETED', 'Hoàn tất'),
                  ],
                  (v) {
                    _status = v;
                    _load();
                  },
                ),
                _filterDrop(
                  'Kết quả',
                  _outcome,
                  const [
                    ('PASS', 'Đạt'),
                    ('FAIL', 'Không đạt'),
                    ('CRITICAL_FAIL', 'Critical fail'),
                  ],
                  (v) {
                    _outcome = v;
                    _load();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _range == null
                        ? 'Khoảng ngày'
                        : '${vnDate.format(_range!.start)} – ${vnDate.format(_range!.end)}',
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2026),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                      initialDateRange: _range,
                    );
                    _range = picked;
                    await _load();
                  },
                ),
                if (_range != null || _storeId != null || _status != null || _outcome != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _storeId = null;
                        _status = null;
                        _outcome = null;
                        _range = null;
                      });
                      _load();
                    },
                    child: const Text('Xoá lọc'),
                  ),
                PrimaryButton(
                  label: 'Tạo phiên kiểm tra',
                  icon: Icons.add,
                  onPressed: _create,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FetchBody<List<QcListItem>>(
              state: _state,
              onRetry: _load,
              builder: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Chưa có phiên kiểm tra',
                    message: 'Bấm "Tạo phiên kiểm tra" để bắt đầu chấm QC một chi nhánh.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(BananSpacing.lg),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.sm),
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return ListTile(
                        shape: const RoundedRectangleBorder(borderRadius: BananRadii.rmd),
                        tileColor: Theme.of(context).colorScheme.surface,
                        onTap: () => context.go('/qc/${it.id}'),
                        title: Text('${it.store.name} · ${vnDate.format(it.inspectionDate.toLocal())}'),
                        subtitle: Text(
                          '${it.code} · ${it.inspectorName}'
                          '${it.revision > 1 ? ' · bản ${it.revision}' : ''}',
                        ),
                        trailing: Wrap(
                          spacing: BananSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (it.riskCount > 0)
                              const StatusBadge(label: 'RISK', intent: StatusIntent.danger, dense: true),
                            if (it.overallPercent != null)
                              Text(
                                '${it.overallPercent!.toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            StatusBadge(
                              label: it.status == 'COMPLETED'
                                  ? qcOutcomeLabel(it.outcome)
                                  : qcStatusLabel(it.status),
                              intent: it.status == 'COMPLETED'
                                  ? qcOutcomeIntent(it.outcome)
                                  : qcStatusIntent(it.status),
                              dense: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDrop(
    String label,
    String? value,
    List<(String, String)> options,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String?>(
        // initialValue only applies at creation — key the widget by value so
        // "Xoá lọc" (programmatic reset) recreates it and the display clears.
        key: ValueKey('$label-$value'),
        initialValue: value,
        isDense: true,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem<String?>(child: Text('Tất cả')),
          for (final (v, l) in options)
            DropdownMenuItem<String?>(value: v, child: Text(l, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    );
  }
}
