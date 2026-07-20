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
class CategoriesState {
  const CategoriesState({
    this.items = const [],
    this.loading = false,
    this.failure,
  });

  final List<Category> items;
  final bool loading;
  final AppFailure? failure;

  CategoriesState copyWith({
    List<Category>? items,
    bool? loading,
    Object? failure = _sentinel,
  }) =>
      CategoriesState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
      );
}

const _sentinel = Object();

class CategoriesController extends StateNotifier<CategoriesState> {
  CategoriesController(this._repo) : super(const CategoriesState()) {
    refresh();
  }

  final CatalogRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    // Merchant manager lists hidden categories too (so they can be unhidden).
    final res = await _repo.categories(includeHidden: true);
    res.when(
      success: (list) => state = state.copyWith(items: list, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  /// Toggles a category's storefront visibility. Returns null on success,
  /// else the failure message.
  Future<String?> toggleHidden(Category c) async {
    final res = await _repo.setCategoryHidden(c.id, hidden: !c.isHidden);
    return res.when(
      success: (_) async {
        await refresh();
        return null;
      },
      failure: authFailureMessage,
    );
  }

  /// Optimistically reorder, persist, then refresh from the server. Returns
  /// the failure message on error (caller surfaces it) or null on success.
  Future<String?> reorder(int oldIndex, int newIndex) async {
    final items = [...state.items];
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final moved = items.removeAt(oldIndex);
    items.insert(adjusted, moved);
    state = state.copyWith(items: items);
    final res = await _repo.reorderCategories(items.map((c) => c.id).toList());
    return res.when(
      success: (_) async {
        await refresh();
        return null;
      },
      failure: (f) async {
        await refresh();
        return authFailureMessage(f);
      },
    );
  }

  /// Deletes a category. Returns null on success, otherwise the failure
  /// message (e.g. CATEGORY_HAS_PRODUCTS) so the UI can show it.
  Future<String?> delete(String id, {bool force = false}) async {
    final res = await _repo.deleteCategory(id, force: force);
    return res.when(
      success: (_) async {
        await refresh();
        return null;
      },
      failure: authFailureMessage,
    );
  }
}

/// autoDispose so the list re-fetches each time the screen remounts (e.g. on
/// returning from the editor) — keeps the order/pinned flags fresh.
final categoriesControllerProvider = StateNotifierProvider.autoDispose<
    CategoriesController, CategoriesState>((ref) {
  return CategoriesController(ref.watch(catalogRepositoryProvider));
});

class CategoriesListScreen extends ConsumerWidget {
  const CategoriesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoriesControllerProvider);
    final controller = ref.read(categoriesControllerProvider.notifier);
    // Categories are admin-managed; non-admins who deep-link here see read-only.
    final isAdmin =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

    return MerchantShell(
      title: 'Danh mục',
      onRefresh: controller.refresh,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/categories/new'),
              icon: const Icon(Icons.add),
              label: const Text('Tạo danh mục'),
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

  final CategoriesState state;
  final CategoriesController controller;
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
        title: 'Chưa có danh mục',
        message:
            'Tạo danh mục để phân loại sản phẩm ("Bánh kem", "Cupcake"…). '
            'danh mục được ghim sẽ hiển thị thành dải sản phẩm ở trang chủ.',
        icon: Icons.category_outlined,
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        BananSpacing.md,
        BananSpacing.md,
        BananSpacing.md,
        BananSpacing.huge,
      ),
      itemCount: state.items.length,
      buildDefaultDragHandles: false,
      onReorder: isAdmin
          ? (oldIndex, newIndex) async {
              final msg = await controller.reorder(oldIndex, newIndex);
              if (msg != null && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..removeCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(msg)));
              }
            }
          : (_, __) {},
      itemBuilder: (context, i) {
        final c = state.items[i];
        return _Row(
          key: ValueKey(c.id),
          category: c,
          index: i,
          isAdmin: isAdmin,
          onEdit: isAdmin ? () => context.push('/categories/${c.id}/edit') : null,
          onDelete:
              isAdmin ? () => _confirmDelete(context, controller, c) : null,
          onToggleHidden:
              isAdmin ? () => _toggleHidden(context, controller, c) : null,
        );
      },
    );
  }

  Future<void> _toggleHidden(
    BuildContext context,
    CategoriesController controller,
    Category category,
  ) async {
    final error = await controller.toggleHidden(category);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                (category.isHidden
                    ? 'Đã hiện lại danh mục "${category.name}".'
                    : 'Đã ẩn danh mục "${category.name}" khỏi cửa hàng.'),
          ),
        ),
      );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoriesController controller,
    Category category,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xoá "${category.name}"?'),
        content: const Text(
          'Chỉ xoá được danh mục khi không còn sản phẩm. Nếu còn sản phẩm, '
          'chọn "Xoá cả sản phẩm" để xoá luôn. Sản phẩm đã có trong đơn hàng '
          'sẽ được giữ lại và chặn xoá (hãy ẩn danh mục trong trường hợp đó).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'normal'),
            child: const Text('Chỉ xoá danh mục'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, 'force'),
            child: const Text('Xoá cả sản phẩm'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final force = choice == 'force';
    final error = await controller.delete(category.id, force: force);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                (force
                    ? 'Đã xoá danh mục "${category.name}" và sản phẩm của nó.'
                    : 'Đã xoá danh mục "${category.name}".'),
          ),
        ),
      );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.category,
    required this.index,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleHidden,
    super.key,
  });

  final Category category;
  final int index;
  final bool isAdmin;
  // Null for non-admin (read-only): tap does nothing, action buttons hidden.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BananSpacing.md),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BananRadii.rlg,
        child: Container(
          padding: const EdgeInsets.all(BananSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BananRadii.rlg,
            color: theme.colorScheme.surface,
            border:
                Border.all(color: theme.dividerTheme.color ?? Colors.black12),
          ),
          child: Row(
            children: [
              if (isAdmin)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: BananSpacing.sm),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ClipRRect(
                borderRadius: BananRadii.rmd,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: category.imageUrl == null ||
                          category.imageUrl!.isEmpty
                      ? Container(
                          color: BananColors.surfaceDim,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.category_outlined,
                            color: BananColors.cocoaSoft,
                          ),
                        )
                      : Image.network(category.imageUrl!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: BananSpacing.xs),
                    if (category.isHidden)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 14,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: BananSpacing.xs),
                          Text(
                            'Đang ẩn khỏi cửa hàng',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      )
                    else if (category.isPinnedToHome)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: BananSpacing.xs),
                          Text(
                            'Ghim trang chủ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        category.slug,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onToggleHidden != null)
                IconButton(
                  icon: Icon(
                    category.isHidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: category.isHidden
                      ? 'Hiện lại trong cửa hàng'
                      : 'Ẩn khỏi cửa hàng',
                  onPressed: onToggleHidden,
                ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Xoá',
                  onPressed: onDelete,
                ),
              if (onEdit != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
