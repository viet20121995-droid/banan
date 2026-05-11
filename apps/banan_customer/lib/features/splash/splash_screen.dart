import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerSplashScreen extends ConsumerWidget {
  const CustomerSplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(_healthProbeProvider);
    return AppScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Banan',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: BananSpacing.sm),
            Text(
              'Patisserie · Cold Cake · Crafted Daily',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: BananSpacing.xxxl),
            healthAsync.when(
              loading: () => const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => ErrorState(
                title: 'Cannot reach the kitchen',
                message: e.toString(),
                onRetry: () => ref.invalidate(_healthProbeProvider),
              ),
              data: (status) => _StatusPill(status: status),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small one-shot future provider that hits `/health` on splash mount.
final _healthProbeProvider = FutureProvider<HealthStatus>((ref) async {
  final api = ref.watch(healthApiProvider);
  final result = await api.getHealth();
  return result.when(
    success: (s) => s,
    failure: (f) => throw _ProbeException(f),
  );
});

class _ProbeException implements Exception {
  _ProbeException(this.failure);
  final AppFailure failure;
  @override
  String toString() => failure.message ?? failure.code;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final HealthStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.lg,
        vertical: BananSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: BananColors.success.withValues(alpha: 0.12),
        border: Border.all(color: BananColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: BananColors.success),
          const SizedBox(width: BananSpacing.sm),
          Text(
            'Backend OK · ${status.environment}',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: BananColors.success),
          ),
        ],
      ),
    );
  }
}
