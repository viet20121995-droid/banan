import 'package:equatable/equatable.dart';

/// In-app notification — drives the inbox + (later) FCM push payload.
class NotificationEntry extends Equatable {
  const NotificationEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  /// Pulls a deep-link target from the payload — currently only orders.
  String? get deepLinkPath {
    final orderId = data?['orderId'];
    if (orderId is String && orderId.isNotEmpty) return '/orders/$orderId';
    return null;
  }

  NotificationEntry markRead() => NotificationEntry(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        data: data,
        readAt: readAt ?? DateTime.now(),
      );

  @override
  List<Object?> get props =>
      [id, type, title, body, data, readAt, createdAt];
}

class NotificationsPage extends Equatable {
  const NotificationsPage({
    required this.items,
    required this.unread,
    required this.total,
  });

  final List<NotificationEntry> items;
  final int unread;
  final int total;

  @override
  List<Object?> get props => [items, unread, total];
}
