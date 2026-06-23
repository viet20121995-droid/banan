import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../cart/cart_controller.dart';
import '../wishlist/wishlist_controller.dart';
import 'cake_wizard.dart';
import 'flavor_composer.dart';

final productProvider =
    FutureProvider.autoDispose.family<Product, String>((ref, id) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final result = await repo.product(id);
  return result.when(
    success: (p) => p,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductVariant? _selected;

  /// Latest cake-wizard output for this screen instance. Stays null
  /// until the customer opens the wizard. Persists in screen state so
  /// they can re-open + tweak before adding to cart.
  CakePersonalization? _personalization;

  /// Macaron-set flavour composition (flavour → count). Only used for
  /// products with `hasFlavorComposer`. Must sum to `flavorPickCount`
  /// before the add-to-cart button enables.
  final Map<String, int> _flavorPicks = {};

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productProvider(widget.productId));
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(productProvider(widget.productId)),
        ),
        data: (product) {
          final selected = _selected ??
              (product.variants.isNotEmpty ? product.variants.first : null);
          final price = selected == null
              ? product.basePrice
              : product.priceFor(selected);

          return BreakpointBuilder(
            builder: (context, bp) {
              final twoCol = bp.isAtLeastMd;
              final image = AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BananRadii.rlg,
                  child: product.coverImage == null
                      ? Container(
                          color: BananColors.surfaceDim,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.cake_outlined,
                            size: 80,
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
              );
              final showStock = ref
                      .watch(displayConfigProvider)
                      .valueOrNull
                      ?.showStockToCustomers ??
                  false;
              // Macaron-set composer gating: when the product needs a
              // flavour composition, the add-to-cart button stays
              // disabled until the picks sum to flavorPickCount.
              final composerComplete = !product.hasFlavorComposer ||
                  _flavorPicks.values.fold(0, (s, n) => s + n) ==
                      product.flavorPickCount;

              final details = _Details(
                product: product,
                selected: selected,
                onSelect: (v) => setState(() => _selected = v),
                priceLabel: fmt.format(price),
                theme: theme,
                s: s,
                showStock: showStock,
                personalization: _personalization,
                flavorPicks: _flavorPicks,
                onFlavorsChanged: (next) => setState(() {
                  _flavorPicks
                    ..clear()
                    ..addAll(next);
                }),
                composerComplete: composerComplete,
                onOpenWizard: !product.isBirthdayCake
                    ? null
                    : () async {
                        final result = await showCakeWizard(
                          context,
                          productName: product.name,
                          initial: _personalization,
                        );
                        if (result != null) {
                          setState(() {
                            _personalization = result.isEmpty ? null : result;
                          });
                        }
                      },
                onAdd: (selected == null || !composerComplete)
                    ? null
                    : () {
                        // Merge cake-wizard + flavour-composition into one
                        // personalization payload for the cart line.
                        final pers = <String, dynamic>{
                          ...?_personalization?.toMap(),
                          if (product.hasFlavorComposer)
                            'flavors': Map<String, int>.from(_flavorPicks),
                        };
                        ref.read(cartControllerProvider.notifier).add(
                              CartItem(
                                productId: product.id,
                                variantId: selected.id,
                                productName: product.name,
                                variantLabel: selected.label,
                                coverImage: product.coverImage,
                                unitPrice: product.priceFor(selected),
                                quantity: 1,
                                personalization:
                                    pers.isEmpty ? null : pers,
                                isBirthdayCake: product.isBirthdayCake,
                                leadTimeHours: product.leadTimeHours,
                                availableDaysOfWeek: product.availableDaysOfWeek,
                              ),
                            );
                        // Surface a "View cart" shortcut directly in the
                        // confirmation so the customer never has to back out
                        // and hunt for the cart icon.
                        final messenger = ScaffoldMessenger.of(context)
                          ..removeCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(s.addedToCart(product.name)),
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: s.cart,
                              onPressed: () {
                                // Hide before nav so the snackbar doesn't
                                // tail into the cart screen.
                                messenger.hideCurrentSnackBar();
                                context.push('/cart');
                              },
                            ),
                          ),
                        );
                      },
              );

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: bp.isMobile ? 16 : 24,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        twoCol
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: image),
                                  const SizedBox(width: BananSpacing.xxl),
                                  Expanded(child: details),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  image,
                                  const SizedBox(height: BananSpacing.xl),
                                  details,
                                ],
                              ),
                        const SizedBox(height: BananSpacing.xxxl),
                        _RecommendationsSection(productId: product.id),
                        const SizedBox(height: BananSpacing.xxl),
                        _ReviewsSection(productId: product.id),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.product,
    required this.selected,
    required this.onSelect,
    required this.priceLabel,
    required this.theme,
    required this.onAdd,
    required this.s,
    required this.showStock,
    required this.personalization,
    required this.onOpenWizard,
    required this.flavorPicks,
    required this.onFlavorsChanged,
    required this.composerComplete,
  });

  final Product product;
  final ProductVariant? selected;
  final ValueChanged<ProductVariant> onSelect;
  final String priceLabel;
  final ThemeData theme;
  final VoidCallback? onAdd;
  final AppStrings s;

  /// Chain-wide toggle from `DisplayConfig`. When false, every stock-related
  /// surface on this screen renders as if all variants were UNLIMITED:
  /// no per-variant "còn N" suffix, no low-stock banner, no sold-out lock.
  final bool showStock;

  /// Current wizard output (or null if the customer hasn't opened the
  /// wizard yet). Drives the "Cá nhân hoá bánh ✓" pill summary on the
  /// detail panel. Only meaningful for birthday-cake products.
  final CakePersonalization? personalization;

  /// Tap handler for the wizard CTA. Null when the product isn't a
  /// birthday cake — the button is hidden in that case.
  final VoidCallback? onOpenWizard;

  /// Macaron-set flavour composer state. Only rendered when the product
  /// has a composer; [composerComplete] gates the add-to-cart button.
  final Map<String, int> flavorPicks;
  final ValueChanged<Map<String, int>> onFlavorsChanged;
  final bool composerComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(product.name, style: theme.textTheme.displaySmall),
        if (product.category != null) ...[
          const SizedBox(height: BananSpacing.sm),
          Text(
            product.category!.name.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4,
              color: theme.colorScheme.outline,
            ),
          ),
        ],
        const SizedBox(height: BananSpacing.lg),
        Text(product.description, style: theme.textTheme.bodyLarge),
        const SizedBox(height: BananSpacing.xl),
        if (product.variants.isNotEmpty) ...[
          Text(s.chooseSizeFlavor, style: theme.textTheme.titleSmall),
          const SizedBox(height: BananSpacing.sm),
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: product.variants.map((v) {
              // Sold-out LIMITED variant → disabled chip with "Hết hàng"
              // suffix so the customer knows the option isn't available
              // without trying to add it to cart first. Gated on
              // [showStock] — when the chain has the toggle off, the
              // chip is just the variant label.
              final isLimitedOut = showStock &&
                  v.stockMode == StockMode.limited &&
                  (v.stockQty ?? 0) <= 0;
              final disabled = !v.isAvailable || isLimitedOut;
              final label = showStock &&
                      v.stockMode == StockMode.limited &&
                      (v.stockQty ?? 0) > 0 &&
                      (v.stockQty ?? 0) <= 5
                  ? '${v.label} · còn ${v.stockQty}'
                  : isLimitedOut
                      ? '${v.label} · hết hàng'
                      : v.label;
              return ChoiceChip(
                label: Text(label),
                selected: selected?.id == v.id,
                onSelected: disabled ? null : (_) => onSelect(v),
              );
            }).toList(),
          ),
          const SizedBox(height: BananSpacing.xl),
        ],
        if (product.hasFlavorComposer) ...[
          FlavorComposer(
            options: product.flavorOptions,
            pickCount: product.flavorPickCount!,
            selection: flavorPicks,
            onChanged: onFlavorsChanged,
          ),
          const SizedBox(height: BananSpacing.xl),
        ],
        if (showStock && product.isLowStock) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BananSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: BananColors.accent.withValues(alpha: 0.12),
              borderRadius: BananRadii.rPill,
              border: Border.all(
                color: BananColors.accent.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_outlined,
                  size: 16,
                  color: BananColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Sắp hết — còn ${product.totalLimitedStock} cái',
                  style: const TextStyle(
                    color: BananColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BananSpacing.md),
        ],
        Row(
          children: [
            Text(
              priceLabel,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            Text(
              s.readyInMin(product.preparationMinutes),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        if (onOpenWizard != null) ...[
          const SizedBox(height: BananSpacing.md),
          _PersonalizationPanel(
            personalization: personalization,
            onOpen: onOpenWizard!,
          ),
        ],
        const SizedBox(height: BananSpacing.xl),
        PrimaryButton(
          label: (showStock && product.isSoldOut)
              ? 'Hết hàng'
              : (!composerComplete
                  ? 'Chọn đủ ${product.flavorPickCount} vị'
                  : s.addToCart),
          icon: (showStock && product.isSoldOut)
              ? Icons.do_not_disturb_alt
              : Icons.shopping_bag_outlined,
          expand: true,
          onPressed:
              (showStock && product.isSoldOut) ? null : onAdd,
        ),
      ],
    );
  }
}

