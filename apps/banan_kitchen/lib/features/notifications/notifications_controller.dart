import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-app notification inbox for the kitchen app. Portable copy of the customer
/// app's controller — same shared data layer (NotificationsRepository + realtime
/// feed), just hosted in this app so the "Sản xuất" notifications surface here.
@immutable
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.unread = 0,
    this.loading = false,
    this.failure,
  });

  final List<NotificationEntry> items;
  final int unread;
  final bool loading;
  final AppFailure? failure;

  NotificationsState copyWith({
    List<NotificationEntry>? items,
    int? unread,
    bool? loading,
    Object? failure = _sentinel,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        unread: unread ?? this.unread,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
      );
}

const _sentinel = Object();

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._repo) : super(const NotificationsState()) {
    refresh();
  }

  final NotificationsRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.list();
    res.when(
      success: (page) => state = state.copyWith(
        items: page.items,
        unread: page.unread,
        loading: false,
      ),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  /// Optimistic prepend on realtime push — reconciles with the next refresh.
  void prepend(NotificationEntry n) {
    state = state.copyWith(
      items: [n, ...state.items],
      unread: state.unread + 1,
    );
  }

  Future<void> markRead(String id) async {
    state = state.copyWith(
      items: [
        for (final n in state.items)
          if (n.id == id && !n.isRead) n.markRead() else n,
      ],
      unread: (state.unread > 0 && state.items.any((n) => n.id == id && !n.isRead))
          ? state.unread - 1
          : state.unread,
    );
    await _repo.markRead([id]);
  }

  Future<void> markAllRead() async {
    state = state.copyWith(
      items: [for (final n in state.items) n.markRead()],
      unread: 0,
    );
    await _repo.markAllRead();
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  final controller =
      NotificationsController(ref.watch(notificationsRepositoryProvider));

  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (event.event != 'notification.new') return;
      final json = event.data['notification'];
      if (json is! Map) return;
      final cast = Map<String, dynamic>.from(json);
      controller.prepend(
        NotificationEntry(
          id: cast['id'] as String,
          type: cast['type'] as String,
          title: cast['title'] as String,
          body: cast['body'] as String,
          data: cast['data'] is Map
              ? Map<String, dynamic>.from(cast['data'] as Map)
              : null,
          createdAt: DateTime.parse(cast['createdAt'] as String),
        ),
      );
    });
  });

  return controller;
});
