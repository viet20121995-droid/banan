import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'notifications_controller.dart';

/// Bell with the unread badge and a drop-down of the latest notifications.
/// Tapping one marks it read and hands it to [onOpen] (deep link); the
/// footer opens the full inbox via [onOpenAll] when the app has one.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({
    required this.onOpen,
    super.key,
    this.onOpenAll,
    this.color,
    this.backgroundColor,
  });

  final void Function(NotificationEntry) onOpen;
  final VoidCallback? onOpenAll;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      notificationsControllerProvider.select((s) => s.unread),
    );
    final button = IconButton(
      tooltip: unread > 0 ? '$unread thông báo chưa đọc' : 'Thông báo',
      icon: Icon(
        unread > 0 ? Icons.notifications_active : Icons.notifications_none,
      ),
      color: color,
      style: backgroundColor == null
          ? null
          : IconButton.styleFrom(
              backgroundColor: backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
      onPressed: () => _openPanel(context, ref),
    );
    if (unread == 0) return button;
    return Badge.count(
      count: unread,
      offset: const Offset(-6, 4),
      child: button,
    );
  }

  Future<void> _openPanel(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    // Below the bell, right-aligned to it; on a phone the menu clamps itself.
    final position = RelativeRect.fromLTRB(
      origin.dx + box.size.width - 360,
      origin.dy + box.size.height + 4,
      overlay.size.width - origin.dx - box.size.width,
      0,
    );
    final picked = await showMenu<_PanelAction>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
      items: [
        PopupMenuItem<_PanelAction>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _Panel(onOpenAll: onOpenAll),
        ),
      ],
    );
    if (!context.mounted || picked == null) return;
    switch (picked) {
      case _OpenEntry(:final entry):
        await ref.read(notificationsControllerProvider.notifier).markRead(
              entry.id,
            );
        onOpen(entry);
      case _OpenAll():
        onOpenAll?.call();
      case _ReadAll():
        await ref.read(notificationsControllerProvider.notifier).markAllRead();
    }
  }
}

sealed class _PanelAction {
  const _PanelAction();
}

class _OpenEntry extends _PanelAction {
  const _OpenEntry(this.entry);
  final NotificationEntry entry;
}

class _OpenAll extends _PanelAction {
  const _OpenAll();
}

class _ReadAll extends _PanelAction {
  const _ReadAll();
}

class _Panel extends ConsumerWidget {
  const _Panel({this.onOpenAll});
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(notificationsControllerProvider);
    final items = state.items.take(10).toList();
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.unread > 0
                        ? 'Thông báo · ${state.unread} chưa đọc'
                        : 'Thông báo',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (state.unread > 0)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const _ReadAll()),
                    child: const Text('Đọc tất cả'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                state.loading ? 'Đang tải…' : 'Chưa có thông báo nào.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final n in items)
                    ListTile(
                      dense: true,
                      tileColor: n.isRead
                          ? null
                          : theme.colorScheme.primary.withValues(alpha: 0.06),
                      leading: Icon(
                        _iconFor(n.type),
                        size: 20,
                        color: n.isRead
                            ? theme.colorScheme.outline
                            : theme.colorScheme.primary,
                      ),
                      title: Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              n.isRead ? FontWeight.w400 : FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${n.body} · ${_relTime(n.createdAt)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(_OpenEntry(n)),
                    ),
                ],
              ),
            ),
          if (onOpenAll != null) ...[
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(const _OpenAll()),
              child: const Text('Xem tất cả'),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
        'order_new' || 'kitchen_new' => Icons.receipt_long_outlined,
        'order.status_changed' => Icons.local_shipping_outlined,
        'mfg.qc_alert' => Icons.warning_amber_outlined,
        'mfg.daily_digest' => Icons.event_note_outlined,
        _ => Icons.notifications_outlined,
      };

  static String _relTime(DateTime created) {
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    return DateFormat('dd/MM/yyyy').format(created.toLocal());
  }
}
