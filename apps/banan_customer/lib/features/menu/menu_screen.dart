import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../cart/cart_controller.dart';
import '../notifications/notifications_controller.dart';
import 'menu_controller.dart';

/// Pinned collections shown as horizontal carousels at the top of the menu.
final homeCollectionsProvider = FutureProvider<List<Collection>>((ref) async {
  final repo = ref.watch(collectionsRepositoryProvider);
  final res = await repo.homeCollections();
  return res.when(
    success: (list) => list,
    failure: (_) => const [],
  );
});

/// Latest published threads — shown as a strip above the menu grid.
final homeThreadsProvider = FutureProvider<List<Thread>>((ref) async {
  final repo = ref.watch(threadsRepositoryProvider);
  final res = await repo.published(limit: 5);
  return res.when(
    success: (list) => list,
    failure: (_) => const [],
  );
});

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(menuControllerProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final controller = ref.read(menuControllerProvider.notifier);

    final cart = ref.watch(cartControllerProvider);
    final unread =
        ref.watch(notificationsControllerProvider.select((s) => s.unread));

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Banan'),
        actions: [
          _NotificationsButton(unread: unread),
          IconButton(
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: 'Membership',
            onPressed: () => context.push('/membership'),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'My orders',
            onPressed: () => context.push('/orders'),
          ),
          _CartButton(itemCount: cart.itemCount),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.servedFromCache)
            _OfflineBanner(
              cacheUpdatedAt: state.cacheUpdatedAt,
              onRetry: controller.refresh,
            ),
          SearchField(
            hint: 'Search cakes, flavors, occasions',
            onChanged: controller.setQuery,
          ),
          const SizedBox(height: BananSpacing.md),
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) => _CategoryChips(
              categories: categories,
              selectedId: state.categoryId,
              onSelect: controller.selectCategory,
            ),
          ),
          const SizedBox(height: BananSpacing.lg),
          Expanded(
            child: _Body(
              state: state,
              onRetry: controller.refresh,
              showHomeContent: state.categoryId == null && state.query.isEmpty,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.cacheUpdatedAt, required this.onRetry});

  final DateTime? cacheUpdatedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = cacheUpdatedAt == null
        ? null
        : _ageLabel(DateTime.now().difference(cacheUpdatedAt!));
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.md,
        vertical: BananSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: BananColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: BananColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: BananColors.warning),
          const SizedBox(width: BananSpacing.sm),
          Expanded(
            child: Text(
              age == null
                  ? "You're offline. Showing the last menu we had."
                  : "You're offline. Menu is from $age ago.",
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  String _ageLabel(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.itemCount});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return _BadgedIcon(
      icon: Icons.shopping_bag_outlined,
      tooltip: 'Cart',
      count: itemCount,
      onPressed: () => GoRouter.of(context).push('/cart'),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.unread});
  final int unread;

  @override
  Widget build(BuildContext context) {
    return _BadgedIcon(
      icon: Icons.notifications_outlined,
      tooltip: 'Notifications',
      count: unread,
      onPressed: () => GoRouter.of(context).push('/notifications'),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.tooltip,
    required this.count,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: const BoxDecoration(
                color: BananColors.primary,
                borderRadius: BananRadii.rPill,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: 'All',
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          ...categories.map(
            (c) => _Chip(
              label: c.name,
              selected: selectedId == c.id,
              onTap: () => onSelect(c.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: BananSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.state,
    required this.onRetry,
    required this.showHomeContent,
  });

  final MenuState state;
  final Future<void> Function() onRetry;
  final bool showHomeContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.products.isEmpty) {
      return ErrorState(
        message: authFailureMessage(state.failure!),
        onRetry: onRetry,
      );
    }
    if (state.loaded && state.products.isEmpty && !showHomeContent) {
      return const EmptyState(
        title: 'No cakes match',
        message: 'Try a different category or clear your search.',
      );
    }
    return BreakpointBuilder(
      builder: (context, bp) {
        final crossAxis = switch (bp) {
          Breakpoint.xs => 2,
          Breakpoint.sm => 2,
          Breakpoint.md => 3,
          Breakpoint.lg => 4,
          Breakpoint.xl => 4,
        };
        return RefreshIndicator(
          onRefresh: () async {
            await onRetry();
            ref
              ..invalidate(homeCollectionsProvider)
              ..invalidate(homeThreadsProvider);
          },
          child: CustomScrollView(
            slivers: [
              if (showHomeContent) ...[
                SliverToBoxAdapter(child: _ThreadsStrip()),
                SliverToBoxAdapter(child: _PinnedCollections()),
              ],
              if (showHomeContent &&
                  state.loaded &&
                  state.products.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: BananSpacing.lg,
                      bottom: BananSpacing.md,
                    ),
                    child: Text(
                      'All cakes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.only(bottom: BananSpacing.xxxl),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxis,
                    crossAxisSpacing: BananSpacing.lg,
                    mainAxisSpacing: BananSpacing.lg,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: state.products.length,
                  itemBuilder: (context, i) {
                    final p = state.products[i];
                    return ProductCard(
                      name: p.name,
                      imageUrl: p.coverImage,
                      tagline: p.description,
                      tags: p.tags,
                      minPrice: p.minPrice,
                      hasPriceRange: p.hasPriceRange,
                      seasonal: p.isSeasonal,
                      onTap: () => context.push('/product/${p.id}'),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Horizontal strip of recent published threads. Hidden if there are none.
class _ThreadsStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeThreadsProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (threads) {
        if (threads.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: BananSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: BananSpacing.sm),
                child: Text(
                  'From the bakery',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: threads.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: BananSpacing.md),
                  itemBuilder: (context, i) =>
                      _ThreadCard(thread: threads[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread});
  final Thread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.MMMd();
    final published = thread.publishedAt ?? thread.createdAt;
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rlg,
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BananRadii.rmd,
              child: SizedBox(
                width: 56,
                height: 56,
                child: thread.imageUrl == null || thread.imageUrl!.isEmpty
                    ? Container(
                        color: BananColors.surfaceDim,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.forum_outlined,
                          color: BananColors.cocoaSoft,
                        ),
                      )
                    : Image.network(thread.imageUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  Text(
                    thread.body,
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    fmt.format(published.toLocal()),
                    style: theme.textTheme.labelSmall,
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

/// Pinned collections — each one renders as its own horizontal product carousel.
class _PinnedCollections extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeCollectionsProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (collections) {
        final visible = collections.where((c) => c.products.isNotEmpty).toList();
        if (visible.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in visible) _CollectionStrip(collection: c),
          ],
        );
      },
    );
  }
}

class _CollectionStrip extends StatelessWidget {
  const _CollectionStrip({required this.collection});
  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final products = collection.products;
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: BananSpacing.xs),
            child: Text(
              collection.name,
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (collection.description != null &&
              collection.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: BananSpacing.sm),
              child: Text(
                collection.description!,
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            const SizedBox(height: BananSpacing.sm),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: BananSpacing.md),
              itemBuilder: (context, i) {
                final p = products[i];
                return SizedBox(
                  width: 180,
                  child: ProductCard(
                    name: p.name,
                    imageUrl: p.coverImage,
                    minPrice: p.minPrice,
                    hasPriceRange: p.hasPriceRange,
                    seasonal: p.isSeasonal,
                    tags: p.tags,
                    onTap: () => context.push('/product/${p.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
