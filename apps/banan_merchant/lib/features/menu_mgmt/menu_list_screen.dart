import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

@immutable
class MerchantMenuState {
  const MerchantMenuState({
    this.products = const [],
    this.loading = false,
    this.failure,
    this.query = '',
  });

  final List<Product> products;
  final bool loading;
  final AppFailure? failure;
  final String query;

  MerchantMenuState copyWith({
    List<Product>? products,
    bool? loading,
    Object? failure = _sentinel,
    String? query,
  }) =>
      MerchantMenuState(
        products: products ?? this.products,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
        query: query ?? this.query,
      );
}

const _sentinel = Object();

class MerchantMenuController extends StateNotifier<MerchantMenuState> {
  MerchantMenuController(this._repo) : super(const MerchantMenuState()) {
    refresh();
  }

  final CatalogRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.merchantProducts(
      q: state.query.trim().isEmpty ? null : state.query.trim(),
    );
    res.when(
      success: (page) {
        state = state.copyWith(products: page.items, loading: false);
      },
      failure: (f) {
        state = state.copyWith(loading: false, failure: f);
      },
    );
  }

  Future<void> setQuery(String q) async {
    state = state.copyWith(query: q);
    await refresh();
  }

  Future<bool> delete(String id) async {
    final res = await _repo.deleteProduct(id);
    return res.when(
      success: (_) async {
        await refresh();
        return true;
      },
      failure: (_) => false,
    );
  }
}

final merchantMenuControllerProvider = StateNotifierProvider.autoDispose<
    MerchantMenuController, MerchantMenuState>((ref) {
  return MerchantMenuController(ref.watch(catalogRepositoryProvider));
});

class MerchantMenuListScreen extends ConsumerWidget {
  const MerchantMenuListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(merchantMenuControllerProvider);
    final controller = ref.read(merchantMenuControllerProvider.notifier);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Orders',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/menu/new'),
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            hint: 'Search your products',
            onChanged: controller.setQuery,
          ),
          const SizedBox(height: BananSpacing.lg),
          Expanded(child: _Body(state: state, fmt: fmt, controller: controller)),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.fmt,
    required this.controller,
  });

  final MerchantMenuState state;
  final NumberFormat fmt;
  final MerchantMenuController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.products.isEmpty) {
      return ErrorState(
        message: authFailureMessage(state.failure!),
        onRetry: controller.refresh,
      );
    }
    if (state.products.isEmpty) {
      return const EmptyState(
        title: 'No products yet',
        message: 'Tap "New product" to add your first cake.',
        icon: Icons.cake_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: BananSpacing.huge),
        itemCount: state.products.length,
        separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.md),
        itemBuilder: (context, i) {
          final p = state.products[i];
          return _Row(
            product: p,
            fmt: fmt,
            onEdit: () => context.push('/menu/${p.id}'),
            onDelete: () => _confirmDelete(context, controller, p),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MerchantMenuController controller,
    Product product,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${product.name}"?'),
        content: const Text(
          'This product will be removed from the catalog. '
          'Existing orders are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm ?? false) {
      final ok = await controller.delete(product.id);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete — try again.')),
        );
      }
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.product,
    required this.fmt,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onEdit,
      borderRadius: BananRadii.rlg,
      child: Container(
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
                width: 72,
                height: 72,
                child: product.coverImage == null
                    ? Container(
                        color: BananColors.surfaceDim,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.cake_outlined,
                          color: BananColors.cocoaSoft,
                        ),
                      )
                    : Image.network(product.coverImage!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!product.isAvailable)
                        const Padding(
                          padding: EdgeInsets.only(left: BananSpacing.sm),
                          child: Chip(
                            label: Text('Hidden'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  Text(
                    '${product.category?.name ?? "—"}  ·  '
                    '${product.variants.length} variant'
                    '${product.variants.length == 1 ? "" : "s"}  ·  '
                    'from ${fmt.format(product.minPrice)}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
