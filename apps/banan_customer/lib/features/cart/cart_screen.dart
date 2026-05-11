import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'cart_controller.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Subtotal',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          fmt.format(cart.subtotal),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: BananSpacing.md),
                    PrimaryButton(
                      label: 'Checkout',
                      icon: Icons.arrow_forward,
                      expand: true,
                      onPressed: () => context.push('/checkout'),
                    ),
                  ],
                ),
              ),
            ),
      body: cart.isEmpty
          ? const EmptyState(
              title: 'Your cart is empty',
              message: 'Add a cake from the menu to get started.',
              icon: Icons.shopping_bag_outlined,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(BananSpacing.lg),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BananSpacing.md),
              itemBuilder: (context, i) {
                final item = cart.items[i];
                return _Row(
                  item: item,
                  fmt: fmt,
                  onIncrement: () =>
                      controller.setQuantity(item.key, item.quantity + 1),
                  onDecrement: () =>
                      controller.setQuantity(item.key, item.quantity - 1),
                  onRemove: () => controller.remove(item.key),
                );
              },
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.fmt,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final NumberFormat fmt;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BananRadii.rmd,
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.coverImage == null
                  ? Container(
                      color: BananColors.surfaceDim,
                      alignment: Alignment.center,
                      child: const Icon(Icons.cake_outlined),
                    )
                  : Image.network(item.coverImage!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: BananSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName, style: theme.textTheme.titleSmall),
                Text(item.variantLabel, style: theme.textTheme.bodySmall),
                const SizedBox(height: BananSpacing.xs),
                Text(
                  fmt.format(item.lineTotal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove',
                onPressed: onRemove,
              ),
              Row(
                children: [
                  IconButton(
                    iconSize: 20,
                    icon: const Icon(Icons.remove),
                    onPressed: onDecrement,
                  ),
                  Text('${item.quantity}',
                      style: theme.textTheme.titleSmall,),
                  IconButton(
                    iconSize: 20,
                    icon: const Icon(Icons.add),
                    onPressed: onIncrement,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
