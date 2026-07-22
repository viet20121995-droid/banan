import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'production_providers.dart';

/// Quality alerts opened by failed QC checks. Any kitchen role can view; a
/// manager advances an alert NEW → CONFIRMED (tiếp nhận) → SOLVED (đã xử lý).
class QualityAlertsScreen extends ConsumerWidget {
  const QualityAlertsScreen({super.key});

  static const _labels = {
    'NEW': 'Mới',
    'CONFIRMED': 'Đang xử lý',
    'SOLVED': 'Đã xử lý',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider(null));
    final canAct = ref.watch(canProduceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cảnh báo QC')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(alertsProvider(null).future),
        child: alerts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: Text('Lỗi: $e'),
              ),
            ],
          ),
          data: (list) {
            if (list.isEmpty) {
              return const _EmptyAlerts();
            }
            // Open alerts (NEW/CONFIRMED) first, solved last.
            final sorted = [...list]
              ..sort((a, b) => _rank(a.stage).compareTo(_rank(b.stage)));
            return ListView.separated(
              padding: const EdgeInsets.all(BananSpacing.md),
              itemCount: sorted.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.sm),
              itemBuilder: (_, i) =>
                  _AlertCard(alert: sorted[i], canAct: canAct),
            );
          },
        ),
      ),
    );
  }

  static int _rank(String stage) =>
      switch (stage) { 'NEW' => 0, 'CONFIRMED' => 1, _ => 2 };
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();
  @override
  Widget build(BuildContext context) => ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            title: 'Không có cảnh báo',
            message: 'Khi một điểm QC không đạt, cảnh báo sẽ hiện ở đây.',
            icon: Icons.verified_outlined,
          ),
        ],
      );
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert, required this.canAct});
  final MfgQualityAlert alert;
  final bool canAct;

  Color _color(String stage) => switch (stage) {
        'NEW' => BananColors.danger,
        'CONFIRMED' => BananColors.warning,
        _ => BananColors.success,
      };

  Future<void> _advance(
    BuildContext context,
    WidgetRef ref,
    String next,
  ) async {
    final res =
        await ref.read(manufacturingApiProvider).setAlertStage(alert.id, next);
    if (!context.mounted) return;
    res.when(
      success: (_) => ref.invalidate(alertsProvider(null)),
      failure: (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${f.message ?? f.code}')),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _color(alert.stage);
    final solved = alert.stage == 'SOLVED';
    return Container(
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
                  alert.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: solved ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BananRadii.rPill,
                ),
                child: Text(
                  QualityAlertsScreen._labels[alert.stage] ?? alert.stage,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (alert.description != null && alert.description!.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(alert.description!, style: theme.textTheme.bodyMedium),
          ],
          if (canAct && !solved) ...[
            const SizedBox(height: BananSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: alert.stage == 'NEW'
                  ? OutlinedButton(
                      onPressed: () => _advance(context, ref, 'CONFIRMED'),
                      child: const Text('Tiếp nhận'),
                    )
                  : FilledButton(
                      onPressed: () => _advance(context, ref, 'SOLVED'),
                      child: const Text('Đã xử lý'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
