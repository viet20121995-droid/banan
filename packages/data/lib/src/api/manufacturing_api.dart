import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// Kitchen MES — the "Sản xuất" API. Backend module: /manufacturing/*.
/// Prisma serialises Decimal as a JSON string, so quantities and costs arrive
/// as strings; [_num] parses them defensively.
double _num(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

// ── DTOs ────────────────────────────────────────────────────────────────────

class MfgProduct {
  const MfgProduct({
    required this.id,
    required this.code,
    required this.nameVi,
    required this.type,
    required this.uomCode,
    required this.avgCost,
  });

  factory MfgProduct.fromJson(Map<String, dynamic> j) => MfgProduct(
        id: j['id'] as String,
        code: j['code'] as String,
        nameVi: j['nameVi'] as String,
        type: j['type'] as String,
        uomCode: (j['uom'] as Map?)?['code'] as String? ?? '',
        avgCost: _num(j['avgCost']),
      );

  final String id;
  final String code;
  final String nameVi;
  final String type; // RAW | SEMI | FINISHED | PACKAGING
  final String uomCode;
  final double avgCost;
}

class MfgBomSummary {
  const MfgBomSummary({
    required this.id,
    required this.productNameVi,
    required this.productCode,
    required this.outputQty,
    required this.uomCode,
    required this.lineCount,
    required this.opCount,
  });

  factory MfgBomSummary.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>? ?? const {};
    final count = j['_count'] as Map<String, dynamic>? ?? const {};
    return MfgBomSummary(
      id: j['id'] as String,
      productNameVi: product['nameVi'] as String? ?? '',
      productCode: product['code'] as String? ?? '',
      outputQty: _num(j['outputQty']),
      uomCode: (j['uom'] as Map?)?['code'] as String? ?? '',
      lineCount: (count['lines'] as num?)?.toInt() ?? 0,
      opCount: (count['operations'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String productNameVi;
  final String productCode;
  final double outputQty;
  final String uomCode;
  final int lineCount;
  final int opCount;
}

class MfgCost {
  const MfgCost({
    required this.materialCost,
    required this.operationCost,
    required this.total,
  });

  factory MfgCost.fromJson(Map<String, dynamic> j) => MfgCost(
        materialCost: _num(j['materialCost']),
        operationCost: _num(j['operationCost']),
        total: _num(j['total']),
      );

  final double materialCost;
  final double operationCost;
  final double total;
}

class MfgComponent {
  const MfgComponent({
    required this.id,
    required this.productNameVi,
    required this.productCode,
    required this.qtyToConsume,
    required this.qtyConsumed,
    required this.availability,
  });

  factory MfgComponent.fromJson(Map<String, dynamic> j) {
    final p = j['product'] as Map<String, dynamic>? ?? const {};
    return MfgComponent(
      id: j['id'] as String,
      productNameVi: p['nameVi'] as String? ?? '',
      productCode: p['code'] as String? ?? '',
      qtyToConsume: _num(j['qtyToConsume']),
      qtyConsumed: _num(j['qtyConsumed']),
      availability: j['availability'] as String? ?? 'NOT_AVAILABLE',
    );
  }

  final String id;
  final String productNameVi;
  final String productCode;
  final double qtyToConsume;
  final double qtyConsumed;
  final String availability; // AVAILABLE | NOT_AVAILABLE
  bool get isAvailable => availability == 'AVAILABLE';
}

class MfgOrderSummary {
  const MfgOrderSummary({
    required this.id,
    required this.code,
    required this.productNameVi,
    required this.qtyToProduce,
    required this.state,
    required this.componentCount,
  });

  factory MfgOrderSummary.fromJson(Map<String, dynamic> j) => MfgOrderSummary(
        id: j['id'] as String,
        code: j['code'] as String,
        productNameVi: (j['product'] as Map?)?['nameVi'] as String? ?? '',
        qtyToProduce: _num(j['qtyToProduce']),
        state: j['state'] as String,
        componentCount: (j['components'] as List?)?.length ?? 0,
      );

  final String id;
  final String code;
  final String productNameVi;
  final double qtyToProduce;
  final String state; // DRAFT | CONFIRMED | PROGRESS | DONE | CANCEL
  final int componentCount;
}

class MfgOrderDetail {
  const MfgOrderDetail({
    required this.id,
    required this.code,
    required this.productNameVi,
    required this.uomCode,
    required this.qtyToProduce,
    required this.qtyProduced,
    required this.state,
    required this.totalCost,
    required this.components,
    required this.lotName,
  });

  factory MfgOrderDetail.fromJson(Map<String, dynamic> j) => MfgOrderDetail(
        id: j['id'] as String,
        code: j['code'] as String,
        productNameVi: (j['product'] as Map?)?['nameVi'] as String? ?? '',
        uomCode: (j['product'] as Map?)?['uom']?['code'] as String? ?? '',
        qtyToProduce: _num(j['qtyToProduce']),
        qtyProduced: _num(j['qtyProduced']),
        state: j['state'] as String,
        totalCost: _num(j['totalCost']),
        lotName: (j['lot'] as Map?)?['name'] as String?,
        components: ((j['components'] as List?) ?? const [])
            .map((e) => MfgComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String code;
  final String productNameVi;
  final String uomCode;
  final double qtyToProduce;
  final double qtyProduced;
  final String state;
  final double totalCost;
  final String? lotName;
  final List<MfgComponent> components;
}

class MfgOnHand {
  const MfgOnHand({
    required this.productNameVi,
    required this.productCode,
    required this.lotName,
    required this.locationCode,
    required this.quantity,
    required this.uomCode,
  });

  factory MfgOnHand.fromJson(Map<String, dynamic> j) => MfgOnHand(
        productNameVi: (j['product'] as Map?)?['nameVi'] as String? ?? '',
        productCode: (j['product'] as Map?)?['code'] as String? ?? '',
        uomCode: (j['product'] as Map?)?['uomId'] as String? ?? '',
        lotName: (j['lot'] as Map?)?['name'] as String?,
        locationCode: (j['location'] as Map?)?['code'] as String? ?? '',
        quantity: _num(j['quantity']),
      );

  final String productNameVi;
  final String productCode;
  final String? lotName;
  final String locationCode;
  final double quantity;
  final String uomCode;
}

class MfgExpiringLot {
  const MfgExpiringLot({
    required this.id,
    required this.name,
    required this.productNameVi,
    required this.expiryDate,
  });

  factory MfgExpiringLot.fromJson(Map<String, dynamic> j) => MfgExpiringLot(
        id: j['id'] as String,
        name: j['name'] as String,
        productNameVi: (j['product'] as Map?)?['nameVi'] as String? ?? '',
        expiryDate: DateTime.tryParse('${j['expiryDate']}'),
      );

  final String id;
  final String name;
  final String productNameVi;
  final DateTime? expiryDate;
}

class MfgStateCount {
  const MfgStateCount({required this.state, required this.count});
  factory MfgStateCount.fromJson(Map<String, dynamic> j) =>
      MfgStateCount(state: j['state'] as String, count: (j['count'] as num).toInt());
  final String state;
  final int count;
}

class MfgQualityPointLite {
  const MfgQualityPointLite({
    required this.id,
    required this.titleVi,
    required this.testType,
    required this.normMin,
    required this.normMax,
    required this.unit,
    required this.latestResult,
  });

  factory MfgQualityPointLite.fromJson(
    Map<String, dynamic> j, {
    String? latestResult,
  }) =>
      MfgQualityPointLite(
        id: j['id'] as String,
        titleVi: j['titleVi'] as String,
        testType: j['testType'] as String,
        normMin: _num(j['normMin']),
        normMax: _num(j['normMax']),
        unit: j['unit'] as String?,
        latestResult: latestResult,
      );

  final String id;
  final String titleVi;
  final String testType; // MEASURE | PASS_FAIL
  final double normMin;
  final double normMax;
  final String? unit;
  final String? latestResult; // null | PASS | FAIL
  bool get isMeasure => testType == 'MEASURE';
}

class MfgWorkOrderCard {
  const MfgWorkOrderCard({
    required this.id,
    required this.sequence,
    required this.state,
    required this.moCode,
    required this.productNameVi,
    required this.operationNameVi,
    required this.workCenterId,
    required this.workCenterNameVi,
    required this.qualityPoints,
  });

  factory MfgWorkOrderCard.fromJson(Map<String, dynamic> j) {
    // Latest check result per quality point → drives the badge.
    final checks = (j['qualityChecks'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    String? latestFor(String pointId) {
      for (final c in checks) {
        if (c['qualityPointId'] == pointId) return c['result'] as String?;
      }
      return null;
    }

    final op = j['bomOperation'] as Map<String, dynamic>? ?? const {};
    final points = (op['qualityPoints'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((p) => MfgQualityPointLite.fromJson(p, latestResult: latestFor(p['id'] as String)))
        .toList();

    return MfgWorkOrderCard(
      id: j['id'] as String,
      sequence: (j['sequence'] as num).toInt(),
      state: j['state'] as String,
      moCode: (j['mo'] as Map?)?['code'] as String? ?? '',
      productNameVi: (j['mo'] as Map?)?['product']?['nameVi'] as String? ?? '',
      operationNameVi: op['nameVi'] as String? ?? '',
      workCenterId: (j['workCenter'] as Map?)?['id'] as String? ?? '',
      workCenterNameVi: (j['workCenter'] as Map?)?['nameVi'] as String? ?? '',
      qualityPoints: points,
    );
  }

  final String id;
  final int sequence;
  final String state; // PENDING | READY | PROGRESS | BLOCKED | DONE | CANCEL
  final String moCode;
  final String productNameVi;
  final String operationNameVi;
  final String workCenterId;
  final String workCenterNameVi;
  final List<MfgQualityPointLite> qualityPoints;
}

class MfgQualityAlert {
  const MfgQualityAlert({
    required this.id,
    required this.title,
    required this.stage,
    required this.description,
  });

  factory MfgQualityAlert.fromJson(Map<String, dynamic> j) => MfgQualityAlert(
        id: j['id'] as String,
        title: j['title'] as String,
        stage: j['stage'] as String,
        description: j['description'] as String?,
      );

  final String id;
  final String title;
  final String stage; // NEW | CONFIRMED | SOLVED
  final String? description;
}

// ── client ──────────────────────────────────────────────────────────────────

class ManufacturingApi {
  ManufacturingApi(this._dio);
  final Dio _dio;

  static const _base = '/manufacturing';

  List<T> _list<T>(Response<dynamic> res, T Function(Map<String, dynamic>) fromJson) {
    final data = res.data?['data'] as List? ?? const [];
    return data.map((e) => fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Result<List<MfgOrderSummary>, AppFailure>> listOrders({String? state}) =>
      _get('$_base/orders', query: {if (state != null) 'state': state},
          parse: (res) => _list(res, MfgOrderSummary.fromJson),);

  Future<Result<MfgOrderDetail, AppFailure>> getOrder(String id) => _get(
        '$_base/orders/$id',
        parse: (res) => MfgOrderDetail.fromJson(
            (res.data?['data'] as Map).cast<String, dynamic>(),),
      );

  Future<Result<List<MfgBomSummary>, AppFailure>> listBoms() => _get('$_base/boms',
      parse: (res) => _list(res, MfgBomSummary.fromJson),);

  Future<Result<MfgCost, AppFailure>> bomCost(String bomId) => _get(
        '$_base/boms/$bomId/cost',
        parse: (res) =>
            MfgCost.fromJson((res.data?['data'] as Map).cast<String, dynamic>()),
      );

  Future<Result<List<MfgOnHand>, AppFailure>> onHand() => _get('$_base/stock/on-hand',
      parse: (res) => _list(res, MfgOnHand.fromJson),);

  Future<Result<List<MfgExpiringLot>, AppFailure>> expiringLots(DateTime before) =>
      _get('$_base/lots/expiring',
          query: {'before': before.toUtc().toIso8601String()},
          parse: (res) => _list(res, MfgExpiringLot.fromJson),);

  Future<Result<List<MfgStateCount>, AppFailure>> moCounts() =>
      _get('$_base/dashboard/mo-counts',
          parse: (res) => _list(res, MfgStateCount.fromJson),);

  // ── mutations ──
  Future<Result<MfgOrderDetail, AppFailure>> createOrder({
    required String bomId,
    required double qtyToProduce,
  }) =>
      _post('$_base/orders',
          body: {'bomId': bomId, 'qtyToProduce': qtyToProduce},
          parse: (res) => MfgOrderDetail.fromJson(
              (res.data?['data'] as Map).cast<String, dynamic>(),),);

  Future<Result<void, AppFailure>> confirm(String id) =>
      _postVoid('$_base/orders/$id/confirm');

  Future<Result<void, AppFailure>> checkAvailability(String id) =>
      _postVoidGet('$_base/orders/$id/check-availability');

  Future<Result<void, AppFailure>> reserve(String id) =>
      _postVoid('$_base/orders/$id/reserve');

  Future<Result<void, AppFailure>> produce(String id) =>
      _postVoid('$_base/orders/$id/produce', body: const {});

  Future<Result<void, AppFailure>> cancel(String id) =>
      _postVoid('$_base/orders/$id/cancel');

  Future<Result<void, AppFailure>> scrap({
    required String productId,
    required double qty,
    required String uomId,
    required String reason,
  }) =>
      _postVoid('$_base/scraps',
          body: {'productId': productId, 'qty': qty, 'uomId': uomId, 'reason': reason},);

  // ── shop floor + QC ──
  Future<Result<List<MfgWorkOrderCard>, AppFailure>> shopFloor({String? workCenter}) =>
      _get('$_base/shop-floor',
          query: {if (workCenter != null) 'workCenter': workCenter},
          parse: (res) => _list(res, MfgWorkOrderCard.fromJson),);

  Future<Result<void, AppFailure>> startWo(String id) =>
      _postVoid('$_base/work-orders/$id/start');
  Future<Result<void, AppFailure>> pauseWo(String id) =>
      _postVoid('$_base/work-orders/$id/pause');
  Future<Result<void, AppFailure>> doneWo(String id) =>
      _postVoid('$_base/work-orders/$id/done');

  Future<Result<void, AppFailure>> recordCheck({
    required String qualityPointId,
    required String workOrderId,
    double? measuredValue,
    String? passFail,
    String? note,
  }) =>
      _postVoid('$_base/quality-checks', body: {
        'qualityPointId': qualityPointId,
        'workOrderId': workOrderId,
        if (measuredValue != null) 'measuredValue': measuredValue,
        if (passFail != null) 'passFail': passFail,
        if (note != null) 'note': note,
      },);

  Future<Result<List<MfgQualityAlert>, AppFailure>> listAlerts({String? stage}) =>
      _get('$_base/quality-alerts',
          query: {if (stage != null) 'stage': stage},
          parse: (res) => _list(res, MfgQualityAlert.fromJson),);

  Future<Result<void, AppFailure>> setAlertStage(String id, String stage) =>
      _postVoid('$_base/quality-alerts/$id/stage', body: {'stage': stage});

  // ── helpers ──
  Future<Result<T, AppFailure>> _get<T>(
    String path, {
    required T Function(Response<dynamic> res) parse,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(parse(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<T, AppFailure>> _post<T>(
    String path, {
    required T Function(Response<dynamic> res) parse,
    Object? body,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(parse(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> _postVoid(String path, {Object? body}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> _postVoidGet(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
