import 'package:banan_core/banan_core.dart';

import '../entities/notification_entry.dart';

abstract class NotificationsRepository {
  /// [types] scopes the inbox and its unread count to the notification
  /// types the calling app shows; null = everything.
  Future<Result<NotificationsPage, AppFailure>> list({
    int page = 1,
    int perPage = 30,
    List<String>? types,
  });

  Future<Result<void, AppFailure>> markRead(List<String> ids);
  Future<Result<void, AppFailure>> markAllRead();
}
