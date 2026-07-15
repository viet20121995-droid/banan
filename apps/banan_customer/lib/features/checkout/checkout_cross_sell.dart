import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../cart/cart_controller.dart';

final _recommendationsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>(
  (ref, productId) async {
    final res = await ref.watch(catalogRepositoryProvider).recommendations(
          productId,
        );
    return res.when(success: (list) => list, failure: (_) => const <Product>[]);
  },
);

/// "Add to your order" strip shown in checkout — horizontal suggestions seeded
/// from a cart item ("khách cũng mua"). Renders nothing while loading, on
/// error, or when every suggestion is already in the cart, so the checkout
/// layout stays clean.
class CheckoutCrossSell extends ConsumerWidget {
  const CheckoutCrossSell({
    required this.seedProductId,
    required this.fmt,
    super.key,
  });

  final String seedProductId;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(_recommendationsProvider(seedProductId));
    final inCart = ref
        .watch(cartControllerProvider)
        .items
        .map((i) => i.productId)
        .toSet();

    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (items) {
        final suggestions =
            items.where((p) => !inCart.contains(p.id)).take(8).toList();
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thêm vào đơn 🧁', style: theme.textTheme.titleMedium),
            const SizedBox(height: BananSpacing.sm),
            SizedBox(
              height: 208,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: BananSpacing.sm),
                itemBuilder: (context, i) =>
                    _Card(product: suggestions[i], fmt: fmt),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.product, required this.fmt});
  final Product product;
  final NumberFormat fmt;

  /// One-tap add of the cheapest variant (qty 1). No-op for a product with no
  /// variants (defensive; menu products always have at least one).
  void _add(BuildContext context, WidgetRef ref) {
    if (product.variants.isEmpty) return;
    final variants = [...product.variants]
      ..sort((a, b) => a.priceDelta.compareTo(b.priceDelta));
    final cheapest = variants.first;
    ref.read(cartControllerProvider.notifier).add(
          CartItem(
            productId: product.id,
            variantId: cheapest.id,
            productName: product.name,
            variantLabel: cheapest.label,
            coverImage: product.coverImage,
            unitPrice: product.priceFor(cheapest),
            quantity: 1,
            isBirthdayCake: product.isBirthdayCake,
            leadTimeHours: product.leadTimeHours,
            availableDaysOfWeek: product.availableDaysOfWeek,
          ),
        );
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${product.name} vào đơn.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BananRadii.rlg,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => context.push('/product/${product.id}'),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: product.coverImage == null
                    ? Container(
                        color: BananColors.surfaceDim,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.cake_outlined,
                          color: BananColors.cocoaSoft,
                        ),
                      )
                    : Image.network(
                        product.coverImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: BananColors.surfaceDim,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BananSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.hasPriceRange
                        ? 'Từ ${fmt.format(product.minPrice)}'
                        : fmt.format(product.minPrice),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: BananSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _add(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Thêm'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: BananSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
