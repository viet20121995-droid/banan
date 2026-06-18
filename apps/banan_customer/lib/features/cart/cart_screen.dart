import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../checkout/fulfillment_preference.dart';
import '../checkout/fulfillment_widgets.dart';
import '../checkout/order_draft.dart';
import '../product_detail/cake_wizard.dart';
import '../product_detail/flavor_composer.dart';
import 'cart_controller.dart';

/// Cross-sell recommendations for the cart — keyed on a cart item's product
/// id ("Khách cũng mua" feed). Mirrors the product-detail recommendations
/// provider so the same backend endpoint + card style are reused.
final _cartRecommendationsProvider =
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

/// Toast-style "bag": items + pickup/delivery + schedule + cross-sell all on
/// one scrollable screen. The fulfillment choices are written into the shared
/// [orderDraftProvider] so checkout can pre-fill them. Checkout still owns the
/// payment / coupon / gift / points / VAT + confirm step.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(s.yourCart)),
        body: EmptyState(
          title: s.emptyCartTitle,
          message: s.emptyCartMsg,
          icon: Icons.shopping_bag_outlined,
          action: PrimaryButton(
            label: 'Xem thực đơn',
            icon: Icons.restaurant_menu_outlined,
            onPressed: () => context.go('/'),
          ),
        ),
      );
    }

    final draft = ref.watch(orderDraftProvider);
    final draftCtrl = ref.read(orderDraftProvider.notifier);
    final isGuest = ref.watch(authSessionProvider).valueOrNull == null;
    final isDelivery = draft.fulfillment == FulfillmentType.delivery;

    return Scaffold(
      appBar: AppBar(title: Text(s.yourCart)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '${s.subtotal} · ${cart.itemCount} món',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    fmt.format(cart.subtotal),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: BananSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Phí giao & khuyến mãi tính ở bước thanh toán',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              PrimaryButton(
                label: 'Tiếp tục',
                icon: Icons.arrow_forward,
                expand: true,
                onPressed: () => context.push('/checkout'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Fulfillment toggle ──────────────────────────────────
                  Text(s.fulfillment, style: theme.textTheme.titleLarge),
                  const SizedBox(height: BananSpacing.md),
                  SegmentedButton<FulfillmentType>(
                    segments: [
                      ButtonSegment(
                        value: FulfillmentType.pickup,
                        label: Text(s.pickup),
                        icon: const Icon(Icons.storefront_outlined),
                      ),
                      ButtonSegment(
                        value: FulfillmentType.delivery,
                        label: Text(s.delivery),
                        icon: const Icon(Icons.delivery_dining_outlined),
                      ),
                    ],
                    selected: {draft.fulfillment},
                    onSelectionChanged: (set) {
                      final next = set.first;
                      draftCtrl.setFulfillment(next);
                      // Keep the session-wide preference in sync so the menu
                      // toggle reflects a change made here too.
                      ref
                          .read(fulfillmentPreferenceProvider.notifier)
                          .state = next;
                    },
                  ),

                  // ── Pickup branch / delivery address ────────────────────
                  if (!isDelivery) ...[
                    const SizedBox(height: BananSpacing.xl),
                    Text(s.pickupBranch, style: theme.textTheme.titleLarge),
                    const SizedBox(height: BananSpacing.md),
                    PickupStorePicker(
                      selectedId: draft.pickupStoreId,
                      onSelect: draftCtrl.setPickupStoreId,
                    ),
                  ] else ...[
                    const SizedBox(height: BananSpacing.xl),
                    Text(s.deliveryAddress, style: theme.textTheme.titleLarge),
                    const SizedBox(height: BananSpacing.md),
                    if (!isGuest)
                      SavedAddressPicker(
                        selectedId: draft.deliveryAddressId,
                        onSelect: (a) => draftCtrl.setDeliveryAddressId(a.id),
                      )
                    else
                      const _MutedNote(
                        icon: Icons.info_outline,
                        text: 'Bạn sẽ nhập địa chỉ ở bước thanh toán.',
                      ),
                  ],

                  // ── Schedule ────────────────────────────────────────────
                  const SizedBox(height: BananSpacing.xl),
                  Text(
                    isDelivery ? s.whenDeliver : s.whenReady,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: BananSpacing.md),
                  LeadAwareSchedule(
                    value: draft.scheduledFor,
                    onChanged: draftCtrl.setScheduledFor,
                    leadHours: cart.maxLeadHours,
                    leadNote: prepLeadNote(
                      leadHours: cart.maxLeadHours,
                      names: cart.leadProductNames,
                    ),
                  ),

                  // ── Items ───────────────────────────────────────────────
                  const SizedBox(height: BananSpacing.xl),
                  Text('Món trong giỏ', style: theme.textTheme.titleLarge),
                  const SizedBox(height: BananSpacing.md),
                  for (final item in cart.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: BananSpacing.md),
                      child: _Row(
                        item: item,
                        fmt: fmt,
                        onIncrement: () => controller.setQuantity(
                          item.key,
                          item.quantity + 1,
                        ),
                        onDecrement: () => controller.setQuantity(
                          item.key,
                          item.quantity - 1,
                        ),
                        onRemove: () => controller.remove(item.key),
                      ),
                    ),

                  // ── Cross-sell ──────────────────────────────────────────
                  _CrossSellSection(
                    // Anchor on the last cart item, matching the "things that
                    // go with what you just added" intent.
                    seedProductId: cart.items.last.productId,
                    fmt: fmt,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muted informational note (e.g. the guest delivery-address hint). Styled to
/// recede so it reads as a hint rather than an action.
class _MutedNote extends StatelessWidget {
  const _MutedNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Thêm vào đơn 🧁" cross-sell strip — a horizontal carousel of products the
/// backend recommends for a cart item. Each card one-tap adds the product's
/// cheapest variant (qty 1). Renders nothing while loading, on error, or when
/// the feed is empty so the cart layout stays clean.
class _CrossSellSection extends ConsumerWidget {
  const _CrossSellSection({required this.seedProductId, required this.fmt});
  final String seedProductId;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(_cartRecommendationsProvider(seedProductId));
    // Don't surface the cart's own lines as "suggestions".
    final inCart = ref
        .watch(cartControllerProvider)
        .items
        .map((i) => i.productId)
        .toSet();

    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (items) {
        final suggestions =
            items.where((p) => !inCart.contains(p.id)).toList();
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: BananSpacing.xl),
            Text('Thêm vào đơn 🧁', style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Có thể bạn cũng thích',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: BananSpacing.md),
            SizedBox(
              height: 232,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: BananSpacing.md),
                itemBuilder: (context, i) => _CrossSellCard(
                  product: suggestions[i],
                  fmt: fmt,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CrossSellCard extends ConsumerWidget {
  const _CrossSellCard({required this.product, required this.fmt});
  final Product product;
  final NumberFormat fmt;

  /// Adds the cheapest variant (qty 1) straight to the cart — the prompt's
  /// "default variant" one-tap add. Falls back to nothing if the product has
  /// no variants (defensive; menu products always have at least one).
  void _add(BuildContext context, WidgetRef ref) {
    if (product.variants.isEmpty) return;
    final variant = [...product.variants]
      ..sort((a, b) => a.priceDelta.compareTo(b.priceDelta));
    final cheapest = variant.first;
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
    final s = ref.read(stringsProvider);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.addedToCart(product.name)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 168,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BananRadii.rlg,
          border:
              Border.all(color: theme.dividerTheme.color ?? Colors.black12),
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
                    if ((item.leadTimeHours ?? 0) > 0 ||
                        item.availableDaysOfWeek.isNotEmpty) ...[
                      const SizedBox(height: BananSpacing.xs),
                      Wrap(
                        spacing: BananSpacing.xs,
                        runSpacing: BananSpacing.xs,
                        children: [
                          if ((item.leadTimeHours ?? 0) > 0)
                            _ConstraintChip(
                              icon: Icons.schedule,
                              label: 'Đặt trước ${item.leadTimeHours}h',
                            ),
                          if (item.availableDaysOfWeek.isNotEmpty)
                            _ConstraintChip(
                              icon: Icons.event_outlined,
                              label:
                                  'Chỉ bán ${_cartDaysLabel(item.availableDaysOfWeek)}',
                            ),
                        ],
                      ),
                    ],
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

/// Weekday ints (0=Sun..6=Sat) → short VN labels, sorted, e.g. "T7, CN".
String _cartDaysLabel(List<int> days) {
  const wd = {0: 'CN', 1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7'};
  return (days.toList()..sort()).map((d) => wd[d] ?? '?$d').join(', ');
}

/// Small amber pill on a cart line flagging a per-item timeline constraint
/// (advance notice or sold-only-on-certain-days), so the customer sees the
/// requirement before reaching checkout.
class _ConstraintChip extends StatelessWidget {
  const _ConstraintChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: BananSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: BananColors.gold.withValues(alpha: 0.14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: BananColors.gold),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurface),
          ),
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
