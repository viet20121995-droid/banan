import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'wishlist_controller.dart';

/// "Yêu thích" tab — lists every product the customer has hearted.
/// Reachable from the profile screen and `/wishlist`.
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yêu thích')),
        body: EmptyState(
          title: 'Đăng nhập để lưu yêu thích',
          message:
              'Đăng nhập để giữ danh sách bánh yêu thích đồng bộ giữa các thiết bị.',
          icon: Icons.favorite_border_rounded,
          action: FilledButton(
            onPressed: () => context.push('/auth/login'),
            child: const Text('Đăng nhập'),
          ),
        ),
      );
    }

    final async = ref.watch(wishlistProvider);
    final wishlistIds = ref.watch(wishlistIdsProvider);
    final showStock = ref
            .watch(displayConfigProvider)
            .valueOrNull
            ?.showStockToCustomers ??
        false;

    return Scaffold(
      appBar: AppBar(title: const Text('Yêu thích')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(wishlistProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              title: 'Chưa có sản phẩm yêu thích',
              message: 'Bấm trái tim trên bánh bạn thích để lưu lại.',
              icon: Icons.favorite_border_rounded,
              action: FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Xem thực đơn'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(wishlistProvider),
            child: LayoutBuilder(
              builder: (context, c) {
                final crossAxis = c.maxWidth >= 900
                    ? 4
                    : c.maxWidth >= 600
                        ? 3
                        : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxis,
                    crossAxisSpacing: BananSpacing.lg,
                    mainAxisSpacing: BananSpacing.lg,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final w = items[i];
                    final p = w.product;
                    if (p == null) return const SizedBox.shrink();
                    return ProductCard(
                      name: p.name,
                      imageUrl: p.coverImage,
                      tagline: p.description,
                      tags: p.tags,
                      minPrice: p.minPrice,
                      hasPriceRange: p.hasPriceRange,
                      seasonal: p.isSeasonal,
                      averageRating: p.averageRating,
                      reviewCount: p.reviewCount,
                      stockRemaining: showStock ? p.totalLimitedStock : null,
                      soldOut: showStock && p.isSoldOut,
                      isWishlisted: isWishlisted(wishlistIds, p.id),
                      onToggleWishlist: () async {
                        await ref
                            .read(wishlistIdsProvider.notifier)
                            .toggle(p.id);
                        // Pull the full list so the removed item disappears.
                        ref.invalidate(wishlistProvider);
                      },
                      onTap: () => context.push('/product/${p.id}'),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
