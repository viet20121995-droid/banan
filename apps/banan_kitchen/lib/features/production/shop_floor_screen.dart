import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mo_list_screen.dart' show mfgStateColor, mfgStateLabels;
import 'production_providers.dart';

/// Tablet-first shop floor: work orders as columns per work center, each card
/// Start / Pause / Done with inline QC entry. Finishing an operation is blocked
/// by the backend until its quality points pass — the buttons here mirror that.
class ShopFloorScreen extends ConsumerWidget {
  const ShopFloorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floor = ref.watch(shopFloorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Xưởng sản xuất')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shopFloorProvider),
        child: floor.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Lỗi: $e')),
          data: (cards) {
            if (cards.isEmpty) {
              return const Center(
                child: Text('Không có công đoạn nào đang chờ.'),
              );
            }
            // Group by work center → one column each.
            final byWc = <String, List<MfgWorkOrderCard>>{};
            for (final c in cards) {
              byWc.putIfAbsent(c.workCenterNameVi, () => []).add(c);
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(BananSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in byWc.entries)
                    _WcColumn(title: entry.key, cards: entry.value),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WcColumn extends StatelessWidget {
  const _WcColumn({required this.title, required this.cards});
  final String title;
  final List<MfgWorkOrderCard> cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.only(right: BananSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: BananSpacing.sm),
            // Viewport-tall column inside the horizontal board scroll: cards get
            // their own vertical scroll so a busy work center doesn't overflow.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [for (final c in cards) _WoCard(card: c)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WoCard extends ConsumerStatefulWidget {
  const _WoCard({required this.card});
  final MfgWorkOrderCard card;
  @override
  ConsumerState<_WoCard> createState() => _WoCardState();
}

class _WoCardState extends ConsumerState<_WoCard> {
  bool _busy = false;

  Future<void> _run(Future<Result<void, AppFailure>> Function() op) async {
    setState(() => _busy = true);
    final res = await op();
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (_) => ref.invalidate(shopFloorProvider),
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.card;
    final canRun = ref.watch(canRunFloorProvider);
    final api = ref.read(manufacturingApiProvider);
    final stateColor = mfgStateColor(c.state);

    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.sm),
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.moCode} · ${c.productNameVi}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.14),
                  borderRadius: BananRadii.rPill,
                ),
                child: Text(
                  mfgStateLabels[c.state] ?? c.state,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Text(c.operationNameVi, style: theme.textTheme.bodySmall),

          // ── QC points ──
          if (c.qualityPoints.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.sm),
            for (final qp in c.qualityPoints)
              _QcRow(workOrderId: c.id, point: qp),
          ],

          const SizedBox(height: BananSpacing.sm),
          if (canRun)
            Wrap(
              spacing: BananSpacing.xs,
              children: [
                if (c.state == 'READY')
                  FilledButton.icon(
                    onPressed:
                        _busy ? null : () => _run(() => api.startWo(c.id)),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Bắt đầu'),
                  ),
                if (c.state == 'PROGRESS') ...[
                  OutlinedButton.icon(
                    onPressed:
                        _busy ? null : () => _run(() => api.pauseWo(c.id)),
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Tạm dừng'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        _busy ? null : () => _run(() => api.doneWo(c.id)),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Hoàn tất'),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _QcRow extends ConsumerWidget {
  const _QcRow({required this.workOrderId, required this.point});
  final String workOrderId;
  final MfgQualityPointLite point;

  Color _resultColor(String? r) => switch (r) {
        'PASS' => BananColors.success,
        'FAIL' => BananColors.danger,
        _ => BananColors.cocoaSoft,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRun = ref.watch(canRunFloorProvider);
    final range = point.isMeasure
        ? ' (${point.normMin.toStringAsFixed(0)}–${point.normMax.toStringAsFixed(0)}${point.unit ?? ''})'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            point.latestResult == 'PASS'
                ? Icons.check_circle
                : point.latestResult == 'FAIL'
                    ? Icons.cancel
                    : Icons.radio_button_unchecked,
            size: 16,
            color: _resultColor(point.latestResult),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${point.titleVi}$range',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (canRun)
            TextButton(
              onPressed: () => _openCheck(context, ref),
              child: const Text('Kiểm tra'),
            ),
        ],
      ),
    );
  }

  Future<void> _openCheck(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _QcDialog(workOrderId: workOrderId, point: point),
    );
    if (done ?? false) ref.invalidate(shopFloorProvider);
  }
}

class _QcDialog extends ConsumerStatefulWidget {
  const _QcDialog({required this.workOrderId, required this.point});
  final String workOrderId;
  final MfgQualityPointLite point;
  @override
  ConsumerState<_QcDialog> createState() => _QcDialogState();
}

class _QcDialogState extends ConsumerState<_QcDialog> {
  final _value = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _submit({String? passFail}) async {
    double? v;
    if (widget.point.isMeasure) {
      v = double.tryParse(_value.text.trim());
      if (v == null) {
        setState(() => _error = 'Nhập giá trị đo.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref.read(manufacturingApiProvider).recordCheck(
          qualityPointId: widget.point.id,
          workOrderId: widget.workOrderId,
          measuredValue: v,
          passFail: passFail,
        );
    if (!mounted) return;
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() {
        _busy = false;
        _error = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.point;
    return AlertDialog(
      title: Text(p.titleVi),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.isMeasure) ...[
            Text(
              'Ngưỡng đạt: ${p.normMin.toStringAsFixed(0)}–${p.normMax.toStringAsFixed(0)}${p.unit ?? ''}',
            ),
            const SizedBox(height: BananSpacing.sm),
            TextField(
              controller: _value,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: 'Giá trị đo (${p.unit ?? ''})'),
            ),
          ] else
            const Text('Đánh giá công đoạn:'),
          if (_error != null) ...[
            const SizedBox(height: BananSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        if (p.isMeasure)
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? '…' : 'Lưu'),
          )
        else ...[
          OutlinedButton(
            onPressed: _busy ? null : () => _submit(passFail: 'FAIL'),
            child: const Text('Không đạt'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _submit(passFail: 'PASS'),
            child: const Text('Đạt'),
          ),
        ],
      ],
    );
  }
}
