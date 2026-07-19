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
    required this.uomId,
    required this.uomCode,
    required this.avgCost,
  });

  factory MfgProduct.fromJson(Map<String, dynamic> j) => MfgProduct(
        id: j['id'] as String,
        code: j['code'] as String,
        nameVi: j['nameVi'] as String,
        type: j['type'] as String,
        uomId: (j['uom'] as Map?)?['id'] as String? ??
            (j['uomId'] as String? ?? ''),
        uomCode: (j['uom'] as Map?)?['code'] as String? ?? '',
        avgCost: _num(j['avgCost']),
      );

  final String id;
  final String code;
  final String nameVi;
  final String type; // RAW | SEMI | FINISHED | PACKAGING
  final String uomId;
  final String uomCode;
  final double avgCost;
}

class MfgWorkCenter {
  const MfgWorkCenter(
      {required this.id, required this.code, required this.nameVi});

  factory MfgWorkCenter.fromJson(Map<String, dynamic> j) => MfgWorkCenter(
        id: j['id'] as String,
        code: j['code'] as String? ?? '',
        nameVi: j['nameVi'] as String? ?? '',
      );

  final String id;
  final String code;
  final String nameVi;
}

class MfgBomLineDetail {
  const MfgBomLineDetail({
    required this.componentId,
    required this.componentNameVi,
    required this.qty,
    required this.uomId,
    required this.uomCode,
    required this.ratioPercent,
  });

  factory MfgBomLineDetail.fromJson(Map<String, dynamic> j) => MfgBomLineDetail(
        componentId: j['componentId'] as String,
        componentNameVi: (j['component'] as Map?)?['nameVi'] as String? ?? '',
        qty: _num(j['qty']),
        uomId:
            j['uomId'] as String? ?? (j['uom'] as Map?)?['id'] as String? ?? '',
        uomCode: (j['uom'] as Map?)?['code'] as String? ?? '',
        ratioPercent: _num(j['ratioPercent']),
      );

  final String componentId;
  final String componentNameVi;
  final double qty;
  final String uomId;
  final String uomCode;
  final double ratioPercent;
}

class MfgBomOperationDetail {
  const MfgBomOperationDetail({
    required this.sequence,
    required this.nameVi,
    required this.workCenterId,
    required this.workCenterName,
    required this.durationMinutes,
  });

  factory MfgBomOperationDetail.fromJson(Map<String, dynamic> j) =>
      MfgBomOperationDetail(
        sequence: (j['sequence'] as num?)?.toInt() ?? 0,
        nameVi: j['nameVi'] as String? ?? '',
        workCenterId: j['workCenterId'] as String? ?? '',
        workCenterName: (j['workCenter'] as Map?)?['nameVi'] as String? ?? '',
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 0,
      );

  final int sequence;
  final String nameVi;
  final String workCenterId;
  final String workCenterName;
  final int durationMinutes;
}

class MfgBomDetail {
  const MfgBomDetail({
    required this.id,
    required this.productId,
    required this.productNameVi,
    required this.outputQty,
    required this.uomId,
    required this.uomCode,
    required this.lines,
    required this.operations,
  });