final _productReviewsProvider =
    FutureProvider.autoDispose.family<ReviewPage, String>(
  (ref, productId) async {
    final api = ref.watch(reviewsApiProvider);
    final res = await api.forProduct(productId);
    return res.when(
      success: (page) => page,
      failure: (f) => throw Exception(f.message ?? f.code),
    );
  },
);

/// Public review list shown at the bottom of every product detail.
///   - Summary header: "4.6 ★ · 128 đánh giá"
///   - Each review: stars + author + body + (optional images grid)
class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(_productReviewsProvider(productId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Đánh giá', style: theme.textTheme.titleLarge),
        const SizedBox(height: BananSpacing.md),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: BananSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: BananSpacing.lg),
            child: Text('Không tải được đánh giá: $e'),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: BananSpacing.lg,
                ),
                child: Text(
                  'Chưa có đánh giá nào. Hãy là người đầu tiên đánh giá '
                  'sản phẩm sau khi nhận hàng nhé.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (page.summary != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: BananColors.gold,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        page.summary!.averageRating.toStringAsFixed(1),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${page.summary!.totalReviews} đánh giá',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: BananSpacing.md),
                for (final r in page.items) _ReviewTile(review: r),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.md),
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: review.userAvatarUrl != null
                    ? NetworkImage(review.userAvatarUrl!)
                    : null,
                child: review.userAvatarUrl == null
                    ? Text(
                        (review.userFullName?.isNotEmpty ?? false)
                            ? review.userFullName![0].toUpperCase()
                            : '?',
                        style: theme.textTheme.labelSmall,
                      )
                    : null,
              ),
              const SizedBox(width: BananSpacing.sm),
              Expanded(
                child: Text(
                  review.userFullName ?? 'Khách hàng',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              for (var i = 0; i < 5; i++)
                Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  size: 14,
                  color: BananColors.gold,
                ),
            ],
          ),
          if ((review.body ?? '').isNotEmpty) ...[
            const SizedBox(height: BananSpacing.xs),
            Text(review.body!, style: theme.textTheme.bodyMedium),
          ],
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    review.images[i],
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final _recommendationsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>(
  (ref, productId) async {
    final repo = ref.watch(catalogRepositoryProvider);
    final res = await repo.recommendations(productId);
    return res.when(
      success: (list) => list,
      failure: (f) => throw Exception(f.message ?? f.code),
    );
  },
);

