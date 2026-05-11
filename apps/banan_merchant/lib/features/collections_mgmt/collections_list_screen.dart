import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

@immutable
class CollectionsState {
  const CollectionsState({
    this.items = const [],
    this.loading = false,
    this.failure,
  });

  final List<Collection> items;
  final bool loading;
  final AppFailure? failure;

  CollectionsState copyWith({
    List<Collection>? items,
    bool? loading,
    Object? failure = _sentinel,
  }) =>
      CollectionsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
      );
}

const _sentinel = Object();

class CollectionsController extends StateNotifier<CollectionsState> {
  CollectionsController(this._repo) : super(const CollectionsState()) {
    refresh();
  }

  final CollectionsRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.storeCollections();
    res.when(
      success: (list) =>
          state = state.copyWith(items: list, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  Future<bool> delete(String id) async {
    final res = await _repo.delete(id);
    return res.when(
      success: (_) async {
        await refresh();
        return true;
      },
      failure: (_) => false,
    );
  }
}

final collectionsControllerProvider =
    StateNotifierProvider<CollectionsController, CollectionsState>((ref) {
  return CollectionsController(ref.watch(collectionsRepositoryProvider));
});

class CollectionsListScreen extends ConsumerWidget {
  const CollectionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionsControllerProvider);
    final controller = ref.read(collectionsControllerProvider.notifier);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Orders',
            onPressed: () => context.go('/'),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Menu',
            onPressed: () => context.go('/menu'),
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
        onPressed: () => context.push('/collections/new'),
        icon: const Icon(Icons.add),
        label: const Text('New collection'),
      ),
      body: _Body(state: state, controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final CollectionsState state;
  final CollectionsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.items.isEmpty) {
      return ErrorState(
        message: authFailureMessage(state.failure!),
        onRetry: controller.refresh,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        title: 'No collections yet',
        message:
            'Group products into "Today\'s specials", "Birthday picks", '
            'or any theme — pinned collections show up on the customer home.',
        icon: Icons.collections_bookmark_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: BananSpacing.huge),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.md),
        itemBuilder: (context, i) {
          final c = state.items[i];
          return _Row(
            collection: c,
            onEdit: () => context.push('/collections/${c.id}'),
            onDelete: () => _confirmDelete(context, controller, c),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CollectionsController controller,
    Collection collection,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${collection.name}"?'),
        content: const Text(
          'The collection is removed from the customer home page. '
          'The products inside it are not affected.',
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
      final ok = await controller.delete(collection.id);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete — try again.')),
        );
      }
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.collection,
    required this.onEdit,
    required this.onDelete,
  });

  final Collection collection;
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
                width: 64,
                height: 64,
                child: collection.imageUrl == null ||
                        collection.imageUrl!.isEmpty
                    ? Container(
                        color: BananColors.surfaceDim,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.collections_bookmark_outlined,
                          color: BananColors.cocoaSoft,
                        ),
                      )
                    : Image.network(collection.imageUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: BananSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          collection.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (collection.isPinnedToHome)
                        Padding(
                          padding: const EdgeInsets.only(left: BananSpacing.sm),
                          child: Icon(
                            Icons.push_pin,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      if (!collection.isActive)
                        const Padding(
                          padding: EdgeInsets.only(left: BananSpacing.sm),
                          child: Chip(
                            label: Text('Inactive'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  Text(
                    '${collection.items.length} '
                    'product${collection.items.length == 1 ? "" : "s"}'
                    '${collection.description != null && collection.description!.isNotEmpty ? "  ·  ${collection.description}" : ""}',
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
