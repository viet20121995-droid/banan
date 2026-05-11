import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KitchenHomeScreen extends ConsumerWidget {
  const KitchenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final theme = Theme.of(context);
    final user = session?.user;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Banan · Kitchen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user == null
                    ? 'Banan Kitchen'
                    : 'Welcome, ${user.fullName}',
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BananSpacing.sm),
              if (user?.kitchenId != null)
                Text(
                  'Kitchen id: ${user!.kitchenId}',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: BananSpacing.xxl),
              Text(
                'The production kanban board arrives in M6.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
