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
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantMenuControllerProvider);
    final controller = ref.read(merchantMenuControllerProvider.notifier);
    // The menu is a chain-wide catalog managed by admin. Merchants see it
    // READ-ONLY — no create / edit / delete controls.
    final isAdmin =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return MerchantShell(
      title: 'Thực đơn',
      onRefresh: controller.refresh,
      floatingActionButton: !isAdmin
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
            ),
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
  });

  final MerchantMenuState state;
  final NumberFormat fmt;
  final MerchantMenuController controller;
  final bool isAdmin;

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
  });

  final Product product;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      // Merchants get a read-only list — only admin can open the editor.
      onTap: isAdmin ? onEdit : null,
      borderRadius: BananRadii.rlg,
      child: Container(
        padding: const EdgeInsets.all(BananSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rlg,
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.dividerTheme.color ?? Colors.black12,
          ),
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
            if (isAdmin) ...[
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
