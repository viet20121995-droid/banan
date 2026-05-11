import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../cart/cart_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productProvider(widget.productId));
    final theme = Theme.of(context);
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
              final details = _Details(
                product: product,
                selected: selected,
                onSelect: (v) => setState(() => _selected = v),
                priceLabel: fmt.format(price),
                theme: theme,
                onAdd: selected == null
                    ? null
                    : () {
                        ref.read(cartControllerProvider.notifier).add(
                              CartItem(
                                productId: product.id,
                                variantId: selected.id,
                                productName: product.name,
                                variantLabel: selected.label,
                                coverImage: product.coverImage,
                                unitPrice: product.priceFor(selected),
                                quantity: 1,
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart'),
                            duration: const Duration(seconds: 2),
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
                    child: twoCol
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
  });

  final Product product;
  final ProductVariant? selected;
  final ValueChanged<ProductVariant> onSelect;
  final String priceLabel;
  final ThemeData theme;
  final VoidCallback? onAdd;

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
          Text('Choose a size & flavor', style: theme.textTheme.titleSmall),
          const SizedBox(height: BananSpacing.sm),
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: product.variants.map((v) {
              return ChoiceChip(
                label: Text(v.label),
                selected: selected?.id == v.id,
                onSelected: v.isAvailable ? (_) => onSelect(v) : null,
              );
            }).toList(),
          ),
          const SizedBox(height: BananSpacing.xl),
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
              'Ready in ~${product.preparationMinutes} min',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: BananSpacing.xl),
        PrimaryButton(
          label: 'Add to cart',
          icon: Icons.shopping_bag_outlined,
          expand: true,
          onPressed: onAdd,
        ),
      ],
    );
  }
}
