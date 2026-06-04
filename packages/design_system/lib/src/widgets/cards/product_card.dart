import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../tokens/colors.dart';
import '../../tokens/radii.dart';
import '../../tokens/spacing.dart';

/// Product card used on the menu grid. Renders cover image (or placeholder),
/// name in display serif, and either a single price or "From X" range.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.name,
    required this.minPrice,
    required this.hasPriceRange,
    this.imageUrl,
    this.tagline,
    this.tags = const [],
    this.seasonal = false,
    this.unavailable = false,
    this.onTap,
    this.onQuickAdd,
    this.onToggleWishlist,
    this.isWishlisted = false,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.stockRemaining,
    this.soldOut = false,
    super.key,
  });

  final String name;
  final double minPrice;
  final bool hasPriceRange;
  final String? imageUrl;
  final String? tagline;
  final List<String> tags;
  final bool seasonal;
  final bool unavailable;
  final VoidCallback? onTap;

  /// Optional quick-add callback. When non-null, a small "+" floating
  /// button appears at the bottom-right of the cover image — single tap
  /// adds to cart without leaving the menu. Tap card body still opens
  /// the product detail screen as before.
  final VoidCallback? onQuickAdd;

  /// Optional wishlist toggle. When non-null, a heart button appears at
  /// the top-right of the cover. [isWishlisted] paints it filled.
  final VoidCallback? onToggleWishlist;
  final bool isWishlisted;

  /// Star summary shown under the price. 0 / 0 hides the row entirely.
  final double averageRating;
  final int reviewCount;

  /// When non-null AND ≤ 5, a "Còn N cái" badge is overlaid on the cover.
  /// Higher counts are hidden — the urgency cue only fires near sell-out.
  /// Pass null for UNLIMITED-only products to skip the indicator entirely.
  final int? stockRemaining;

  /// When true, a "Hết hàng" overlay covers the cover and the card looks
  /// disabled — prevents accidental quick-adds.
  final bool soldOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final priceLabel = hasPriceRange
        ? 'From ${fmt.format(minPrice)}'
        : fmt.format(minPrice);

    return InkWell(
      onTap: onTap,
      borderRadius: BananRadii.rlg,
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BananRadii.rlg,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
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
                    _Cover(imageUrl: imageUrl),
                    if (seasonal)
                      const Positioned(
                        top: BananSpacing.sm,
                        left: BananSpacing.sm,
                        child: _Tag(
                          label: 'Seasonal',
                          color: BananColors.gold,
                        ),
                      ),
                    if (unavailable || soldOut)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: Center(
                            child: Text(
                              soldOut ? 'Hết hàng' : 'Tạm ngưng',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (stockRemaining != null &&
                        stockRemaining! > 0 &&
                        stockRemaining! <= 5 &&
                        !soldOut)
                      Positioned(
                        bottom: BananSpacing.sm,
                        left: BananSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: BananColors.accent.withValues(alpha: 0.95),
                            borderRadius: BananRadii.rPill,
                          ),
                          child: Text(
                            'Còn $stockRemaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    if (onQuickAdd != null && !unavailable)
                      Positioned(
                        bottom: BananSpacing.sm,
                        right: BananSpacing.sm,
                        child: _QuickAddButton(onTap: onQuickAdd!),
                      ),
                    if (onToggleWishlist != null)
                      Positioned(
                        top: BananSpacing.sm,
                        right: BananSpacing.sm,
                        child: _WishlistHeart(
                          active: isWishlisted,
                          onTap: onToggleWishlist!,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BananSpacing.md,
                  BananSpacing.md,
                  BananSpacing.md,
                  BananSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tagline != null) ...[
                      const SizedBox(height: BananSpacing.xs),
                      Text(
                        tagline!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: BananSpacing.xs),
                      Wrap(
                        spacing: BananSpacing.xs,
                        runSpacing: BananSpacing.xs,
                        children: [
                          for (final t in tags.take(3)) _MiniTag(label: t),
                        ],
                      ),
                    ],
                    const SizedBox(height: BananSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            priceLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        if (reviewCount > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: BananColors.gold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($reviewCount)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        color: BananColors.surfaceDim,
        alignment: Alignment.center,
        child: const Icon(
          Icons.bakery_dining_rounded,
          size: 48,
          color: BananColors.cocoaSoft,
        ),
      );
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: BananColors.surfaceDim,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_rounded,
          size: 32,
          color: BananColors.cocoaSoft,
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: BananColors.surfaceDim,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: BananColors.gold.withValues(alpha: 0.14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BananColors.cocoa,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Compact circular "+" overlay shown on the product cover. Tap adds the
/// product to the cart without navigating away — the parent decides
/// whether that opens a variant sheet first or skips straight to add.
class _QuickAddButton extends StatelessWidget {
  const _QuickAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.add,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Heart toggle painted in the top-right of the cover.
///   - active=false → outlined heart on a translucent white pill
///   - active=true  → filled red heart on the same pill
class _WishlistHeart extends StatelessWidget {
  const _WishlistHeart({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 18,
            color: active ? Colors.redAccent : BananColors.cocoaSoft,
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rPill,
        color: color.withValues(alpha: 0.92),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
