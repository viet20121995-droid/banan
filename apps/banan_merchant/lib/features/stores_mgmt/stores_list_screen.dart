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
class StoresState {
  const StoresState({this.items = const [], this.loading = false, this.failure});

  final List<Store> items;
  final bool loading;
  final AppFailure? failure;

  StoresState copyWith({
    List<Store>? items,
    bool? loading,
    Object? failure = _sentinel,
  }) =>
      StoresState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
      );
}

const _sentinel = Object();

class StoresController extends StateNotifier<StoresState> {
  StoresController(this._repo) : super(const StoresState()) {
    refresh();
  }

  final StoresRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.listForAdmin();
    res.when(
      success: (list) => state = state.copyWith(items: list, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  /// Deletes a branch. Returns null on success, otherwise the user-facing
  /// failure message (e.g. STORE_IN_USE) so the UI can surface it.
  Future<String?> delete(String id) async {
    final res = await _repo.delete(id);
    return res.when(
      success: (_) async {
        await refresh();
        return null;
      },
      failure: authFailureMessage,
    );
  }
}

final storesControllerProvider =
    StateNotifierProvider.autoDispose<StoresController, StoresState>((ref) {
  return StoresController(ref.watch(storesRepositoryProvider));
});

class StoresListScreen extends ConsumerWidget {
  const StoresListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storesControllerProvider);
    final controller = ref.read(storesControllerProvider.notifier);
    // Chain infrastructure — admin-managed. Non-admins who deep-link see read-only.
    final isAdmin =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

    return MerchantShell(
      title: 'Cửa hàng (chuỗi)',
      onRefresh: controller.refresh,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/stores/new'),
              icon: const Icon(Icons.add),
              label: const Text('Tạo cửa hàng'),
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

  final StoresState state;
  final StoresController controller;
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
        title: 'Chưa có cửa hàng',
        message:
            'Tạo chi nhánh để khách chọn điểm lấy hàng và để định tuyến đơn '
            'tới bếp phụ trách.',
        icon: Icons.storefront_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        BananSpacing.md,
        BananSpacing.md,
        BananSpacing.md,
        BananSpacing.huge,
      ),
      itemCount: state.items.length,
      itemBuilder: (context, i) {
        final s = state.items[i];
        return _Row(
          store: s,
          onEdit: isAdmin ? () => context.push('/stores/${s.id}/edit') : null,
          onDelete: isAdmin ? () => _confirmDelete(context, controller, s) : null,
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    StoresController controller,
    Store store,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xoá "${store.name}"?'),
        content: const Text(
          'Chi nhánh sẽ bị gỡ. Chỉ xoá được khi không còn nhân viên, sản phẩm, '
          'đơn hàng… liên kết.',
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
      final error = await controller.delete(store.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(error ?? 'Đã xoá cửa hàng "${store.name}".')),
        );
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.store, required this.onEdit, required this.onDelete});

  final Store store;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
            border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BananRadii.rmd,
                child: Container(
                  width: 56,
                  height: 56,
                  color: BananColors.surfaceDim,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.storefront,
                    color: BananColors.cocoaSoft,
                  ),
                ),
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            store.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (store.isPaused) ...[
                          const SizedBox(width: BananSpacing.sm),
                          _PausedBadge(theme: theme),
                        ],
                      ],
                    ),
                    const SizedBox(height: BananSpacing.xs),
                    Text(
                      store.address,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
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
              if (onEdit != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _PausedBadge extends StatelessWidget {
  const _PausedBadge({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BananSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rsm,
        color: theme.colorScheme.errorContainer,
      ),
      child: Text(
        'Tạm nghỉ',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
