import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Site footer — links to the trust / legal / help pages, plus any marketing
/// programs the admin has switched on (referral, gift cards, …). Rendered at
/// the bottom of the home menu.
class AppFooter extends ConsumerWidget {
  const AppFooter({super.key});

  static const _baseLinks = <MapEntry<String, String>>[
    MapEntry('Về Banan', '/about'),
    MapEntry('Chi nhánh', '/locations'),
    MapEntry('Câu hỏi thường gặp', '/faq'),
    MapEntry('Liên hệ', '/contact'),
    MapEntry('Chính sách bảo mật', '/privacy'),
    MapEntry('Điều khoản', '/terms'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mkt = ref.watch(marketingConfigProvider).valueOrNull;

    // Marketing links appear only when the admin enabled that program.
    final marketingLinks = <MapEntry<String, String>>[
      if (mkt?.referral.enabled ?? false)
        const MapEntry('Giới thiệu bạn', '/referral'),
      if (mkt?.giftCard.enabled ?? false)
        const MapEntry('Thẻ quà tặng', '/gift-cards'),
      if (mkt?.subscription.enabled ?? false)
        const MapEntry('Gói định kỳ', '/subscription'),
      if (mkt?.catering.enabled ?? false)
        const MapEntry('Đặt tiệc', '/catering'),
      if (mkt?.rewards.enabled ?? false)
        const MapEntry('Đổi điểm', '/rewards'),
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
              for (final link in [..._baseLinks, ...marketingLinks])
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
