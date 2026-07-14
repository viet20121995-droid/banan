import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/orders_api.dart';
import '../dtos/order_dto.dart';

/// Converts order DTOs to domain, SKIPPING any single order that fails to parse
/// (e.g. one carrying a brand-new enum value an older client build can't decode
/// yet). One un-mappable order must never blank the whole list / kitchen queue —
/// that was the failure mode behind the merchant orders spinner.
List<Order> _safeOrders(List<OrderDto> dtos) {
  final out = <Order>[];
  for (final d in dtos) {
    try {
      out.add(d.toDomain());
    } catch (_) {
      // Drop the un-parseable order rather than failing the entire list.
    }
  }
  return out;
}

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._api);
  final OrdersApi _api;

  @override
  Future<Result<PlaceOrderResult, AppFailure>> placeOrder(NewOrder draft) async {
    final res = await _api.place(draft.toJson());
    return res.map(
      (apiResult) => PlaceOrderResult(
        order: apiResult.order.toDomain(),
        payment: apiResult.payment.toDomain(),
        guestSession: apiResult.guestSession?.toDomain(),
      ),
    );
  }

  @override
  Future<Result<OrderPage, AppFailure>> myOrders({
    int page = 1,
    int perPage = 20,
  }) async {
    final res = await _api.myOrders(page: page, perPage: perPage);
    return res.map(
      (data) => OrderPage(
        items: _safeOrders(data.items),
        page: data.page,
        perPage: data.perPage,
        total: data.total,
      ),
    );
  }

  @override
  Future<Result<Order, AppFailure>> order(String id) async {
    final res = await _api.get(id);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Order, AppFailure>> tracking(String id) async {
    final res = await _api.track(id);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Order, AppFailure>> cancel(String id, {String? reason}) async {
    final res = await _api.cancel(id, reason: reason);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<OrderPage, AppFailure>> storeOrders({
    OrderStatus? status,
    int page = 1,
    int perPage = 30,
  }) async {
    final res = await _api.storeOrders(
      status: status?.wire,
      page: page,
      perPage: perPage,
    );
    return res.map(
      (data) => OrderPage(
        items: _safeOrders(data.items),
        page: data.page,
        perPage: data.perPage,
        total: data.total,
      ),
    );
  }

  @override
  Future<Result<Order, AppFailure>> transition(
    String id,
    OrderStatus toStatus, {
    String? note,
  }) async {
    final res = await _api.transition(id, toStatus.wire, note: note);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Order, AppFailure>> transferToKitchen(
    String id, {
    String? kitchenId,
    String? note,
  }) async {
    final res = await _api.transferToKitchen(id, kitchenId: kitchenId, note: note);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Order, AppFailure>> issueInvoice(
    String id, {
    String? invoiceFileUrl,
  }) async {
    final res = await _api.issueInvoice(id, invoiceFileUrl: invoiceFileUrl);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<List<Order>, AppFailure>> kitchenQueue({
    KitchenStatus? status,
    bool includeDoneToday = false,
  }) async {
    final res = await _api.kitchenQueue(
      kitchenStatus: status?.wire,
      includeDoneToday: includeDoneToday,
    );
    return res.map(_safeOrders);
  }

  @override
  Future<Result<Order, AppFailure>> transitionKitchen(
    String id,
    KitchenStatus toKitchenStatus,
  ) async {
    final res = await _api.transitionKitchen(id, toKitchenStatus.wire);
    return res.map((d) => d.toDomain());
  }

  @override
  Future<Result<Order, AppFailure>> dispatchFromKitchen(String id) async {
    final res = await _api.dispatchFromKitchen(id);
    return res.map((d) => d.toDomain());
  }
}
