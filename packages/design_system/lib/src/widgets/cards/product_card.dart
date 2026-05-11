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
                    if (unavailable)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Center(
                            child: Text(
                              'Unavailable',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                    Text(
                      priceLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
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
          Icons.cake_outlined,
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
          Icons.broken_image_outlined,
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
