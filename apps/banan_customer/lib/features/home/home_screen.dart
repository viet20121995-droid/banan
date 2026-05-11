import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final theme = Theme.of(context);
    final user = session?.user;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Banan'),
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
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome back, ${user?.fullName ?? 'friend'}',
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BananSpacing.sm),
              if (user != null)
                _MembershipBadge(tier: user.membershipTier, points: user.pointsBalance),
              const SizedBox(height: BananSpacing.xxl),
              Text(
                "The menu is being polished. We'll have today's creations "
                'ready for browsing soon.',
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

class _MembershipBadge extends StatelessWidget {
  const _MembershipBadge({required this.tier, required this.points});
  final MembershipTier tier;
  final int points;

  @override
  Widget build(BuildContext context) {
    final label = tier.name.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.lg,
        vertical: BananSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: BananColors.gold.withValues(alpha: 0.15),
        border: Border.all(color: BananColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label  ·  $points pts',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: BananColors.gold,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
