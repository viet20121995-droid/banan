import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KitchenSplashScreen extends ConsumerWidget {
  const KitchenSplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(_healthProbeProvider);
    return AppScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Banan · Kitchen',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: BananSpacing.sm),
            Text(
              'Central Kitchen Production Board',
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
                title: 'Backend unreachable',
                message: e.toString(),
                onRetry: () => ref.invalidate(_healthProbeProvider),
              ),
              data: (status) => Chip(
                avatar: const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: BananColors.success,
                ),
                label: Text('Backend OK · ${status.environment}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _healthProbeProvider = FutureProvider<HealthStatus>((ref) async {
  final api = ref.watch(healthApiProvider);
  final result = await api.getHealth();
  return result.when(
    success: (s) => s,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});
