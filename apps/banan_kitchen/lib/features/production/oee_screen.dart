import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'production_providers.dart';

String _pct(double v) => '${(v * 100).round()}%';

/// OEE per work centre — an approximate directional metric (a bakery has no
/// shift/planned-time config). Availability = runtime/(runtime+downtime),
/// performance = standard/real minutes, quality = passed/total QC checks.
class OeeScreen extends ConsumerWidget {
  const OeeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const range = (null, null); // all-time
    final oee = ref.watch(oeeReportProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('OEE (hiệu suất thiết bị)')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(oeeReportProvider(range).future),
        child: oee.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: Text('Lỗi: $e'),
              ),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const _Empty();
            }
            return ListView(
              padding: const EdgeInsets.all(BananSpacing.lg),
              children: [
                Text(
                  'Ước tính định hướng: availability = chạy/(chạy+bảo trì), '
                  'performance = giờ chuẩn/giờ thực, quality = QC đạt/tổng.',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
                const SizedBox(height: BananSpacing.md),
                for (final r in rows) _OeeCard(row: r),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OeeCard extends StatelessWidget {
  const _OeeCard({required this.row});
  final MfgOeeRow row;

  Color _oeeColor(double v) => v >= 0.85
      ? BananColors.success
      : v >= 0.6
          ? BananColors.warning
          : BananColors.danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.sm),
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${row.nameVi} (${row.code})',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'OEE ${_pct(row.oee)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _oeeColor(row.oee),
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          _bar(context, 'Sẵn sàng', row.availability),
          _bar(context, 'Hiệu năng', row.performance),
          _bar(context, 'Chất lượng', row.quality),
          const SizedBox(height: BananSpacing.xs),
          Text(
            '${row.woCount} công đoạn · chạy ${row.runtimeMin} phút · bảo trì ${row.downtimeMin} phút',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, String label, double v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BananRadii.rsm,
              child: LinearProgressIndicator(
                value: v.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: BananSpacing.sm),
          SizedBox(width: 44, child: Text(_pct(v), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            title: 'Chưa đủ dữ liệu',
            message: 'Hoàn tất vài công đoạn ở xưởng sản xuất để tính OEE.',
            icon: Icons.speed_outlined,
          ),
        ],
      );
}
