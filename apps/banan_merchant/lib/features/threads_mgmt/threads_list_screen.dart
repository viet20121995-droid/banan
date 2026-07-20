import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart' as domain;
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/shell/merchant_shell.dart';

@immutable
class ThreadsState {
  const ThreadsState({
    this.items = const [],
    this.loading = false,
    this.failure,
  });

  final List<domain.Thread> items;
  final bool loading;
  final AppFailure? failure;

  ThreadsState copyWith({
    List<domain.Thread>? items,
    bool? loading,
    Object? failure = _sentinel,
  }) =>
      ThreadsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
      );
}

const _sentinel = Object();

class ThreadsController extends StateNotifier<ThreadsState> {
  ThreadsController(this._repo) : super(const ThreadsState()) {
    refresh();
  }

  final domain.ThreadsRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.storeThreads();
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

final threadsControllerProvider =
    StateNotifierProvider<ThreadsController, ThreadsState>((ref) {
  return ThreadsController(ref.watch(threadsRepositoryProvider));
});

class ThreadsListScreen extends ConsumerWidget {
  const ThreadsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(threadsControllerProvider);
    final controller = ref.read(threadsControllerProvider.notifier);
    // Posts are admin-managed; merchants who deep-link here see read-only.
    final isAdmin =
        ref.watch(authSessionProvider).valueOrNull?.user.role.isAdmin ?? false;

    return MerchantShell(
      title: 'Bài đăng',
      onRefresh: controller.refresh,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/threads/new'),
              icon: const Icon(Icons.edit_note),
              label: const Text('Bài đăng mới'),
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
  final ThreadsState state;
  final ThreadsController controller;
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
        title: 'Chưa có bài đăng',
        message:
            'Bài đăng là những mẩu tin ngắn hiển thị trên trang chủ của khách, '
            'dùng cho hàng mới, tin theo mùa hoặc hậu trường.',
        icon: Icons.forum_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: BananSpacing.huge),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.md),
        itemBuilder: (context, i) {
          final t = state.items[i];
          return _Row(
            thread: t,
            onEdit: isAdmin ? () => context.push('/threads/${t.id}') : null,
            onDelete:
                isAdmin ? () => _confirmDelete(context, controller, t) : null,
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ThreadsController controller,
    domain.Thread thread,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xoá "${thread.title}"?'),
        content: const Text('Bài đăng sẽ bị gỡ khỏi mọi khách hàng.'),
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
      final ok = await controller.delete(thread.id);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không xoá được, thử lại.')),
        );
      }
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.thread,
    required this.onEdit,
    required this.onDelete,
  });

  final domain.Thread thread;
  // Null for non-admin → read-only (tap inert, delete hidden).
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd().add_jm();
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: BananSpacing.sm),
                        child: StatusBadge(
                          label: thread.isPublished ? 'Đã đăng' : 'Bản nháp',
                          intent: thread.isPublished
                              ? StatusIntent.success
                              : StatusIntent.neutral,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  Text(
                    thread.body,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: BananSpacing.xs),
                  Text(
                    thread.publishedAt != null
                        ? 'Đăng lúc ${fmt.format(thread.publishedAt!.toLocal())}'
                        : 'Cập nhật ${fmt.format(thread.updatedAt.toLocal())}',
                    style: theme.textTheme.labelSmall,
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

