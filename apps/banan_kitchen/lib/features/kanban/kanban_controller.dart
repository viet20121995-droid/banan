import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kitchen_alerts.dart';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

@immutable
class KanbanState {
  KanbanState({
    this.orders = const [],
    this.loading = false,
    this.failure,
    DateTime? from,
    DateTime? to,
  })  : from = from ?? _today(),
        to = to ?? from ?? _today();

  /// The board for [from]…[to] (inclusive calendar days), keyed on the day
  /// each order has to be READY: orders scheduled in the range, walk-ins
  /// placed in it, orders dispatched in it — and, when the range covers
  /// today, live work that is overdue or unscheduled. Use [activeByColumn]
  /// for the 3 kitchen-owned stages and [done] for the dispatched ones.
  final List<Order> orders;
  final bool loading;
  final AppFailure? failure;

  /// Calendar-day range the board shows — today → today on sign-in.
  final DateTime from;
  final DateTime to;

  bool get isToday => from == _today() && to == from;
  bool get isSingleDay => from == to;

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

  /// Orders this kitchen already dispatched — no longer SENT_TO_KITCHEN.
  List<Order> get done =>
      orders.where((o) => o.status != OrderStatus.sentToKitchen).toList();

  KanbanState copyWith({
    List<Order>? orders,
    bool? loading,
    Object? failure = _sentinel,
    DateTime? from,
    DateTime? to,
  }) =>
      KanbanState(
        orders: orders ?? this.orders,
        loading: loading ?? this.loading,
        failure: failure == _sentinel ? this.failure : failure as AppFailure?,
        from: from ?? this.from,
        to: to ?? this.to,
      );
}

const _sentinel = Object();

class KanbanController extends StateNotifier<KanbanState> {
  KanbanController(this._repo) : super(KanbanState()) {
    refresh();
  }

  final OrderRepository _repo;

  Future<void> refresh() async {
    final from = state.from;
    final to = state.to;
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.kitchenQueue(includeDoneToday: true, from: from, to: to);
    // A range switch may have raced this fetch — never paint another
    // range's orders under the current one.
    if (state.from != from || state.to != to) return;
    res.when(
      success: (list) =>
          state = state.copyWith(orders: list, loading: false),
      failure: (f) => state = state.copyWith(loading: false, failure: f),
    );
  }

  /// Show another calendar-day range (past, or scheduled ahead). A single
  /// day is `from == to`; `to` before `from` is swapped, never rejected.
  Future<void> setRange(DateTime from, DateTime to) {
    var a = _dayOf(from);
    var b = _dayOf(to);
    if (b.isBefore(a)) {
      final t = a;
      a = b;
      b = t;
    }
    state = state.copyWith(from: a, to: b, orders: const []);
    return refresh();
  }

  Future<void> setDay(DateTime day) => setRange(day, day);

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
  // The chime lives in kitchenAlertsProvider (app-wide); here only refetch —
  // including counter / internal-transfer orders that arrive as
  // `order.created` already on the board.
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (isKitchenBoardEvent(event)) controller.refresh();
    });
  });
  return controller;
});
