import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/legal_info.dart';

/// Site footer — links to the trust / legal / help pages, plus any marketing
/// programs the admin has switched on (referral, gift cards, …). Rendered at
/// the bottom of the home menu.
class AppFooter extends ConsumerWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mkt = ref.watch(marketingConfigProvider).valueOrNull;
    final s = ref.watch(stringsProvider);

    final baseLinks = <MapEntry<String, String>>[
      MapEntry(s.footAbout, '/about'),
      MapEntry(s.footLocations, '/locations'),
      MapEntry(s.footFaq, '/faq'),
      MapEntry(s.footContact, '/contact'),
      MapEntry(s.footPrivacy, '/privacy'),
      MapEntry(s.footTerms, '/terms'),
      MapEntry(s.footShipping, '/shipping'),
      MapEntry(s.footPayment, '/payment-policy'),
      MapEntry(s.footRefund, '/refund-policy'),
    ];

    // Marketing links appear only when the admin enabled that program.
    final marketingLinks = <MapEntry<String, String>>[
      if (mkt?.referral.enabled ?? false)
        MapEntry(s.footReferral, '/referral'),
      if (mkt?.giftCard.enabled ?? false)
        MapEntry(s.footGiftCards, '/gift-cards'),
      if (mkt?.subscription.enabled ?? false)
        MapEntry(s.footSubscription, '/subscription'),
      if (mkt?.catering.enabled ?? false)
        MapEntry(s.footCatering, '/catering'),
      if (mkt?.rewards.enabled ?? false)
        MapEntry(s.footRewards, '/rewards'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: BananSpacing.xl,
        horizontal: BananSpacing.lg,
      ),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: BananSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: BananSpacing.lg,
            runSpacing: BananSpacing.sm,
            children: [
              for (final link in [...baseLinks, ...marketingLinks])
                InkWell(
                  onTap: () => context.push(link.value),
                  child: Text(
                    link.key,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          // Thông tin chủ sở hữu website — yêu cầu của Bộ Công Thương
          // (online.gov.vn). Lấy từ LegalInfo (placeholder, chủ shop điền).
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ) ??
                const TextStyle(),
            child: Column(
              children: [
                const Text(LegalInfo.businessName),
                const Text('MST: ${LegalInfo.taxCode}'),
                Text(s.bizReg(LegalInfo.bizRegNo)),
                Text(s.bizAddress(LegalInfo.address)),
                const Text(
                  'Hotline: ${LegalInfo.hotline} · Email: ${LegalInfo.email}',
                ),
              ],
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
          Text(
            '© 2026 Banan Fukuoka Saigon',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
