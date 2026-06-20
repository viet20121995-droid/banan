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
class KitchensState {
  const KitchensState({
    this.items = const [],
    this.loading = false,
    this.failure,
  });

  final List<Kitchen> items;
  final bool loading;
  final AppFailure? failure;

  KitchensState copyWith({
    List<Kitchen>? items,
    bool? loading,
    Object? failure = _sentinel,
  }) =>
      KitchensState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
      );
}

const _sentinel = Object();

class KitchensController extends StateNotifier<KitchensState> {
  KitchensController(this._repo) : super(const KitchensState()) {
    refresh();
  }

  final KitchensRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.list();
    res.when(
      success: (list) => state = state.copyWith(items: list, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  /// Deletes a kitchen. Returns null on success, else the failure message
  /// (e.g. KITCHEN_IN_USE) for the UI to surface.
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

final kitchensControllerProvider =
    StateNotifierProvider.autoDispose<KitchensController, KitchensState>((ref) {
  return KitchensController(ref.watch(kitchensRepositoryProvider));
});

class KitchensListScreen extends ConsumerWidget {
  const KitchensListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kitchensControllerProvider);
    final controller = ref.read(kitchensControllerProvider.notifier);
    final isAdmin =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

    return MerchantShell(
      title: 'Bếp',
      onRefresh: controller.refresh,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/kitchens/new'),
              icon: const Icon(Icons.add),
              label: const Text('Tạo bếp'),
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

  final KitchensState state;
  final KitchensController controller;
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
        title: 'Chưa có bếp',
        message:
            'Tạo bếp sản xuất để chuẩn bị đơn. Mỗi cửa hàng có thể chọn một '
            'bếp phụ trách.',
        icon: Icons.soup_kitchen_outlined,
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
        final k = state.items[i];
        return _Row(
          kitchen: k,
          onEdit: isAdmin ? () => context.push('/kitchens/${k.id}/edit') : null,
          onDelete:
              isAdmin ? () => _confirmDelete(context, controller, k) : null,
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    KitchensController controller,
    Kitchen kitchen,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xoá "${kitchen.name}"?'),
        content: const Text(
          'Bếp sẽ bị gỡ. Chỉ xoá được khi không còn nhân viên, đơn hàng, mẻ '
          'sản xuất… và không phải bếp mặc định của cửa hàng nào.',
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
      final error = await controller.delete(kitchen.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(error ?? 'Đã xoá bếp "${kitchen.name}".')),
        );
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.kitchen,
    required this.onEdit,
    required this.onDelete,
  });

  final Kitchen kitchen;
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
                    Icons.soup_kitchen,
                    color: BananColors.cocoaSoft,
                  ),
                ),
              ),
              const SizedBox(width: BananSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kitchen.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: BananSpacing.xs),
                    Text(
                      '${kitchen.address} · ${kitchen.capacityPerHour} đơn/giờ',
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
