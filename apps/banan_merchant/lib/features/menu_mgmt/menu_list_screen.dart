import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';
import '../collections_mgmt/collections_list_screen.dart';

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

  /// Returns the delete outcome so the screen can show the right snackbar.
  /// `null` = the call failed.
  Future<DeleteProductResult?> delete(String id) async {
    final res = await _repo.deleteProduct(id);
    return res.when(
      success: (outcome) async {
        await refresh();
        return outcome;
      },
      failure: (_) => null,
    );
  }

  Future<bool> restore(String id) async {
    final res = await _repo.restoreProduct(id);
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

class MerchantMenuListScreen extends ConsumerStatefulWidget {
  const MerchantMenuListScreen({super.key});

  @override
  ConsumerState<MerchantMenuListScreen> createState() =>
      _MerchantMenuListScreenState();
}

class _MerchantMenuListScreenState
    extends ConsumerState<MerchantMenuListScreen> {
  /// Multi-select mode for the "add to collection" flow. Off by default — the
  /// list behaves exactly as before (tap = edit) until the merchant taps the
  /// "select" action.
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  void _toggle(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _exitSelect() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _showAddToCollectionSheet() async {
    final productIds = _selectedIds.toList();
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddToCollectionSheet(productIds: productIds),
    );
    if ((added ?? false) && mounted) _exitSelect();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantMenuControllerProvider);
    final controller = ref.read(merchantMenuControllerProvider.notifier);
    // The menu is a chain-wide catalog managed by admin. Merchants see it
    // READ-ONLY — no create / edit / delete / add-to-collection controls.
    final isAdmin =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return MerchantShell(
      title: _selectMode ? 'Đã chọn ${_selectedIds.length}' : 'Thực đơn',
      onRefresh: controller.refresh,
      action: _selectMode
          ? TextButton(onPressed: _exitSelect, child: const Text('Xong'))
          : (isAdmin
              ? IconButton(
                  icon: const Icon(Icons.playlist_add_check),
                  tooltip: 'Chọn nhiều để thêm vào bộ sưu tập',
                  onPressed: () => setState(() => _selectMode = true),
                )
              : null),
      floatingActionButton: (_selectMode || !isAdmin)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/menu/new'),
              icon: const Icon(Icons.add),
              label: const Text('Sản phẩm mới'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            hint: 'Tìm sản phẩm của bạn',
            onChanged: controller.setQuery,
          ),
          const SizedBox(height: BananSpacing.lg),
          Expanded(
            child: _Body(
              state: state,
              fmt: fmt,
              controller: controller,
              isAdmin: isAdmin,
              selectMode: _selectMode,
              selectedIds: _selectedIds,
              onToggleSelect: _toggle,
            ),
          ),
          if (_selectMode)
            _SelectionBar(
              count: _selectedIds.length,
              onAdd: _selectedIds.isEmpty ? null : _showAddToCollectionSheet,
            ),
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
    required this.isAdmin,
    required this.selectMode,
    required this.selectedIds,
    required this.onToggleSelect,
  });

  final MerchantMenuState state;
  final NumberFormat fmt;
  final MerchantMenuController controller;
  final bool isAdmin;
  final bool selectMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;

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
        title: 'Chưa có sản phẩm',
        message: 'Chạm "Sản phẩm mới" để thêm chiếc bánh đầu tiên.',
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
            isAdmin: isAdmin,
            selectMode: selectMode,
            selected: selectedIds.contains(p.id),
            onToggleSelect: () => onToggleSelect(p.id),
            onEdit: () => context.push('/menu/${p.id}'),
            onDelete: () => _confirmDelete(context, controller, p),
            onRestore: () async {
              final ok = await controller.restore(p.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..removeCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Đã đưa "${p.name}" trở lại menu.'
                          : 'Không khôi phục được — thử lại.',
                    ),
                  ),
                );
            },
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
        title: Text('Xoá "${product.name}"?'),
        content: const Text(
          'Sản phẩm sẽ bị gỡ khỏi danh mục. '
          'Đơn hàng đã có không bị ảnh hưởng.',
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
      final outcome = await controller.delete(product.id);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
      if (outcome == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Không xoá được — thử lại.')),
        );
      } else if (outcome.deleted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Đã xoá "${product.name}".')),
        );
      } else {
        // Archived because of past orders — explain so the merchant
        // doesn't think the action failed.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '"${product.name}" đã có đơn cũ — chuyển sang trạng thái '
              'Đã ẩn, không bán nữa nhưng giữ lịch sử đơn.',
            ),
            duration: const Duration(seconds: 5),
          ),
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
    required this.onRestore,
    this.isAdmin = false,
    this.selectMode = false,
    this.selected = false,
    this.onToggleSelect,
  });

  final Product product;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final bool isAdmin;
  final bool selectMode;
  final bool selected;
  final VoidCallback? onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      // Merchants get a read-only list — only admin can open the editor.
      onTap: selectMode ? onToggleSelect : (isAdmin ? onEdit : null),
      borderRadius: BananRadii.rlg,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rlg,
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.dividerTheme.color ?? Colors.black12,
          ),
        ),
        child: Row(
          children: [
            if (selectMode) ...[
              Icon(
                selected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: BananSpacing.sm),
            ],
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
                            label: Text('Đã ẩn'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  Text(
                    '${product.category?.name ?? "—"}  ·  '
                    '${product.variants.length} biến thể  ·  '
                    'từ ${fmt.format(product.minPrice)}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!selectMode && isAdmin) ...[
              if (product.isAvailable)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Xoá',
                  onPressed: onDelete,
                )
              else
                IconButton(
                  icon: const Icon(Icons.restore_outlined),
                  tooltip: 'Khôi phục',
                  onPressed: onRestore,
                ),
              const Icon(Icons.chevron_right),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom action bar shown while in multi-select mode — the selected count and
/// the single "add to collection" action. [onAdd] is null (button disabled)
/// until at least one product is selected.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, this.onAdd});

  final int count;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  count == 0
                      ? 'Chọn sản phẩm để thêm'
                      : 'Đã chọn $count sản phẩm',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.collections_bookmark_outlined),
                label: const Text('Thêm vào bộ sưu tập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing the store's collections so the merchant can drop the
/// selected products into one. Pops `true` on success so the caller can leave
/// select mode. Already-present products are skipped server-side, so tapping
/// the same collection twice is harmless.
class _AddToCollectionSheet extends ConsumerStatefulWidget {
  const _AddToCollectionSheet({required this.productIds});

  final List<String> productIds;

  @override
  ConsumerState<_AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState
    extends ConsumerState<_AddToCollectionSheet> {
  bool _busy = false;

  Future<void> _add(Collection c) async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await ref
        .read(collectionsRepositoryProvider)
        .addItems(c.id, widget.productIds);
    if (!mounted) return;
    res.when(
      success: (_) {
        // Item counts changed — keep the collections list fresh.
        ref.read(collectionsControllerProvider.notifier).refresh();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Đã thêm ${widget.productIds.length} sản phẩm vào "${c.name}".',
              ),
            ),
          );
      },
      failure: (f) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(authFailureMessage(f))));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(collectionsControllerProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BananSpacing.lg,
                0,
                BananSpacing.lg,
                BananSpacing.sm,
              ),
              child: Text(
                'Thêm ${widget.productIds.length} sản phẩm vào…',
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (state.loading && state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(BananSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(BananSpacing.lg),
                child: Column(
                  children: [
                    const Text(
                      'Bạn chưa có bộ sưu tập nào. Tạo một bộ rồi quay lại '
                      'thêm sản phẩm.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: BananSpacing.md),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/collections/new');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo bộ sưu tập'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: BananSpacing.md),
                  itemCount: state.items.length,
                  itemBuilder: (context, i) {
                    final c = state.items[i];
                    return ListTile(
                      leading:
                          const Icon(Icons.collections_bookmark_outlined),
                      title: Text(c.name),
                      subtitle: Text('${c.items.length} sản phẩm'),
                      trailing: _busy
                          ? null
                          : const Icon(Icons.add_circle_outline),
                      enabled: !_busy,
                      onTap: () => _add(c),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
