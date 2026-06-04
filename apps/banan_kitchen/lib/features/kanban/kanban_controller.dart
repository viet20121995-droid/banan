import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alert_sound.dart';

@immutable
class KanbanState {
  const KanbanState({
    this.orders = const [],
    this.loading = false,
    this.failure,
  });

  /// Both active-in-kitchen orders AND today's dispatched orders mixed in.
  /// Use [activeByColumn] for the 3 kitchen-owned columns and [completedToday]
  /// for the "Completed" column.
  final List<Order> orders;
  final bool loading;
  final AppFailure? failure;

  /// Group active kitchen orders by their `kitchenStatus`.
  Map<KitchenStatus, List<Order>> get activeByColumn {
    final map = <KitchenStatus, List<Order>>{
      for (final c in KitchenStatus.orderedColumns) c: [],
    };
    for (final o in orders) {
      if (o.status != OrderStatus.sentToKitchen) continue;
      final s = o.kitchenStatus;
      if (s != null && map.containsKey(s)) map[s]!.add(o);
    }
    return map;
  }

  /// Orders this kitchen dispatched today — no longer SENT_TO_KITCHEN.
  List<Order> get completedToday => orders
      .where((o) => o.status != OrderStatus.sentToKitchen)
      .toList();

  KanbanState copyWith({
    List<Order>? orders,
    bool? loading,
    Object? failure = _sentinel,
  }) =>
      KanbanState(
        orders: orders ?? this.orders,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
      );
}

const _sentinel = Object();

class KanbanController extends StateNotifier<KanbanState> {
  KanbanController(this._repo) : super(const KanbanState()) {
    refresh();
  }

  final OrderRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.kitchenQueue(includeDoneToday: true);
    res.when(
      success: (list) =>
          state = state.copyWith(orders: list, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  /// Accept an incoming order (PENDING_ACK → PREPARING).
  Future<bool> accept(String orderId) =>
      advance(orderId, KitchenStatus.preparing);

  /// Mark order as ready for dispatch (PREPARING → READY_DISPATCH).
  Future<bool> markReady(String orderId) =>
      advance(orderId, KitchenStatus.readyDispatch);

  Future<bool> advance(String orderId, KitchenStatus next) async {
    final res = await _repo.transitionKitchen(orderId, next);
    return res.when(
      success: (_) async {
        await refresh();
        return true;
      },
      failure: (_) => false,
    );
  }

  Future<bool> dispatch(String orderId) async {
    final res = await _repo.dispatchFromKitchen(orderId);
    return res.when(
      success: (_) async {
        await refresh();
        return true;
      },
      failure: (_) => false,
    );
  }
}

final kanbanControllerProvider =
    StateNotifierProvider.autoDispose<KanbanController, KanbanState>((ref) {
  final controller = KanbanController(ref.watch(orderRepositoryProvider));
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (event.event == 'order.status_changed' ||
          event.event == 'order.kitchen_status_changed') {
        // A fresh order just landed in this kitchen → audible chime.
        if (event.data['toStatus'] == 'SENT_TO_KITCHEN') {
          playNewTicketChime();
        }
        controller.refresh();
      }
    });
  });
  return controller;
});
