import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MerchantHomeScreen extends ConsumerWidget {
  const MerchantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final theme = Theme.of(context);
    final user = session?.user;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Banan · Merchant'),
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
                    ? 'Banan Merchant'
                    : 'Welcome, ${user.fullName}',
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BananSpacing.sm),
              if (user?.storeId != null)
                Text(
                  'Store id: ${user!.storeId}',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: BananSpacing.xxl),
              Text(
                'Orders queue, menu management, and analytics arrive in M2.',
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
