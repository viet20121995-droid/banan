import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../menu/section_header.dart';

final homeBundlesProvider =
    FutureProvider.autoDispose<List<Bundle>>((ref) async {
  final res = await ref.watch(bundlesApiProvider).home();
  return res.when(
    success: (l) => l,
    failure: (_) => const [],
  );
});

/// Horizontal carousel of pinned-to-home bundles. Auto-hides when
/// there are no active bundles flagged for home — never renders an
/// empty section.
class BundleStrip extends ConsumerWidget {
  const BundleStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeBundlesProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (bundles) {
        if (bundles.isEmpty) return const SizedBox.shrink();
        return _BundlesCarousel(
          overline: 'Tiết kiệm hơn',
          title: 'Combo nổi bật',
          subtitle: 'Đặt set có sẵn — rẻ hơn 10-20% so với mua lẻ.',
          bundles: bundles,
        );
      },
    );
  }
}

/// Horizontal carousel of every ACTIVE combo (pinned + unpinned), so active
/// combos that aren't featured on home are still browsable. Auto-hides when
/// there are no active combos. Reuses the same card as [BundleStrip].
class AllBundlesStrip extends ConsumerWidget {
  const AllBundlesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(homeBundlesProvider).valueOrNull ?? const [];
    final async = ref.watch(allBundlesProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (all) {
        if (all.isEmpty) return const SizedBox.shrink();
        // Drop the ones already shown in "Combo nổi bật" so the two strips
        // don't repeat the same cards. Hide the section if nothing's left.
        final pinnedIds = pinned.map((b) => b.id).toSet();
        final rest = all.where((b) => !pinnedIds.contains(b.id)).toList();
        if (rest.isEmpty) return const SizedBox.shrink();
        return _BundlesCarousel(
          overline: 'Combo',
          title: 'Tất cả combo',
          subtitle: 'Mọi set đang bán — chọn combo bạn thích.',
          bundles: rest,
        );
      },
    );
  }
}

/// Shared layout for a labelled horizontal combo carousel.
class _BundlesCarousel extends StatelessWidget {
  const _BundlesCarousel({
    required this.overline,
    required this.title,
    required this.subtitle,
    required this.bundles,
  });

  final String overline;
  final String title;
  final String subtitle;
  final List<Bundle> bundles;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            overline: overline,
            title: title,
            subtitle: subtitle,
          ),
          SizedBox(
            height: 270,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: BananSpacing.lg,
              ),
              itemCount: bundles.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: BananSpacing.md),
              itemBuilder: (context, i) =>
                  _BundleCard(bundle: bundles[i], fmt: fmt),
            ),
          ),
        ],
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle, required this.fmt});
  final Bundle bundle;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: InkWell(
        borderRadius: BananRadii.rlg,
        onTap: () => context.push('/bundles/${bundle.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BananRadii.rlg,
            border: Border.all(
              color: theme.dividerTheme.color ?? Colors.black12,
            ),
          ),
          child: ClipRRect(
            borderRadius: BananRadii.rlg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (bundle.imageUrl != null &&
                          bundle.imageUrl!.isNotEmpty)
                        Image.network(bundle.imageUrl!, fit: BoxFit.cover)
                      else
                        Container(
                          color: BananColors.surfaceDim,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.local_offer_outlined,
                            size: 40,
                            color: BananColors.cocoaSoft,
                          ),
                        ),
                      Positioned(
                        top: BananSpacing.sm,
                        left: BananSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BananRadii.rPill,
                            color: BananColors.accent.withValues(alpha: 0.92),
                          ),
                          child: const Text(
                            'COMBO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(BananSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bundle.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bundle.items
                            .map((it) =>
                                '${it.quantity}× ${it.product?.name ?? "?"}')
                            .join(' + '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: BananSpacing.sm),
                      Text(
                        fmt.format(bundle.priceVnd),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
