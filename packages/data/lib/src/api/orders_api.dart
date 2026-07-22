import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/auth_response_dto.dart';
import '../dtos/order_dto.dart';
import '../dtos/payment_dto.dart';
import 'errors.dart';

/// Result of POST /orders — server returns the order plus provider-specific
/// payment instructions (CASH `payAtPickup`, Stripe `redirectUrl`, ...).
/// `guestSession` is present only when the backend auto-created a guest user
/// during this checkout and wants the client to store the tokens.
class PlaceOrderApiResult {
  const PlaceOrderApiResult({
    required this.order,
    required this.payment,
    this.guestSession,
  });
  final OrderDto order;
  final PaymentInstructionsDto payment;
  final AuthResponseDto? guestSession;
}

class OrdersApi {
  OrdersApi(this._dio);

  final Dio _dio;

  Future<Result<PlaceOrderApiResult, AppFailure>> place(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/orders', data: body);
      final data = res.data?['data'] as Map<String, dynamic>?;
      if ((res.statusCode != 200 && res.statusCode != 201) || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final orderJson = data['order'] as Map<String, dynamic>?;
      final paymentJson = data['payment'] as Map<String, dynamic>?;
      if (orderJson == null || paymentJson == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      final guestJson = data['guestSession'] as Map<String, dynamic>?;
      return Result.success(
        PlaceOrderApiResult(
          order: OrderDto.fromJson(orderJson),
          payment: PaymentInstructionsDto.fromJson(paymentJson),
          guestSession:
              guestJson == null ? null : AuthResponseDto.fromJson(guestJson),
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<
      Result<({List<OrderDto> items, int page, int perPage, int total}),
          AppFailure>> myOrders({
    int page = 1,
    int perPage = 20,
  }) =>
      _list('/orders', {'page': page, 'perPage': perPage});

  Future<
      Result<({List<OrderDto> items, int page, int perPage, int total}),
          AppFailure>> storeOrders({
    String? status,
    String? source,
    int page = 1,
    int perPage = 30,
  }) =>
      _list('/merchant/orders', {
        if (status != null) 'status': status,
        if (source != null) 'source': source,
        'page': page,
        'perPage': perPage,
      });

  /// Staff keys in a walk-in customer's order at the counter. Settlement is
  /// the till — no online gateway is ever involved.
  Future<Result<OrderDto, AppFailure>> createCounterOrder({
    required List<Map<String, dynamic>> items,
    required String customerName,
    required String customerPhone,
    required bool paidAtCounter,
    String? customerEmail,
    DateTime? scheduledFor,
    String? notes,
    String? storeId,
    String? clientRequestId,
  }) =>
      _postOrder('/merchant/orders/counter', {
        'items': items,
        'customerName': customerName,
        'customerPhone': customerPhone,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'customerEmail': customerEmail,
        'payment': paidAtCounter ? 'PAID_AT_COUNTER' : 'UNPAID_AT_COUNTER',
        if (scheduledFor != null)
          'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (storeId != null) 'storeId': storeId,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      });

  /// A branch requests goods from the kitchen for itself (internal transfer).
  /// [mfgItems]: kitchen-warehouse supplies {mfgProductId, qty} delivered to
  /// the branch alongside (or instead of) menu items.
  Future<Result<OrderDto, AppFailure>> createInternalTransfer({
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>>? mfgItems,
    DateTime? scheduledFor,
    String? notes,
    String? requestingStoreId,
    String? destinationStoreId,
    String? clientRequestId,
  }) =>
      _postOrder('/merchant/orders/internal-transfer', {
        'items': items,
        if (mfgItems != null && mfgItems.isNotEmpty) 'mfgItems': mfgItems,
        if (scheduledFor != null)
          'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (requestingStoreId != null) 'requestingStoreId': requestingStoreId,
        if (destinationStoreId != null)
          'destinationStoreId': destinationStoreId,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      });

  Future<Result<OrderDto, AppFailure>> markCounterPaid(String id) =>
      _postOrder('/merchant/orders/$id/counter-paid', const {});

  /// Destination branch signs for an internal transfer (→ COMPLETED).
  /// [receivedItems] reports shortages: {orderItemId, receivedQty} per line;
  /// [receivedMfgItems] the same for supply lines: {itemId, receivedQty}.
  Future<Result<OrderDto, AppFailure>> receiveTransfer(
    String id, {
    String? note,
    List<Map<String, dynamic>>? receivedItems,
    List<Map<String, dynamic>>? receivedMfgItems,
  }) =>
      _postOrder('/merchant/orders/$id/receive-transfer', {
        if (note != null && note.isNotEmpty) 'note': note,
        if (receivedItems != null && receivedItems.isNotEmpty)
          'items': receivedItems,
        if (receivedMfgItems != null && receivedMfgItems.isNotEmpty)
          'mfgItems': receivedMfgItems,
      });

  Future<Result<OrderDto, AppFailure>> get(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/orders/$id');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(OrderDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Public tracking — `/orders/:id/track` is guest-accessible (no bearer).
  Future<Result<OrderDto, AppFailure>> track(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/orders/$id/track');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(OrderDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<OrderDto, AppFailure>> cancel(String id, {String? reason}) =>
      _postOrder('/orders/$id/cancel', {if (reason != null) 'reason': reason});

  Future<Result<OrderDto, AppFailure>> transition(
    String id,
    String toStatus, {
    String? note,
  }) =>
      _postOrder('/merchant/orders/$id/transition', {
        'toStatus': toStatus,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  Future<Result<OrderDto, AppFailure>> transferToKitchen(
    String id, {
    String? kitchenId,
    String? note,
  }) =>
      _postOrder('/merchant/orders/$id/transfer-to-kitchen', {
        if (kitchenId != null) 'kitchenId': kitchenId,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  /// Merchant marks the VAT invoice as issued for [id]. Optionally attaches
  /// a public URL to the hoá đơn PDF hosted on the merchant's invoice
  /// provider — surfaced on the customer order detail.
  Future<Result<OrderDto, AppFailure>> issueInvoice(
    String id, {
    String? invoiceFileUrl,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/merchant/orders/$id/invoice',
        data: {
          if (invoiceFileUrl != null && invoiceFileUrl.isNotEmpty)
            'invoiceFileUrl': invoiceFileUrl,
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(OrderDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<List<OrderDto>, AppFailure>> kitchenQueue({
    String? kitchenStatus,
    bool includeDoneToday = false,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/kitchen/orders',
        queryParameters: {
          if (kitchenStatus != null) 'kitchenStatus': kitchenStatus,
          if (includeDoneToday) 'includeDoneToday': '1',
        },
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw.map((e) => OrderDto.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<OrderDto, AppFailure>> transitionKitchen(
    String id,
    String toKitchenStatus,
  ) =>
      _postOrder('/kitchen/orders/$id/transition', {
        'toKitchenStatus': toKitchenStatus,
      });

  Future<Result<OrderDto, AppFailure>> dispatchFromKitchen(String id) =>
      _postOrder('/kitchen/orders/$id/dispatch', const {});

  Future<Result<OrderDto, AppFailure>> _postOrder(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (res.statusCode != 200 && res.statusCode != 201) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(OrderDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<
      Result<({List<OrderDto> items, int page, int perPage, int total}),
          AppFailure>> _list(String path, Map<String, dynamic> query) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>? ?? const {};
      return Result.success(
        (
          items: raw
              .map((e) => OrderDto.fromJson(e as Map<String, dynamic>))
              .toList(),
          page: (meta['page'] as num?)?.toInt() ?? 1,
          perPage: (meta['perPage'] as num?)?.toInt() ?? raw.length,
          total: (meta['total'] as num?)?.toInt() ?? raw.length,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
