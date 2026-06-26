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
class RefundsState {
  const RefundsState({
    this.refunds = const [],
    this.loading = false,
    this.failure,
    this.statusFilter = RefundStatus.requested,
  });

  final List<Refund> refunds;
  final bool loading;
  final AppFailure? failure;
  final RefundStatus? statusFilter;

  RefundsState copyWith({
    List<Refund>? refunds,
    bool? loading,
    Object? failure = _sentinel,
    Object? statusFilter = _sentinel,
  }) =>
      RefundsState(
        refunds: refunds ?? this.refunds,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
        statusFilter: statusFilter == _sentinel
            ? this.statusFilter
            : statusFilter as RefundStatus?,
      );
}

const _sentinel = Object();

class RefundsController extends StateNotifier<RefundsState> {
  RefundsController(this._repo) : super(const RefundsState()) {
    refresh();
  }

  final RefundRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.list(status: state.statusFilter);
    res.when(
      success: (page) =>
          state = state.copyWith(refunds: page.items, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  Future<void> setFilter(RefundStatus? status) async {
    state = state.copyWith(statusFilter: status);
    await refresh();
  }

  Future<bool> approve(String id) async {
    final res = await _repo.approve(id);
    return res.when(
      success: (_) async {
        await refresh();
        return true;
      },
      failure: (_) => false,
    );
  }

  Future<bool> reject(String id, {String? reason}) async {
    final res = await _repo.reject(id, reason: reason);
    return res.when(
      success: (_) async {
        await refresh();
        return true;
      },
      failure: (_) => false,
    );
  }
}

final refundsControllerProvider =
    StateNotifierProvider.autoDispose<RefundsController, RefundsState>((ref) {
  final controller = RefundsController(ref.watch(refundRepositoryProvider));
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (event.event == 'refund.updated') controller.refresh();
    });
  });
  return controller;
});

class RefundsScreen extends ConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refundsControllerProvider);
    final controller = ref.read(refundsControllerProvider.notifier);
    final fmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return MerchantShell(
      title: 'Hoàn tiền',
      onRefresh: controller.refresh,
      body: Column(
        children: [
          _Filter(selected: state.statusFilter, onSelect: controller.setFilter),
          const SizedBox(height: BananSpacing.lg),
          Expanded(child: _Body(state: state, fmt: fmt, controller: controller)),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.selected, required this.onSelect});
  final RefundStatus? selected;
  final ValueChanged<RefundStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, RefundStatus?)>[
      ('Tất cả', null),
      ('Đã yêu cầu', RefundStatus.requested),
      ('Đang xử lý', RefundStatus.processing),
      ('Hoàn thành', RefundStatus.completed),
      ('Từ chối', RefundStatus.rejected),
    ];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: BananSpacing.sm),
              child: ChoiceChip(
                label: Text(f.$1),
                selected: selected == f.$2,
                onSelected: (_) => onSelect(f.$2),
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
  });

  final RefundsState state;
  final NumberFormat fmt;
  final RefundsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.refunds.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.refunds.isEmpty) {
      return ErrorState(
        message: authFailureMessage(state.failure!),
        onRetry: controller.refresh,
      );
    }
    if (state.refunds.isEmpty) {
      return const EmptyState(
        title: 'Hộp thư trống',
        message: 'Yêu cầu hoàn tiền mới sẽ hiện ở đây theo thời gian thực.',
        icon: Icons.assignment_return_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: BananSpacing.huge),
        itemCount: state.refunds.length,
        separatorBuilder: (_, __) => const SizedBox(height: BananSpacing.md),
        itemBuilder: (context, i) =>
            _Row(refund: state.refunds[i], fmt: fmt, controller: controller),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.refund,
    required this.fmt,
    required this.controller,
  });

  final Refund refund;
  final NumberFormat fmt;
  final RefundsController controller;

  Future<void> _approve(BuildContext context) async {
    final ok = await controller.approve(refund.id);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không duyệt được — thử lại.')),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reason = await _askReason(context);
    if (reason == null) return;
    final ok = await controller.reject(refund.id, reason: reason);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không từ chối được — thử lại.')),
      );
    }
  }

  Future<String?> _askReason(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối hoàn tiền'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Lý do'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intent = switch (refund.status) {
      RefundStatus.requested => StatusIntent.warning,
      RefundStatus.approved => StatusIntent.progress,
      RefundStatus.processing => StatusIntent.progress,
      RefundStatus.completed => StatusIntent.success,
      RefundStatus.rejected => StatusIntent.danger,
      RefundStatus.unknown => StatusIntent.neutral,
    };
    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đơn ${refund.orderId.substring(0, 8)}…',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StatusBadge(label: refund.status.label, intent: intent, dense: true),
            ],
          ),
          const SizedBox(height: BananSpacing.xs),
          Text(
            '${fmt.format(refund.amount)}  ·  '
            '${DateFormat.yMMMd().add_jm().format(refund.createdAt.toLocal())}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: BananSpacing.sm),
          Text(refund.reason, style: theme.textTheme.bodyMedium),
          if (refund.status == RefundStatus.requested) ...[
            const SizedBox(height: BananSpacing.md),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _approve(context),
                  icon: const Icon(Icons.check),
                  label: const Text('Duyệt'),
                ),
                const SizedBox(width: BananSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _reject(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Từ chối'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
