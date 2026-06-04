import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../product_detail/cake_wizard.dart';
import '../product_detail/flavor_composer.dart';
import 'cart_controller.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final s = ref.watch(stringsProvider);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.yourCart)),
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
                          s.subtotal,
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
                      label: s.checkout,
                      icon: Icons.arrow_forward,
                      expand: true,
                      onPressed: () => context.push('/checkout'),
                    ),
                  ],
                ),
              ),
            ),
      body: cart.isEmpty
          ? EmptyState(
              title: s.emptyCartTitle,
              message: s.emptyCartMsg,
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

class _Row extends ConsumerWidget {
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

  /// Opens the cake wizard pre-filled with the line's current
  /// personalization and writes the edited result back into the cart.
  /// `null` from the wizard means "dismissed" — we leave the line untouched.
  Future<void> _editCake(BuildContext context, WidgetRef ref) async {
    final initial = item.personalization == null
        ? null
        : CakePersonalization.fromMap(item.personalization!);
    final result = await showCakeWizard(
      context,
      productName: item.productName,
      initial: initial,
    );
    if (result == null) return;
    ref.read(cartControllerProvider.notifier).setPersonalization(
          item.key,
          result.isEmpty ? null : result.toMap(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(stringsProvider);
    final summary = _personalizationSummary(item.personalization);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    if (item.variantLabel.isNotEmpty)
                      Text(
                        item.variantLabel,
                        style: theme.textTheme.bodySmall,
                      ),
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
                    tooltip: s.removeItem,
                    onPressed: onRemove,
                  ),
                  Row(
                    children: [
                      IconButton(
                        iconSize: 20,
                        icon: const Icon(Icons.remove),
                        onPressed: onDecrement,
                      ),
                      Text(
                        '${item.quantity}',
                        style: theme.textTheme.titleSmall,
                      ),
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
          // Personalization summary + (for birthday cakes) an edit / add
          // button so the customer can compose or tweak the cake right in
          // the cart without going back to the product page.
          if (summary != null || item.isBirthdayCake) ...[
            const Divider(height: BananSpacing.lg),
            Row(
              children: [
                Icon(
                  Icons.cake_outlined,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    summary ?? 'Chưa cá nhân hoá',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: summary == null
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                      fontStyle:
                          summary == null ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (item.isBirthdayCake)
                  TextButton.icon(
                    onPressed: () => _editCake(context, ref),
                    icon: Icon(
                      summary == null ? Icons.add : Icons.edit_outlined,
                      size: 16,
                    ),
                    label: Text(summary == null ? 'Cá nhân hoá' : 'Sửa'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Builds a one-line human summary of a cart line's personalization, merging
/// the cake-wizard fields (text / candles / note) and any macaron flavour
/// composition. Returns null when there's nothing to show.
String? _personalizationSummary(Map<String, dynamic>? p) {
  if (p == null || p.isEmpty) return null;
  final parts = <String>[];
  final cake = CakePersonalization.fromMap(p).summarize();
  if (cake != null) parts.add(cake);
  final flavors = p['flavors'];
  if (flavors is Map && flavors.isNotEmpty) {
    parts.add(summarizeFlavors(Map<String, dynamic>.from(flavors)));
  }
  return parts.isEmpty ? null : parts.join(' · ');
}
