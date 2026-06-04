import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MembershipScreen extends ConsumerWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(membershipSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(stringsProvider).membershipTitle)),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(membershipSummaryProvider),
        ),
        data: (summary) => _Body(summary: summary),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.summary});
  final MembershipSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final tierColor = switch (summary.tier) {
      MembershipTier.platinum => BananColors.cocoa,
      MembershipTier.gold => BananColors.gold,
      MembershipTier.silver => BananColors.cocoaSoft,
    };

    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero card with current tier + balance.
                Container(
                  padding: const EdgeInsets.all(BananSpacing.xl),
                  decoration: BoxDecoration(
                    borderRadius: BananRadii.rlg,
                    color: tierColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.tier.name.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      Text(
                        s.michoBalance(summary.balance),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      Text(
                        summary.pointsToNextTier == null
                            ? s.topTier
                            : s.michoUntilNextTier(
                                summary.pointsToNextTier!,),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BananSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  decoration: BoxDecoration(
                    borderRadius: BananRadii.rmd,
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.dividerTheme.color ?? Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.howItWorks, style: theme.textTheme.titleMedium),
                      const SizedBox(height: BananSpacing.sm),
                      Text(
                        s.loyaltyHowText(
                          fmt.format(summary.earnRatePerVnd),
                          fmt.format(summary.redemptionValueVnd),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BananSpacing.xl),
                Text(s.history, style: theme.textTheme.titleLarge),
                const SizedBox(height: BananSpacing.sm),
                if (summary.history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: BananSpacing.lg),
                    child: Text(
                      s.noLoyaltyActivity,
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  for (final event in summary.history)
                    _HistoryRow(event: event),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event});
  final LoyaltyEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = event.delta > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BananSpacing.xs),
      child: Row(
        children: [
          Icon(
            positive ? Icons.add_circle_outline : Icons.remove_circle_outline,
            size: 20,
            color: positive ? BananColors.success : theme.colorScheme.outline,
          ),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.reason ?? event.type.label,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(event.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${event.delta} Micho',
            style: theme.textTheme.titleSmall?.copyWith(
              color: positive ? BananColors.success : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
