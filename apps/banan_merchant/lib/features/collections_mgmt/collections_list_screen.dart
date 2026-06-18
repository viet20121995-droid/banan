import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/shell/merchant_shell.dart';

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

/// autoDispose so the controller is rebuilt (and the list re-fetched) every
/// time its last listener goes away — e.g. when the "Thêm vào bộ sưu tập"
/// bottom sheet reopens. Without this a collection created moments ago wouldn't
/// appear in the picker until a manual refresh.
final collectionsControllerProvider =
    StateNotifierProvider.autoDispose<CollectionsController, CollectionsState>(
        (ref) {
  return CollectionsController(ref.watch(collectionsRepositoryProvider));
});

class CollectionsListScreen extends ConsumerWidget {
  const CollectionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(collectionsControllerProvider);
    final controller = ref.read(collectionsControllerProvider.notifier);
    // Collections are admin-managed; merchants who deep-link here see read-only.
    final isAdmin =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

    return MerchantShell(
      title: 'Bộ sưu tập',
      onRefresh: controller.refresh,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/collections/new'),
              icon: const Icon(Icons.add),
              label: const Text('Tạo bộ sưu tập'),
            )
          : null,
      body: _Body(state: state, controller: controller, isAdmin: isAdmin),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.controller,
    required this.isAdmin,
  });

  final CollectionsState state;
  final CollectionsController controller;
  final bool isAdmin;

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
        title: 'Chưa có bộ sưu tập',
        message:
            'Nhóm sản phẩm theo chủ đề ("Đặc sắc hôm nay", "Sinh nhật"…) — '
            'các bộ ghim sẽ hiển thị ở trang chủ khách hàng.',
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
            onEdit: isAdmin ? () => context.push('/collections/${c.id}') : null,
            onDelete:
                isAdmin ? () => _confirmDelete(context, controller, c) : null,
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
        title: Text('Xoá "${collection.name}"?'),
        content: const Text(
          'Bộ sưu tập sẽ bị gỡ khỏi trang chủ khách hàng. '
          'Sản phẩm bên trong không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirm ?? false) {
      final ok = await controller.delete(collection.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Đã xoá bộ sưu tập "${collection.name}".'
                  : 'Không xoá được — thử lại.',
            ),
          ),
        );
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
  // Null for non-admin (read-only): tap does nothing, delete button hidden.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                            label: Text('Đã ẩn'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  Text(
                    '${collection.items.length} sản phẩm'
                    '${collection.description != null && collection.description!.isNotEmpty ? "  ·  ${collection.description}" : ""}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Xoá',
                onPressed: onDelete,
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
