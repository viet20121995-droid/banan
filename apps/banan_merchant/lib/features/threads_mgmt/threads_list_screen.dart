import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart' as domain;
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Threads'),
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
        onPressed: () => context.push('/threads/new'),
        icon: const Icon(Icons.edit_note),
        label: const Text('New thread'),
      ),
      body: _Body(state: state, controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});
  final ThreadsState state;
  final ThreadsController controller;

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
        title: 'No threads yet',
        message:
            'Threads are short posts that show up on the customer home — '
            'use them for new arrivals, seasonal news, or behind-the-scenes.',
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
            onEdit: () => context.push('/threads/${t.id}'),
            onDelete: () => _confirmDelete(context, controller, t),
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
        title: Text('Delete "${thread.title}"?'),
        content: const Text('This thread will be removed for all customers.'),
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
      final ok = await controller.delete(thread.id);
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
    required this.thread,
    required this.onEdit,
    required this.onDelete,
  });

  final domain.Thread thread;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                          label: thread.isPublished ? 'Published' : 'Draft',
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
                        ? 'Published ${fmt.format(thread.publishedAt!.toLocal())}'
                        : 'Updated ${fmt.format(thread.updatedAt.toLocal())}',
                    style: theme.textTheme.labelSmall,
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

