import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/order_dto.dart';
import 'errors.dart';

double _num(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

/// One orderable line of a wholesale contract, priced.
class WholesaleCatalogLine {
  const WholesaleCatalogLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.retailPrice,
    required this.contractPrice,
    required this.minQty,
    this.variantId,
    this.variantLabel,
    this.leadTimeHours,
    this.multipleQty = 1,
    this.deliveryDays = const [],
    this.leadTimeDays,
  });

  factory WholesaleCatalogLine.fromJson(Map<String, dynamic> j) =>
      WholesaleCatalogLine(
        id: j['id'] as String,
        productId: j['productId'] as String,
        productName: j['productName'] as String? ?? '',
        variantId: j['variantId'] as String?,
        variantLabel: j['variantLabel'] as String?,
        retailPrice: _num(j['retailPrice']),
        contractPrice: _num(j['contractPrice']),
        minQty: (j['minQty'] as num?)?.toInt() ?? 1,
        leadTimeHours: (j['leadTimeHours'] as num?)?.toInt(),
        multipleQty: (j['multipleQty'] as num?)?.toInt() ?? 1,
        deliveryDays: ((j['deliveryDays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        leadTimeDays: (j['leadTimeDays'] as num?)?.toInt(),
      );

  final String id;
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantLabel;
  final double retailPrice;
  final double contractPrice;
  final int minQty;
  final int? leadTimeHours;

  /// Order quantity must be a multiple of this. 1 = any quantity.
  final int multipleQty;

  /// ISO weekdays (1 = Thứ 2 … 7 = CN) this item ships. Empty = any day.
  final List<int> deliveryDays;

  /// Must be ordered at least this many days before the delivery date.
  final int? leadTimeDays;
}

class WholesaleContractView {
  const WholesaleContractView({
    required this.id,
    required this.name,
    required this.lines,
    this.minOrderVnd,
    this.endsAt,
    this.nextDayCutoffMinutes,
    this.noDeliveryDays = const [],
    this.shipFeeVnd = 0,
  });

  factory WholesaleContractView.fromJson(Map<String, dynamic> j) =>
      WholesaleContractView(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        minOrderVnd: (j['minOrderVnd'] as num?)?.toInt(),
        endsAt: DateTime.tryParse('${j['endsAt']}'),
        nextDayCutoffMinutes: (j['nextDayCutoffMinutes'] as num?)?.toInt(),
        noDeliveryDays: ((j['noDeliveryDays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        shipFeeVnd: (j['shipFeeVnd'] as num?)?.toInt() ?? 0,
        lines: ((j['lines'] as List?) ?? const [])
            .map(
              (e) => WholesaleCatalogLine.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );

  final String id;
  final String name;
  final int? minOrderVnd;
  final DateTime? endsAt;

  /// Order before this minute-of-day (VN time) → next-day delivery possible.
  final int? nextDayCutoffMinutes;

  /// ISO weekdays (1 = Thứ 2 … 7 = CN) with no delivery.
  final List<int> noDeliveryDays;

  /// Per-order ship fee (₫). 0 = freeship.
  final int shipFeeVnd;
  final List<WholesaleCatalogLine> lines;

  /// Any rule that makes picking a delivery date mandatory.
  bool get requiresDeliveryDate =>
      nextDayCutoffMinutes != null ||
      noDeliveryDays.isNotEmpty ||
      lines.any(
        (l) => l.deliveryDays.isNotEmpty || (l.leadTimeDays ?? 0) > 0,
      );
}

class WholesaleReceivableView {
  const WholesaleReceivableView({
    required this.id,
    required this.amountVnd,
    required this.dueDate,
    required this.status,
    this.orderCode,
    this.companyName,
    this.paidAt,
  });

  factory WholesaleReceivableView.fromJson(Map<String, dynamic> j) =>
      WholesaleReceivableView(
        id: j['id'] as String,
        amountVnd: _num(j['amountVnd']),
        dueDate: j['dueDate'] == null
            ? null
            : DateTime.parse(j['dueDate'] as String),
        status: j['status'] as String? ?? 'OPEN',
        orderCode: (j['order'] as Map?)?['code'] as String?,
        companyName: (j['account'] as Map?)?['companyName'] as String?,
        paidAt: DateTime.tryParse('${j['paidAt']}'),
      );

  final String id;
  final double amountVnd;
  final DateTime? dueDate;
  final String status; // PENDING | OPEN | PARTIAL | PAID | OVERDUE | CANCELLED
  final String? orderCode;
  final String? companyName;
  final DateTime? paidAt;

  bool get isOpen =>
      status == 'OPEN' || status == 'PARTIAL' || status == 'OVERDUE';
  bool get isOverdue =>
      isOpen && dueDate != null && dueDate!.isBefore(DateTime.now());
}

class WholesaleAccountView {
  const WholesaleAccountView({
    required this.id,
    required this.companyName,
    required this.active,
    required this.creditLimitVnd,
    required this.paymentTermDays,
    this.userEmail,
    this.userPhone,
    this.contactName,
    this.deliveryAddress,
    this.blockedReason,
    this.contractCount = 0,
    this.orderCount = 0,
  });

  factory WholesaleAccountView.fromJson(Map<String, dynamic> j) =>
      WholesaleAccountView(
        id: j['id'] as String,
        companyName: j['companyName'] as String? ?? '',
        active: j['active'] as bool? ?? true,
        creditLimitVnd: (j['creditLimitVnd'] as num?)?.toInt() ?? 0,
        paymentTermDays: (j['paymentTermDays'] as num?)?.toInt() ?? 30,
        userEmail: (j['user'] as Map?)?['email'] as String?,
        userPhone: (j['user'] as Map?)?['phone'] as String?,
        contactName: j['contactName'] as String?,
        deliveryAddress: j['deliveryAddress'] as String?,
        blockedReason: j['blockedReason'] as String?,
        contractCount:
            ((j['_count'] as Map?)?['contracts'] as num?)?.toInt() ?? 0,
        orderCount: ((j['_count'] as Map?)?['orders'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String companyName;
  final bool active;
  final int creditLimitVnd;
  final int paymentTermDays;
  final String? userEmail;
  final String? userPhone;
  final String? contactName;
  final String? deliveryAddress;
  final String? blockedReason;
  final int contractCount;
  final int orderCount;
}

/// Wholesale (B2B on-account) API — customer-side (`/wholesale/*`) and
/// admin-side (`/admin/wholesale/*`).
class WholesaleApi {
  WholesaleApi(this._dio);

  final Dio _dio;

  // ── customer (wholesale buyer) ──
  Future<Result<bool, AppFailure>> access() async {
    final result = await _getRaw('/wholesale/access');
    return result.when(
      success: (data) => Result.success(data['enabled'] as bool? ?? false),
      failure: Result.failure,
    );
  }

  Future<Result<List<WholesaleContractView>, AppFailure>> catalog() =>
      _getList('/wholesale/catalog', WholesaleContractView.fromJson);

  Future<Result<OrderDto, AppFailure>> createOrder({
    required String contractId,
    required List<Map<String, dynamic>> items,
    DateTime? scheduledFor,
    String? notes,
    String? poCode,
    String? clientRequestId,
  }) =>
      _post('/wholesale/orders', {
        'contractId': contractId,
        'items': items,
        if (scheduledFor != null)
          'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (poCode != null && poCode.isNotEmpty) 'poCode': poCode,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      });

  Future<Result<List<OrderDto>, AppFailure>> myOrders() =>
      _getList('/wholesale/orders', OrderDto.fromJson);

  Future<Result<List<WholesaleReceivableView>, AppFailure>> myReceivables() =>
      _getList('/wholesale/receivables', WholesaleReceivableView.fromJson);

  // ── admin ──
  Future<Result<List<WholesaleAccountView>, AppFailure>> adminAccounts() =>
      _getList('/admin/wholesale/accounts', WholesaleAccountView.fromJson);

  Future<Result<Map<String, dynamic>, AppFailure>> adminAccount(String id) =>
      _getRaw('/admin/wholesale/accounts/$id');

  Future<Result<Map<String, dynamic>, AppFailure>> adminCreateAccount(
    Map<String, dynamic> body,
  ) =>
      _postRaw('/admin/wholesale/accounts', body);

  Future<Result<Map<String, dynamic>, AppFailure>> adminUpdateAccount(
    String id,
    Map<String, dynamic> body,
  ) =>
      _patchRaw('/admin/wholesale/accounts/$id', body);

  Future<Result<Map<String, dynamic>, AppFailure>> adminCreateContract(
    Map<String, dynamic> body,
  ) =>
      _postRaw('/admin/wholesale/contracts', body);

  Future<Result<Map<String, dynamic>, AppFailure>> adminUpdateContract(
    String id,
    Map<String, dynamic> body,
  ) =>
      _patchRaw('/admin/wholesale/contracts/$id', body);

  Future<Result<Map<String, dynamic>, AppFailure>> adminAddLine(
    String contractId,
    Map<String, dynamic> body,
  ) =>
      _postRaw('/admin/wholesale/contracts/$contractId/lines', body);

  Future<Result<Map<String, dynamic>, AppFailure>> adminUpdateLine(
    String contractId,
    String lineId,
    Map<String, dynamic> body,
  ) =>
      _patchRaw('/admin/wholesale/contracts/$contractId/lines/$lineId', body);

  Future<Result<List<OrderDto>, AppFailure>> adminOrders({String? status}) =>
      _getList(
        '/admin/wholesale/orders',
        OrderDto.fromJson,
        query: {if (status != null) 'status': status},
      );

  Future<Result<OrderDto, AppFailure>> adminConfirmOrder(String id) =>
      _post('/admin/wholesale/orders/$id/confirm', const {});

  Future<Result<OrderDto, AppFailure>> adminRejectOrder(
    String id, {
    String? reason,
  }) =>
      _post('/admin/wholesale/orders/$id/reject', {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

  Future<Result<List<WholesaleReceivableView>, AppFailure>> adminReceivables({
    String? status,
  }) =>
      _getList(
        '/admin/wholesale/receivables',
        WholesaleReceivableView.fromJson,
        query: {if (status != null) 'status': status},
      );

  Future<Result<Map<String, dynamic>, AppFailure>> adminMarkPaid(String id) =>
      _postRaw('/admin/wholesale/receivables/$id/mark-paid', const {});

  /// Record ONE collection (possibly partial) with method/reference/note.
  Future<Result<Map<String, dynamic>, AppFailure>> adminRecordPayment(
    String id, {
    int? amountVnd,
    String? method,
    String? reference,
    String? note,
    String? clientRequestId,
  }) =>
      _postRaw('/admin/wholesale/receivables/$id/payments', {
        if (amountVnd != null) 'amountVnd': amountVnd,
        if (method != null) 'method': method,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (note != null && note.isNotEmpty) 'note': note,
        if (clientRequestId != null) 'clientRequestId': clientRequestId,
      });

  // ── plumbing ──
  Future<Result<List<T>, AppFailure>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw.map((e) => fromJson((e as Map).cast<String, dynamic>())).toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<OrderDto, AppFailure>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = res.data?['data'] as Map<String, dynamic>?;
      if ((res.statusCode != 200 && res.statusCode != 201) || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(OrderDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Map<String, dynamic>, AppFailure>> _getRaw(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (!isOk(res) || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Map<String, dynamic>, AppFailure>> _postRaw(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = res.data?['data'] as Map<String, dynamic>?;
      if ((res.statusCode != 200 && res.statusCode != 201) || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Map<String, dynamic>, AppFailure>> _patchRaw(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(path, data: body);
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (!isOk(res) || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
