import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Brand colour for each membership tier. Bronze is a warm copper tone;
/// the rest reuse the existing palette.
const _bronzeColor = Color(0xFFA9743B);

Color _tierColor(MembershipTier tier) {
  switch (tier) {
    case MembershipTier.bronze:
      return _bronzeColor;
    case MembershipTier.silver:
      return BananColors.cocoaSoft;
    case MembershipTier.gold:
      return BananColors.gold;
    case MembershipTier.platinum:
      return BananColors.cocoa;
  }
}

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
    final tierColor = _tierColor(summary.tier);

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
                        'Hạng ${summary.tier.label}'.toUpperCase(),
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
                // All four tiers — current one highlighted, with progress to
                // the next tier derived from /me/loyalty thresholds.
                _TierLadder(summary: summary),
                const SizedBox(height: BananSpacing.xl),
                // Quick link into the voucher wallet.
                _NavTile(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Ví voucher',
                  subtitle: 'Mã giảm giá khả dụng, đã dùng và hết hạn.',
                  onTap: () => context.push('/vouchers'),
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

/// Shows all four tiers (Đồng → Bạch kim) as a vertical ladder. The
/// customer's current tier is highlighted; a progress bar under the active
/// row tracks points toward the next tier using the loyalty thresholds.
class _TierLadder extends StatelessWidget {
  const _TierLadder({required this.summary});
  final MembershipSummary summary;

  static const _tiers = [
    MembershipTier.bronze,
    MembershipTier.silver,
    MembershipTier.gold,
    MembershipTier.platinum,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.decimalPattern('vi_VN');
    final next = summary.nextTier;
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Các hạng thành viên', style: theme.textTheme.titleMedium),
          const SizedBox(height: BananSpacing.sm),
          for (final tier in _tiers) ...[
            _TierRow(
              tier: tier,
              threshold: summary.tierThresholds[tier] ?? 0,
              isCurrent: tier == summary.tier,
              isNext: tier == next,
              balance: summary.balance,
              fmt: fmt,
            ),
            if (tier != _tiers.last) const SizedBox(height: BananSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.threshold,
    required this.isCurrent,
    required this.isNext,
    required this.balance,
    required this.fmt,
  });

  final MembershipTier tier;
  final int threshold;
  final bool isCurrent;
  final bool isNext;
  final int balance;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rsm,
        color: isCurrent ? color.withValues(alpha: 0.12) : null,
        border: isCurrent ? Border.all(color: color) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: color, size: 22),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Text(
                  tier.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BananSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BananRadii.rsm,
                    color: color,
                  ),
                  child: Text(
                    'Hiện tại',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Text(
                  'Từ ${fmt.format(threshold)} điểm',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          // Progress bar toward the next tier — drawn under the current row.
          if (isCurrent && threshold >= 0) ...[
            const SizedBox(height: BananSpacing.sm),
            _NextTierProgress(balance: balance, color: color),
          ],
        ],
      ),
    );
  }
}

/// A thin progress bar + caption showing how close the balance is to the
/// next tier threshold. Rendered inside the active tier row.
class _NextTierProgress extends ConsumerWidget {
  const _NextTierProgress({required this.balance, required this.color});
  final int balance;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(membershipSummaryProvider).valueOrNull;
    if (summary == null) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final next = summary.nextTier;
    if (next == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          s.topTier,
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    final nextThreshold = summary.tierThresholds[next] ?? 0;
    final currentThreshold = summary.tierThresholds[summary.tier] ?? 0;
    final span = (nextThreshold - currentThreshold).clamp(1, 1 << 31);
    final progressed = (balance - currentThreshold).clamp(0, span);
    final ratio = progressed / span;
    final remaining = summary.pointsToNextTier ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Còn $remaining điểm để lên hạng ${next.label}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

/// A tappable card-style row used for in-screen navigation (e.g. to the
/// voucher wallet).
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BananRadii.rmd,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon, color: BananColors.gold),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
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