/// "Khách cũng mua" horizontal carousel — shown between the buy panel
/// and the reviews on every product detail. Silently hides when there
/// are no recommendations (cold-start / brand-new product).
class _RecommendationsSection extends ConsumerStatefulWidget {
  const _RecommendationsSection({required this.productId});
  final String productId;

  @override
  ConsumerState<_RecommendationsSection> createState() =>
      _RecommendationsSectionState();
}

class _RecommendationsSectionState
    extends ConsumerState<_RecommendationsSection> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll by [delta] px (≈ 2 cards), clamped to the scroll extent.
  void _nudge(double delta) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(_recommendationsProvider(widget.productId));
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        // Warm the cover-image cache for EVERY recommendation up-front. Without
        // this, cards peeking at the right edge render as empty cream frames
        // until their image lazily loads — which looks broken. Cheap + idempotent
        // (precacheImage dedupes against the image cache).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (final p in items) {
            final url = p.coverImage;
            if (url != null && url.isNotEmpty) {
              precacheImage(NetworkImage(url), context);
            }
          }
        });
        final session = ref.watch(authSessionProvider).valueOrNull;
        final wishlistAsync = ref.watch(wishlistIdsProvider);
        final showStock = ref
                .watch(displayConfigProvider)
                .valueOrNull
                ?.showStockToCustomers ??
            false;
        // Desktop/web has no swipe gesture, so overlay prev/next arrows.
        // Mobile keeps touch-swipe (arrows hidden on narrow viewports). Each
        // tap advances ≈ 2 cards.
        const step = (180 + BananSpacing.md) * 2;
        final showArrows = MediaQuery.sizeOf(context).width >= 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khách cũng mua', style: theme.textTheme.titleLarge),
            const SizedBox(height: BananSpacing.md),
            SizedBox(
              // Match the home category strips (180×230, no tagline). The card's
              // natural height (4:3 image + name + 2-line tagline + tags + price)
              // overflowed the old 280 box at width 200, clipping the price row.
              height: 230,
              child: Stack(
                children: [
                  ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: BananSpacing.md),
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return SizedBox(
                        width: 180,
                        child: ProductCard(
                          name: p.name,
                          imageUrl: p.coverImage,
                          tags: p.tags,
                          minPrice: p.minPrice,
                          hasPriceRange: p.hasPriceRange,
                          seasonal: p.isSeasonal,
                          averageRating: p.averageRating,
                          reviewCount: p.reviewCount,
                          stockRemaining:
                              showStock ? p.totalLimitedStock : null,
                          soldOut: showStock && p.isSoldOut,
                          isWishlisted: isWishlisted(wishlistAsync, p.id),
                          onToggleWishlist: session == null
                              ? null
                              : () => ref
                                  .read(wishlistIdsProvider.notifier)
                                  .toggle(p.id),
                          onTap: () => context.push('/product/${p.id}'),
                        ),
                      );
                    },
                  ),
                  if (showArrows)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _scroll,
                        builder: (context, _) {
                          final hasClients = _scroll.hasClients;
                          final maxExtent = hasClients
                              ? _scroll.position.maxScrollExtent
                              : 0.0;
                          // Nothing to scroll → no arrows.
                          if (hasClients && maxExtent <= 0) {
                            return const SizedBox.shrink();
                          }
                          final offset = hasClients ? _scroll.offset : 0.0;
                          final atStart = offset <= 1;
                          final atEnd = hasClients && offset >= maxExtent - 1;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _CarouselArrow(
                                icon: Icons.chevron_left_rounded,
                                hidden: atStart,
                                onTap: () => _nudge(-step),
                              ),
                              _CarouselArrow(
                                icon: Icons.chevron_right_rounded,
                                hidden: atEnd,
                                onTap: () => _nudge(step),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Circular prev/next control overlaid on a horizontal carousel. [hidden]
/// fades it out + disables taps at the start/end of the scroll range.
class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.onTap,
    this.hidden = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: hidden ? 0 : 1,
      duration: const Duration(milliseconds: 150),
      child: IgnorePointer(
        ignoring: hidden,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BananSpacing.xs),
            child: Material(
              color: theme.colorScheme.surface,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, size: 26, color: theme.colorScheme.primary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable pill that opens the cake wizard. Shows "Cá nhân hoá bánh"
/// in idle state, switches to a green-tick chip with the wizard summary
/// once the customer has filled it in.
class _PersonalizationPanel extends StatelessWidget {
  const _PersonalizationPanel({
    required this.personalization,
    required this.onOpen,
  });
  final CakePersonalization? personalization;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue =
        personalization != null && !personalization!.isEmpty;
    return InkWell(
      borderRadius: BananRadii.rmd,
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.md,
          vertical: BananSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rmd,
          color: hasValue
              ? BananColors.success.withValues(alpha: 0.10)
              : BananColors.primary.withValues(alpha: 0.06),
          border: Border.all(
            color: hasValue
                ? BananColors.success.withValues(alpha: 0.5)
                : BananColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasValue ? Icons.check_circle_outline : Icons.cake_outlined,
              color: hasValue ? BananColors.success : BananColors.primary,
              size: 20,
            ),
            const SizedBox(width: BananSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasValue
                        ? 'Đã cá nhân hoá bánh'
                        : 'Cá nhân hoá bánh',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: hasValue
                          ? BananColors.success
                          : BananColors.primary,
                    ),
                  ),
                  Text(
                    hasValue
                        ? personalization!.summarize() ?? ''
                        : 'Chữ trên bánh, số nến, ảnh tham khảo, ghi chú …',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              hasValue ? Icons.edit_outlined : Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
