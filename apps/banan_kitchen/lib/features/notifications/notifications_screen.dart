import 'dart:async';

import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'notifications_controller.dart';

/// Kitchen notification inbox — surfaces the MES background jobs (HSD/overdue
/// digest, QC alerts) plus anything else routed to the signed-in user. Tapping a
/// QC-alert notification deep-links to the MO it names.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (state.unread > 0)
            TextButton.icon(
              onPressed: controller.markAllRead,
              icon: const Icon(Icons.done_all),
              label: const Text('Đọc hết'),
            ),
        ],
      ),
      body: _body(context, state, controller),
    );
  }

  Widget _body(
    BuildContext context,
    NotificationsState state,
    NotificationsController controller,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.failure != null && state.items.isEmpty) {
      return ErrorState(
        message: state.failure!.message ?? state.failure!.code,
        onRetry: controller.refresh,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        title: 'Chưa có thông báo',
        message: 'Nhắc việc sản xuất và cảnh báo QC sẽ hiện ở đây.',
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
          return _Tile(
            notification: n,
            onTap: () => _open(context, controller, n),
          );
        },
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    NotificationsController controller,
    NotificationEntry n,
  ) async {
    if (!n.isRead) await controller.markRead(n.id);
    if (!context.mounted) return;
    final moId = n.data?['moId'];
    if (moId is String && moId.isNotEmpty) {
      unawaited(context.push('/production/orders/$moId'));
    }
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.notification, required this.onTap});
  final NotificationEntry notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _styleFor(notification.type);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BananSpacing.lg,
          vertical: BananSpacing.md,
        ),
        color: notification.isRead ? null : color.withValues(alpha: 0.06),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 20),
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
                        _relTime(notification.createdAt),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
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
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, Color) _styleFor(String type) {
    switch (type) {
      case 'mfg.qc_alert':
        return (Icons.warning_amber_outlined, BananColors.danger);
      case 'mfg.daily_digest':
        return (Icons.event_note_outlined, BananColors.warning);
      default:
        return (Icons.notifications_outlined, BananColors.info);
    }
  }

  String _relTime(DateTime created) {
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    return DateFormat('dd/MM/yyyy').format(created.toLocal());
  }
}
