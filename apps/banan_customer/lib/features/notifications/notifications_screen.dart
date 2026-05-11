import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'notifications_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unread > 0)
            TextButton.icon(
              onPressed: controller.markAllRead,
              icon: const Icon(Icons.done_all),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: _Body(state: state, controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final NotificationsState state;
  final NotificationsController controller;

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
        title: 'No notifications yet',
        message: 'Order updates and offers land here.',
        icon: Icons.notifications_none_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: BananSpacing.md),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) {
          final n = state.items[i];
          return _Tile(notification: n, onTap: () => _open(context, n));
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, NotificationEntry n) async {
    if (!n.isRead) {
      await controller.markRead(n.id);
    }
    if (!context.mounted) return;
    final path = n.deepLinkPath;
    if (path != null) context.push(path);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.notification, required this.onTap});
  final NotificationEntry notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relTime = _formatTimestamp(notification.createdAt);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.lg,
          vertical: BananSpacing.md,
        ),
        color: notification.isRead
            ? null
            : theme.colorScheme.primary.withValues(alpha: 0.04),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                _iconFor(notification.type),
                color: theme.colorScheme.primary,
                size: 20,
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
                          notification.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        relTime,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(notification.body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(width: BananSpacing.sm),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'order.status_changed':
        return Icons.receipt_long_outlined;
      case 'order.kitchen_status_changed':
        return Icons.kitchen_outlined;
      case 'refund.updated':
        return Icons.refresh;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTimestamp(DateTime created) {
    final now = DateTime.now();
    final diff = now.difference(created);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.yMMMd().format(created.toLocal());
  }
}