  factory MfgBomDetail.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>? ?? const {};
    return MfgBomDetail(
      id: j['id'] as String,
      productId: j['productId'] as String,
      productNameVi: product['nameVi'] as String? ?? '',
      outputQty: _num(j['outputQty']),
      uomId:
          j['uomId'] as String? ?? (j['uom'] as Map?)?['id'] as String? ?? '',
      uomCode: (j['uom'] as Map?)?['code'] as String? ?? '',
      lines: ((j['lines'] as List?) ?? const [])
          .map((e) =>
              MfgBomLineDetail.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      operations: ((j['operations'] as List?) ?? const [])
          .map((e) => MfgBomOperationDetail.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  final String id;
  final String productId;
  final String productNameVi;
  final double outputQty;
  final String uomId;
  final String uomCode;
  final List<MfgBomLineDetail> lines;
  final List<MfgBomOperationDetail> operations;
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
  factory MfgStateCount.fromJson(Map<String, dynamic> j) => MfgStateCount(
        state: j['state'] as String,
        count: (j['count'] as num).toInt(),
      );
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
    final checks =
        (j['qualityChecks'] as List? ?? const []).cast<Map<String, dynamic>>();
    String? latestFor(String pointId) {
      for (final c in checks) {
        if (c['qualityPointId'] == pointId) return c['result'] as String?;
      }
      return null;
    }

    final op = j['bomOperation'] as Map<String, dynamic>? ?? const {};
    final points = (op['qualityPoints'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (p) => MfgQualityPointLite.fromJson(
            p,
            latestResult: latestFor(p['id'] as String),
          ),
        )
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

/// A plannable MO on the schedule board: what to make, when, and by whom.
class MfgScheduleItem {
  const MfgScheduleItem({
    required this.id,
    required this.code,
    required this.productNameVi,
    required this.qtyToProduce,
    required this.uomCode,
    required this.state,
    required this.scheduledDate,
    required this.responsibleId,
    required this.responsibleName,
  });

  factory MfgScheduleItem.fromJson(Map<String, dynamic> j) => MfgScheduleItem(
        id: j['id'] as String,
        code: j['code'] as String,
        productNameVi: j['productNameVi'] as String? ?? '',
        qtyToProduce: _num(j['qtyToProduce']),
        uomCode: j['uomCode'] as String? ?? '',
        state: j['state'] as String,
        scheduledDate: DateTime.tryParse('${j['scheduledDate']}'),
        responsibleId: j['responsibleId'] as String?,
        responsibleName: j['responsibleName'] as String?,
      );

  final String id;
  final String code;
  final String productNameVi;
  final double qtyToProduce;
  final String uomCode;
  final String state;
  final DateTime? scheduledDate;
  final String? responsibleId;
  final String? responsibleName;
}

/// A kitchen user assignable as the person responsible for an MO.
class MfgStaff {
  const MfgStaff({required this.id, required this.fullName});

  factory MfgStaff.fromJson(Map<String, dynamic> j) => MfgStaff(
        id: j['id'] as String,
        fullName: j['fullName'] as String? ?? '',
      );

  final String id;
  final String fullName;
}

// ── reports + replenishment (increment 5) ────────────────────────────────────

class MfgProductionRow {
  const MfgProductionRow({
    required this.productId,
    required this.productCode,
    required this.productNameVi,
    required this.uomCode,
    required this.moCount,
    required this.qtyProduced,
    required this.totalCost,
    required this.avgUnitCost,
  });

  factory MfgProductionRow.fromJson(Map<String, dynamic> j) => MfgProductionRow(
        productId: j['productId'] as String,
        productCode: j['productCode'] as String? ?? '',
        productNameVi: j['productNameVi'] as String? ?? '',
        uomCode: j['uomCode'] as String? ?? '',
        moCount: (j['moCount'] as num?)?.toInt() ?? 0,
        qtyProduced: _num(j['qtyProduced']),
        totalCost: _num(j['totalCost']),
        avgUnitCost: _num(j['avgUnitCost']),
      );

  final String productId;
  final String productCode;
  final String productNameVi;
  final String uomCode;
  final int moCount;
  final double qtyProduced;
  final double totalCost;
  final double avgUnitCost;
}

class MfgProductionReport {
  const MfgProductionReport({
    required this.rows,
    required this.moCount,
    required this.totalCost,
  });

  factory MfgProductionReport.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'] as Map<String, dynamic>? ?? const {};
    return MfgProductionReport(
      rows: ((j['rows'] as List?) ?? const [])
          .map(
            (e) =>
                MfgProductionRow.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      moCount: (totals['moCount'] as num?)?.toInt() ?? 0,
      totalCost: _num(totals['totalCost']),
    );
  }

  final List<MfgProductionRow> rows;
  final int moCount;
  final double totalCost;
}

class MfgScrapReasonRow {
  const MfgScrapReasonRow({
    required this.reason,
    required this.value,
    required this.count,
  });

  factory MfgScrapReasonRow.fromJson(Map<String, dynamic> j) =>
      MfgScrapReasonRow(
        reason: j['reason'] as String? ?? '',
        value: _num(j['value']),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );

  final String reason;
  final double value;
  final int count;
}

class MfgScrapProductRow {
  const MfgScrapProductRow({
    required this.productId,
    required this.productCode,
    required this.productNameVi,
    required this.uomCode,
    required this.qty,
    required this.value,
    required this.count,
  });

  factory MfgScrapProductRow.fromJson(Map<String, dynamic> j) =>
      MfgScrapProductRow(
        productId: j['productId'] as String,
        productCode: j['productCode'] as String? ?? '',
        productNameVi: j['productNameVi'] as String? ?? '',
        uomCode: j['uomCode'] as String? ?? '',
        qty: _num(j['qty']),
        value: _num(j['value']),
        count: (j['count'] as num?)?.toInt() ?? 0,
      );

  final String productId;
  final String productCode;
  final String productNameVi;
  final String uomCode;
  final double qty;
  final double value;
  final int count;
}

class MfgScrapReport {
  const MfgScrapReport({
    required this.byReason,
    required this.byProduct,
    required this.value,
    required this.count,
  });

  factory MfgScrapReport.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'] as Map<String, dynamic>? ?? const {};
    return MfgScrapReport(
      byReason: ((j['byReason'] as List?) ?? const [])
          .map(
            (e) =>
                MfgScrapReasonRow.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      byProduct: ((j['byProduct'] as List?) ?? const [])
          .map(
            (e) =>
                MfgScrapProductRow.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      value: _num(totals['value']),
      count: (totals['count'] as num?)?.toInt() ?? 0,
    );
  }

  final List<MfgScrapReasonRow> byReason;
  final List<MfgScrapProductRow> byProduct;
  final double value;
  final int count;
}

class MfgCostRow {
  const MfgCostRow({
    required this.moId,
    required this.code,
    required this.productNameVi,
    required this.qtyProduced,
    required this.uomCode,
    required this.materialCost,
    required this.operationCost,
    required this.totalCost,
    required this.unitCost,
  });

  factory MfgCostRow.fromJson(Map<String, dynamic> j) => MfgCostRow(
        moId: j['moId'] as String,
        code: j['code'] as String? ?? '',
        productNameVi: j['productNameVi'] as String? ?? '',
        qtyProduced: _num(j['qtyProduced']),
        uomCode: j['uomCode'] as String? ?? '',
        materialCost: _num(j['materialCost']),
        operationCost: _num(j['operationCost']),
        totalCost: _num(j['totalCost']),
        unitCost: _num(j['unitCost']),
      );

  final String moId;
  final String code;
  final String productNameVi;
  final double qtyProduced;
  final String uomCode;
  final double materialCost;
  final double operationCost;
  final double totalCost;
  final double unitCost;
}

class MfgCostReport {
  const MfgCostReport({
    required this.rows,
    required this.materialCost,
    required this.operationCost,
    required this.totalCost,
  });

  factory MfgCostReport.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'] as Map<String, dynamic>? ?? const {};
    return MfgCostReport(
      rows: ((j['rows'] as List?) ?? const [])
          .map((e) => MfgCostRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      materialCost: _num(totals['materialCost']),
      operationCost: _num(totals['operationCost']),
      totalCost: _num(totals['totalCost']),
    );
  }

  final List<MfgCostRow> rows;
  final double materialCost;
  final double operationCost;
  final double totalCost;
}

class MfgReplenishRow {
  const MfgReplenishRow({
    required this.productId,
    required this.productCode,
    required this.productNameVi,
    required this.uomCode,
    required this.demand,
    required this.available,
    required this.shortfall,
    required this.avgCost,
    required this.estCost,
  });

  factory MfgReplenishRow.fromJson(Map<String, dynamic> j) => MfgReplenishRow(
        productId: j['productId'] as String,
        productCode: j['productCode'] as String? ?? '',
        productNameVi: j['productNameVi'] as String? ?? '',
        uomCode: j['uomCode'] as String? ?? '',
        demand: _num(j['demand']),
        available: _num(j['available']),
        shortfall: _num(j['shortfall']),
        avgCost: _num(j['avgCost']),
        estCost: _num(j['estCost']),
      );

  final String productId;
  final String productCode;
  final String productNameVi;
  final String uomCode;
  final double demand;
  final double available;
  final double shortfall;
  final double avgCost;
  final double estCost;
}

class MfgReplenishment {
  const MfgReplenishment({required this.rows, required this.estCost});

  factory MfgReplenishment.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'] as Map<String, dynamic>? ?? const {};
    return MfgReplenishment(
      rows: ((j['rows'] as List?) ?? const [])
          .map(
            (e) => MfgReplenishRow.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      estCost: _num(totals['estCost']),
    );
  }

  final List<MfgReplenishRow> rows;
  final double estCost;
}

// ── client ──────────────────────────────────────────────────────────────────

class ManufacturingApi {
  ManufacturingApi(this._dio);
  final Dio _dio;

  static const _base = '/manufacturing';

  List<T> _list<T>(
    Response<dynamic> res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final data = res.data?['data'] as List? ?? const [];
    return data
        .map((e) => fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Result<List<MfgOrderSummary>, AppFailure>> listOrders({
    String? state,
  }) =>
      _get(
        '$_base/orders',
        query: {if (state != null) 'state': state},
        parse: (res) => _list(res, MfgOrderSummary.fromJson),
      );

  Future<Result<MfgOrderDetail, AppFailure>> getOrder(String id) => _get(
        '$_base/orders/$id',
        parse: (res) => MfgOrderDetail.fromJson(
          (res.data?['data'] as Map).cast<String, dynamic>(),
        ),
      );

  Future<Result<List<MfgBomSummary>, AppFailure>> listBoms() => _get(
        '$_base/boms',
        parse: (res) => _list(res, MfgBomSummary.fromJson),
      );

  /// Master-data product list (for scrap/receipt/BoM pickers). [type] filters by
  /// RAW/SEMI/FINISHED/PACKAGING.
  Future<Result<List<MfgProduct>, AppFailure>> listProducts({String? type}) =>
      _get(
        '$_base/products',
        query: {if (type != null) 'type': type},
        parse: (res) => _list(res, MfgProduct.fromJson),
      );

  Future<Result<List<MfgWorkCenter>, AppFailure>> listWorkCenters() => _get(
        '$_base/work-centers',
        parse: (res) => _list(res, MfgWorkCenter.fromJson),
      );

  /// Full BoM (lines + operations) for the recipe editor.
  Future<Result<MfgBomDetail, AppFailure>> getBom(String id) => _get(
        '$_base/boms/$id',
        parse: (res) => MfgBomDetail.fromJson(
          (res.data?['data'] as Map).cast<String, dynamic>(),
        ),
      );

  /// Save a recipe as a new active version (editing posts here too).
  Future<Result<void, AppFailure>> createBom({
    required String productId,
    required double outputQty,
    required String uomId,
    required List<({String componentId, double qty, String uomId})> lines,
    required List<({String nameVi, String workCenterId, int durationMinutes})>
        operations,
  }) =>
      _postVoid(
        '$_base/boms',
        body: {
          'productId': productId,
          'outputQty': outputQty,
          'uomId': uomId,
          'lines': [
            for (final l in lines)
              {'componentId': l.componentId, 'qty': l.qty, 'uomId': l.uomId},
          ],
          'operations': [
            for (final o in operations)
              {
                'nameVi': o.nameVi,
                'workCenterId': o.workCenterId,
                'durationMinutes': o.durationMinutes,
              },
          ],
        },
      );

  Future<Result<MfgCost, AppFailure>> bomCost(String bomId) => _get(
        '$_base/boms/$bomId/cost',
        parse: (res) => MfgCost.fromJson(
          (res.data?['data'] as Map).cast<String, dynamic>(),
        ),
      );

  Future<Result<List<MfgOnHand>, AppFailure>> onHand() => _get(
        '$_base/stock/on-hand',
        parse: (res) => _list(res, MfgOnHand.fromJson),
      );

  Future<Result<List<MfgExpiringLot>, AppFailure>> expiringLots(
    DateTime before,
  ) =>
      _get(
        '$_base/lots/expiring',
        query: {'before': before.toUtc().toIso8601String()},
        parse: (res) => _list(res, MfgExpiringLot.fromJson),
      );

  Future<Result<List<MfgStateCount>, AppFailure>> moCounts() => _get(
        '$_base/dashboard/mo-counts',
        parse: (res) => _list(res, MfgStateCount.fromJson),
      );

  // ── reports + replenishment ──

  /// A calendar day anchored to UTC midnight, so the range round-trips to the
  /// same day whatever timezone the backend runs in (matches [planOrder]).
  static String? _day(DateTime? d) =>
      d == null ? null : DateTime.utc(d.year, d.month, d.day).toIso8601String();

  Future<Result<MfgProductionReport, AppFailure>> productionReport({
    DateTime? from,
    DateTime? to,
  }) =>
      _get(
        '$_base/reports/production',
        query: {
          if (_day(from) != null) 'from': _day(from),
          if (_day(to) != null) 'to': _day(to),
        },
        parse: (res) => MfgProductionReport.fromJson(
          (res.data?['data'] as Map).cast<String, dynamic>(),
        ),
      );

  Future<Result<MfgScrapReport, AppFailure>> scrapReport({
    DateTime? from,
    DateTime? to,
  }) =>
      _get(
        '$_base/reports/scrap',
        query: {
          if (_day(from) != null) 'from': _day(from),
          if (_day(to) != null) 'to': _day(to),
        },
        parse: (res) => MfgScrapReport.fromJson(
          (res.data?['data'] as Map).cast<String, dynamic>(),
        ),
      );

  Future<Result<MfgCostReport, AppFailure>> costReport({
    DateTime? from,
    DateTime? to,
  }) =>
      _get(
        '$_base/reports/cost',
        query: {
          if (_day(from) != null) 'from': _day(from),
          if (_day(to) != null) 'to': _day(to),
        },
        parse: (res) => MfgCostReport.fromJson(
          (res.data?['data'] as Map).cast<String, dynamic>(),
        ),
      );

  Future<Result<MfgReplenishment, AppFailure>> replenishment() => _get(
        '$_base/replenishment',
        parse: (res) => MfgReplenishment.fromJson(
          (res.data?['data'] as Map).cast<String, dynamic>(),
        ),
      );

  // ── planning ──
  Future<Result<List<MfgScheduleItem>, AppFailure>> schedule() => _get(
        '$_base/schedule',
        parse: (res) => _list(res, MfgScheduleItem.fromJson),
      );

  Future<Result<List<MfgStaff>, AppFailure>> listStaff() =>
      _get('$_base/staff', parse: (res) => _list(res, MfgStaff.fromJson));

  /// Set/clear an MO's scheduled date and assignee. Nulls clear the field.
  Future<Result<void, AppFailure>> planOrder(
    String id, {
    required DateTime? scheduledDate,
    required String? responsibleId,
  }) =>
      _postVoid(
        '$_base/orders/$id/plan',
        body: {
          // Anchor the chosen calendar day to UTC midnight so it round-trips to
          // the same day regardless of the server's timezone (the read side reads
          // UTC calendar fields). A bare local DateTime drops its offset and lands
          // a day off on any ahead-of-UTC backend.
          'scheduledDate': scheduledDate == null
              ? null
              : DateTime.utc(
                  scheduledDate.year,
                  scheduledDate.month,
                  scheduledDate.day,
                ).toIso8601String(),
          'responsibleId': responsibleId,
        },
      );

  // ── mutations ──
  Future<Result<MfgOrderDetail, AppFailure>> createOrder({
    required String bomId,
    required double qtyToProduce,
  }) =>
      _post(
        '$_base/orders',
        body: {'bomId': bomId, 'qtyToProduce': qtyToProduce},
        parse: (res) => MfgOrderDetail.fromJson(
          (res.data?['data'] as Map).cast<String, dynamic>(),
        ),
      );

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

  /// Log a scrap. [uomId] defaults server-side to the product's base UoM, so the
  /// app posts [qty] in the product's own unit; [lotId] optionally pins the lot.
  Future<Result<void, AppFailure>> scrap({
    required String productId,
    required double qty,
    required String reason,
    String? uomId,
    String? lotId,
  }) =>
      _postVoid(
        '$_base/scraps',
        body: {
          'productId': productId,
          'qty': qty,
          'reason': reason,
          if (uomId != null) 'uomId': uomId,
          if (lotId != null) 'lotId': lotId,
        },
      );

  /// Receive raw material into stock (rolls AVCO). [uomId] defaults to the
  /// product's base UoM; [lotName] names the lot for lot-tracked products.
  Future<Result<void, AppFailure>> receive({
    required String productId,
    required double qty,
    required double unitCost,
    String? uomId,
    String? lotName,
  }) =>
      _postVoid(
        '$_base/receipts',
        body: {
          'productId': productId,
          'qty': qty,
          'unitCost': unitCost,
          if (uomId != null) 'uomId': uomId,
          if (lotName != null) 'lotName': lotName,
        },
      );

  // ── shop floor + QC ──
  Future<Result<List<MfgWorkOrderCard>, AppFailure>> shopFloor({
    String? workCenter,
  }) =>
      _get(
        '$_base/shop-floor',
        query: {if (workCenter != null) 'workCenter': workCenter},
        parse: (res) => _list(res, MfgWorkOrderCard.fromJson),
      );

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
      _postVoid(
        '$_base/quality-checks',
        body: {
          'qualityPointId': qualityPointId,
          'workOrderId': workOrderId,
          if (measuredValue != null) 'measuredValue': measuredValue,
          if (passFail != null) 'passFail': passFail,
          if (note != null) 'note': note,
        },
      );

  Future<Result<List<MfgQualityAlert>, AppFailure>> listAlerts({
    String? stage,
  }) =>
      _get(
        '$_base/quality-alerts',
        query: {if (stage != null) 'stage': stage},
        parse: (res) => _list(res, MfgQualityAlert.fromJson),
      );

  Future<Result<void, AppFailure>> setAlertStage(String id, String stage) =>
      _postVoid('$_base/quality-alerts/$id/stage', body: {'stage': stage});

  // ── helpers ──
  Future<Result<T, AppFailure>> _get<T>(
    String path, {
    required T Function(Response<dynamic> res) parse,
    Map<String, dynamic>? query,
  }) async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
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

  Future<Result<void, AppFailure>> _postVoid(
    String path, {
    Object? body,
  }) async {
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
