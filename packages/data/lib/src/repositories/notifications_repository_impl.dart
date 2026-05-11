import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/notifications_api.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._api);
  final NotificationsApi _api;

  @override
  Future<Result<NotificationsPage, AppFailure>> list({
    int page = 1,
    int perPage = 30,
  }) async {
    final res = await _api.list(page: page, perPage: perPage);
    return res.map(
      (data) => NotificationsPage(
        items: data.items.map((d) => d.toDomain()).toList(),
        unread: data.unread,
        total: data.total,
      ),
    );
  }

  @override
  Future<Result<void, AppFailure>> markRead(List<String> ids) =>
      _api.markRead(ids);

  @override
  Future<Result<void, AppFailure>> markAllRead() => _api.markAllRead();
}
