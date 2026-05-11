import 'package:banan_core/banan_core.dart';

import '../entities/notification_entry.dart';

abstract class NotificationsRepository {
  Future<Result<NotificationsPage, AppFailure>> list({
    int page = 1,
    int perPage = 30,
  });

  Future<Result<void, AppFailure>> markRead(List<String> ids);
  Future<Result<void, AppFailure>> markAllRead();
}
