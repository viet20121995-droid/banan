import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../cart/cart_controller.dart';

final bundleDetailProvider =
    FutureProvider.autoDispose.family<Bundle, String>((ref, id) async {
  final res = await ref.watch(bundlesApiProvider).detail(id);
  return res.when(
    success: (b) => b,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Detail page for a single bundle — hero image + name + savings pill,
/// constituent items list with thumbnails, "Thêm combo vào giỏ" CTA.
class BundleDetailScreen extends ConsumerWidget {
  const BundleDetailScreen({required this.bundleId, super.key});
  final String bundleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bundleDetailProvider(bundleId));
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Combo')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (bundle) => _BundleBody(bundle: bundle, fmt: fmt),
      ),
    );
  }
}

class _BundleBody extends ConsumerWidget {
  const _BundleBody({required this.bundle, required this.fmt});
  final Bundle bundle;
  final NumberFormat fmt;

  void _addToCart(BuildContext context, WidgetRef ref) {
    // Bundle becomes a single line item — `productId` = bundle.id (so
    // the cart key dedupes correctly) and the variant slot carries a
    // synthetic id so the cart row schema is satisfied.
    final synth = 'bundle:${bundle.id}';
    final itemsSummary = bundle.items
        .map((it) => '${it.quantity}× ${it.product?.name ?? "Sản phẩm"}')
        .join(' + ');
    // A combo's advance-notice requirement is the longest of its parts.
    final bundleLead = bundle.items.fold<int>(
      0,
      (m, it) => (it.product?.leadTimeHours ?? 0) > m
          ? (it.product?.leadTimeHours ?? 0)
          : m,
    );
    // A combo can only be ordered on a day EVERY part is sold (intersection;
    // parts with no day constraint don't narrow it). All-7 collapses to "no
    // constraint" so the picker isn't needlessly restricted.
    final bundleDays = <int>[
      for (var d = 0; d <= 6; d++)
        if (bundle.items.every((it) {
          final days = it.product?.availableDaysOfWeek ?? const <int>[];
          return days.isEmpty || days.contains(d);
        }))
          d,
    ];
    ref.read(cartControllerProvider.notifier).add(
          CartItem(
            productId: bundle.id,
            variantId: synth,
            productName: bundle.name,
            variantLabel: itemsSummary,
            unitPrice: bundle.priceVnd.toDouble(),
            quantity: 1,
            coverImage: bundle.imageUrl,
            leadTimeHours: bundleLead > 0 ? bundleLead : null,
            availableDaysOfWeek: bundleDays.length == 7 ? const [] : bundleDays,
            isBundle: true,
            // Real constituent product ids — so the delivery quote sees what's
            // inside, and checkout sends variantId:null (the synthetic id is
            // for the cart key only; the backend expands the bundle).
            bundleProductIds: [
              for (final it in bundle.items)
                if (it.product != null) it.product!.id,
            ],
          ),
        );
    final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Đã thêm combo "${bundle.name}" vào giỏ.'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Xem giỏ',
          onPressed: () {
            messenger.hideCurrentSnackBar();
            context.push('/checkout');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(BananSpacing.lg),
      children: [
        // Hero image (or icon fallback)
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BananRadii.rlg,
            child: bundle.imageUrl != null && bundle.imageUrl!.isNotEmpty
                ? Image.network(bundle.imageUrl!, fit: BoxFit.cover)
                : Container(
                    color: BananColors.surfaceDim,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_offer_outlined,
                      size: 64,
                      color: BananColors.cocoaSoft,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: BananSpacing.lg),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BananRadii.rPill,
                color: BananColors.accent.withValues(alpha: 0.15),
                border: Border.all(
                  color: BananColors.accent.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'COMBO',
                style: TextStyle(
                  color: BananColors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
            ),
            const Spacer(),
            if (bundle.savedVnd != null && bundle.savedVnd! > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rPill,
                  color: BananColors.success.withValues(alpha: 0.15),
                ),
                child: Text(
                  'Tiết kiệm ${fmt.format(bundle.savedVnd)}',
                  style: const TextStyle(
                    color: BananColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: BananSpacing.sm),
        Text(bundle.name, style: theme.textTheme.displaySmall),
        if (bundle.description != null &&
            bundle.description!.isNotEmpty) ...[
          const SizedBox(height: BananSpacing.xs),
          Text(bundle.description!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: BananSpacing.xl),
        Text('Combo gồm', style: theme.textTheme.titleMedium),
        const SizedBox(height: BananSpacing.sm),
        for (final item in bundle.items)
          _BundleItemRow(item: item, fmt: fmt),
        const SizedBox(height: BananSpacing.xl),
        Text(
          fmt.format(bundle.priceVnd),
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: BananSpacing.md),
        PrimaryButton(
          label: 'Thêm combo vào giỏ',
          icon: Icons.shopping_bag_outlined,
          expand: true,
          onPressed: () => _addToCart(context, ref),
        ),
      ],
    );
  }
}

class _BundleItemRow extends StatelessWidget {
  const _BundleItemRow({required this.item, required this.fmt});
  final BundleItem item;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = item.product;
    final cover = p?.coverImage;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BananRadii.rmd,
            child: SizedBox(
              width: 56,
              height: 56,
              child: cover == null
                  ? Container(
                      color: BananColors.surfaceDim,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.bakery_dining_rounded,
                        color: BananColors.cocoaSoft,
                      ),
                    )
                  : Image.network(cover, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: BananSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p?.name ?? 'Sản phẩm',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  '${item.quantity} cái${item.variant != null
                          ? ' · ${item.variant!.label}'
                          : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
