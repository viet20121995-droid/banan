import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class KanbanState {
  const KanbanState({
    this.orders = const [],
    this.loading = false,
    this.failure,
  });

  final List<Order> orders;
  final bool loading;
  final AppFailure? failure;

  /// Group orders by their current `kitchenStatus` for column rendering.
  Map<KitchenStatus, List<Order>> get byColumn {
    final map = <KitchenStatus, List<Order>>{
      for (final c in KitchenStatus.orderedColumns) c: [],
    };
    for (final o in orders) {
      final s = o.kitchenStatus;
      if (s != null) map[s]!.add(o);
    }
    return map;
  }

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
    final res = await _repo.kitchenQueue();
    res.when(
      success: (list) =>
          state = state.copyWith(orders: list, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

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
        controller.refresh();
      }
    });
  });
  return controller;
});
