import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'kanban_controller.dart';

class KanbanScreen extends ConsumerWidget {
  const KanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(kanbanControllerProvider);
    final controller = ref.read(kanbanControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Analytics',
            onPressed: () => context.push('/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: controller.refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: state.loading && state.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : (state.failure != null && state.orders.isEmpty)
              ? ErrorState(
                  message: authFailureMessage(state.failure!),
                  onRetry: controller.refresh,
                )
              : _Board(state: state, controller: controller),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.state, required this.controller});

  final KanbanState state;
  final KanbanController controller;

  @override
  Widget build(BuildContext context) {
    final byColumn = state.byColumn;
    return Padding(
      padding: const EdgeInsets.all(BananSpacing.lg),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final column in KitchenStatus.orderedColumns)
              Padding(
                padding: const EdgeInsets.only(right: BananSpacing.lg),
                child: _Column(
                  title: column.label,
                  status: column,
                  cards: byColumn[column] ?? const [],
                  controller: controller,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.title,
    required this.status,
    required this.cards,
    required this.controller,
  });

  final String title;
  final KitchenStatus status;
  final List<Order> cards;
  final KanbanController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rlg,
        color: BananColors.surfaceDim.withValues(alpha: 0.6),
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BananSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BananRadii.rPill,
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Text(
                  '${cards.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          if (cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BananSpacing.xl),
              child: Text(
                'Empty',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final order in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: BananSpacing.sm),
                child: _Card(
                  order: order,
                  status: status,
                  controller: controller,
                ),
              ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.order,
    required this.status,
    required this.controller,
  });

  final Order order;
  final KitchenStatus status;
  final KanbanController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = order.items
        .map((i) => '${i.quantity}× ${i.productName}')
        .join('\n');
    final next = status.next;

    Future<void> handleAdvance() async {
      final ok = await controller.advance(order.id, next!);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not advance — try again.')),
        );
      }
    }

    Future<void> handleDispatch() async {
      final ok = await controller.dispatch(order.id);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not dispatch — try again.')),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                order.fulfillmentType == FulfillmentType.delivery
                    ? Icons.delivery_dining_outlined
                    : Icons.storefront_outlined,
                size: 16,
              ),
              const SizedBox(width: BananSpacing.xs),
              Expanded(
                child: Text(order.code, style: theme.textTheme.titleSmall),
              ),
              Text(
                DateFormat.jm().format(order.updatedAt.toLocal()),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.xs),
          Text(summary, style: theme.textTheme.bodySmall),
          const SizedBox(height: BananSpacing.sm),
          if (status == KitchenStatus.readyDispatch)
            FilledButton.icon(
              onPressed: handleDispatch,
              icon: const Icon(Icons.local_shipping_outlined, size: 16),
              label: const Text('Dispatch'),
            )
          else if (next != null)
            FilledButton.tonalIcon(
              onPressed: handleAdvance,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text('Move to ${next.label}'),
            ),
        ],
      ),
    );
  }
}
