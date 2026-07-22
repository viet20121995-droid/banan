import 'package:banan_domain/banan_domain.dart';

import 'address_dto.dart';
import 'payment_dto.dart';
import 'refund_dto.dart';

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

/// Parses a VND amount that may arrive as a number or a Decimal string.
int _toIntVnd(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? (double.tryParse(value)?.round() ?? 0);
  }
  return 0;
}

class OrderItemDto {
  const OrderItemDto({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.variantId,
    this.variantLabel,
    this.customMessage,
    this.personalization,
  });

  factory OrderItemDto.fromJson(Map<String, dynamic> json) {
    return OrderItemDto(
      id: json['id'] as String,
      productId: json['productId'] as String,
      variantId: json['variantId'] as String?,
      productName: json['productName'] as String,
      variantLabel: json['variantLabel'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: _toDouble(json['unitPrice']),
      lineTotal: _toDouble(json['lineTotal']),
      customMessage: json['customMessage'] as String?,
      personalization: json['personalization'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String productId;
  final String? variantId;
  final String productName;
  final String? variantLabel;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? customMessage;
  final Map<String, dynamic>? personalization;

  OrderItem toDomain() => OrderItem(
        id: id,
        productId: productId,
        variantId: variantId,
        productName: productName,
        variantLabel: variantLabel,
        quantity: quantity,
        unitPrice: unitPrice,
        lineTotal: lineTotal,
        customMessage: customMessage,
        personalization: personalization,
      );
}

class OrderStatusEventDto {
  const OrderStatusEventDto({
    required this.id,
    required this.toStatus,
    required this.createdAt,
    this.fromStatus,
    this.actorId,
    this.note,
  });

  factory OrderStatusEventDto.fromJson(Map<String, dynamic> json) {
    return OrderStatusEventDto(
      id: json['id'] as String,
      fromStatus: json['fromStatus'] as String?,
      toStatus: json['toStatus'] as String,
      actorId: json['actorId'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String? fromStatus;
  final String toStatus;
  final String? actorId;
  final String? note;
  final DateTime createdAt;

  OrderStatusEvent toDomain() => OrderStatusEvent(
        id: id,
        fromStatus:
            fromStatus == null ? null : OrderStatus.fromWire(fromStatus!),
        toStatus: OrderStatus.fromWire(toStatus),
        actorId: actorId,
        note: note,
        createdAt: createdAt,
      );
}

/// Aggregated picking sheet for the kitchen: one row per item across every
/// live internal transfer, one column per receiving branch, plus a total.
class TransferSummaryDto {
  const TransferSummaryDto({
    required this.stores,
    required this.rows,
    required this.orderCount,
  });

  factory TransferSummaryDto.fromJson(Map<String, dynamic> json) =>
      TransferSummaryDto(
        stores: ((json['stores'] as List?) ?? const [])
            .map((e) => (
                  id: (e as Map)['id'] as String,
                  name: e['name'] as String? ?? '',
                ))
            .toList(),
        rows: ((json['rows'] as List?) ?? const [])
            .map(
              (e) => TransferSummaryRow.fromJson(
                (e as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      );

  final List<({String id, String name})> stores;
  final List<TransferSummaryRow> rows;
  final int orderCount;
}

class TransferSummaryRow {
  const TransferSummaryRow({
    required this.label,
    required this.unit,
    required this.isSupply,
    required this.byStore,
    required this.total,
  });

  factory TransferSummaryRow.fromJson(Map<String, dynamic> json) =>
      TransferSummaryRow(
        label: json['label'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        isSupply: json['isSupply'] as bool? ?? false,
        byStore: ((json['byStore'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', _toDouble(v))),
        total: _toDouble(json['total']),
      );

  final String label;
  final String unit;
  final bool isSupply;
  final Map<String, double> byStore;
  final double total;
}

/// MES supply line on an internal transfer (see [TransferMfgItem]).
class TransferMfgItemDto {
  const TransferMfgItemDto({
    required this.id,
    required this.mfgProductId,
    required this.code,
    required this.name,
    required this.uomCode,
    required this.qty,
    this.receivedQty,
  });

  factory TransferMfgItemDto.fromJson(Map<String, dynamic> json) {
    final product = json['mfgProduct'] as Map<String, dynamic>?;
    return TransferMfgItemDto(
      id: json['id'] as String,
      mfgProductId: json['mfgProductId'] as String,
      code: product?['code'] as String? ?? '',
      name: product?['nameVi'] as String? ?? '',
      uomCode: (product?['uom'] as Map?)?['code'] as String? ?? '',
      qty: _toDouble(json['qty']),
      receivedQty:
          json['receivedQty'] == null ? null : _toDouble(json['receivedQty']),
    );
  }

  final String id;
  final String mfgProductId;
  final String code;
  final String name;
  final String uomCode;
  final double qty;
  final double? receivedQty;

  TransferMfgItem toDomain() => TransferMfgItem(
        id: id,
        mfgProductId: mfgProductId,
        code: code,
        name: name,
        uomCode: uomCode,
        qty: qty,
        receivedQty: receivedQty,
      );
}

class OrderDto {
  const OrderDto({
    required this.id,
    required this.code,
    required this.customerId,
    required this.storeId,
    required this.fulfillmentType,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.items,
    required this.statusEvents,
    this.mfgItems = const [],
    required this.payments,
    required this.refunds,
    required this.createdAt,
    required this.updatedAt,
    this.address,
    this.scheduledFor,
    this.notes,
    this.storeName,
    this.kitchenId,
    this.kitchenStatus,
    this.requestVatInvoice = false,
    this.invoiceCompanyName,
    this.invoiceTaxId,
    this.invoiceAddress,
    this.invoiceEmail,
    this.invoiceIssuedAt,
    this.invoiceFileUrl,
    this.campaignDiscount = 0,
    this.bundleDiscount = 0,
    this.campaignInfo,
    this.couponDiscount = 0,
    this.giftCardAmountVnd = 0,
    this.pointsRedeemed = 0,
    this.pointsDiscount = 0,
    this.isGift = false,
    this.giftMessage,
    this.giftRecipientName,
    this.giftRecipientPhone,
    this.giftWrap = false,
    this.hidePrice = false,
    this.source = 'WEB',
    this.settlementMode = 'ONLINE',
    this.requestingStoreName,
    this.destinationStoreName,
    this.requestingStoreId,
    this.destinationStoreId,
    this.wholesaleCompanyName,
    this.wholesaleDeliveryAddress,
  });

  factory OrderDto.fromJson(Map<String, dynamic> json) {
    final store = json['store'] as Map<String, dynamic>?;
    final campaignInfoRaw = json['campaignInfo'] as List?;
    return OrderDto(
      id: json['id'] as String,
      code: json['code'] as String,
      customerId: json['customerId'] as String,
      storeId: json['storeId'] as String,
      storeName: store?['name'] as String?,
      fulfillmentType: json['fulfillmentType'] as String,
      status: json['status'] as String,
      kitchenId: json['kitchenId'] as String?,
      kitchenStatus: json['kitchenStatus'] as String?,
      subtotal: _toDouble(json['subtotal']),
      deliveryFee: _toDouble(json['deliveryFee']),
      total: _toDouble(json['total']),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => OrderItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      mfgItems: ((json['mfgItems'] as List?) ?? const [])
          .map((e) => TransferMfgItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      statusEvents: ((json['statusEvents'] as List?) ?? const [])
          .map((e) => OrderStatusEventDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      payments: ((json['payments'] as List?) ?? const [])
          .map((e) => PaymentDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      refunds: ((json['refunds'] as List?) ?? const [])
          .map((e) => RefundDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      address: json['address'] == null
          ? null
          : AddressDto.fromJson(json['address'] as Map<String, dynamic>),
      scheduledFor: json['scheduledFor'] as String?,
      notes: json['notes'] as String?,
      requestVatInvoice: json['requestVatInvoice'] as bool? ?? false,
      invoiceCompanyName: json['invoiceCompanyName'] as String?,
      invoiceTaxId: json['invoiceTaxId'] as String?,
      invoiceAddress: json['invoiceAddress'] as String?,
      invoiceEmail: json['invoiceEmail'] as String?,
      invoiceIssuedAt: json['invoiceIssuedAt'] as String?,
      invoiceFileUrl: json['invoiceFileUrl'] as String?,
      campaignDiscount: _toIntVnd(json['campaignDiscount']),
      bundleDiscount: _toIntVnd(json['bundleDiscount']),
      campaignInfo: campaignInfoRaw
          ?.map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      couponDiscount: _toIntVnd(json['couponDiscount']),
      giftCardAmountVnd: _toIntVnd(json['giftCardAmountVnd']),
      pointsRedeemed: _toIntVnd(json['pointsRedeemed']),
      pointsDiscount: _toIntVnd(json['pointsDiscount']),
      isGift: json['isGift'] as bool? ?? false,
      giftMessage: json['giftMessage'] as String?,
      giftRecipientName: json['giftRecipientName'] as String?,
      giftRecipientPhone: json['giftRecipientPhone'] as String?,
      giftWrap: json['giftWrap'] as bool? ?? false,
      hidePrice: json['hidePrice'] as bool? ?? false,
      source: json['source'] as String? ?? 'WEB',
      settlementMode: json['settlementMode'] as String? ?? 'ONLINE',
      requestingStoreName:
          (json['requestingStore'] as Map?)?['name'] as String?,
      destinationStoreName:
          (json['destinationStore'] as Map?)?['name'] as String?,
      requestingStoreId: json['requestingStoreId'] as String?,
      destinationStoreId: json['destinationStoreId'] as String?,
      wholesaleCompanyName:
          (json['wholesaleAccount'] as Map?)?['companyName'] as String?,
      wholesaleDeliveryAddress:
          (json['wholesaleAccount'] as Map?)?['deliveryAddress'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String code;
  final String customerId;
  final String storeId;
  final String? storeName;
  final String fulfillmentType;
  final String status;
  final String? kitchenId;
  final String? kitchenStatus;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final List<OrderItemDto> items;
  final List<TransferMfgItemDto> mfgItems;
  final List<OrderStatusEventDto> statusEvents;
  final List<PaymentDto> payments;
  final List<RefundDto> refunds;
  final AddressDto? address;
  final String? scheduledFor;
  final String? notes;
  final bool requestVatInvoice;
  final String? invoiceCompanyName;
  final String? invoiceTaxId;
  final String? invoiceAddress;
  final String? invoiceEmail;

  /// ISO-8601 string from the API (kept raw so a null roundtrip stays null).
  final String? invoiceIssuedAt;
  final String? invoiceFileUrl;
  final int campaignDiscount;
  final int bundleDiscount;
  final List<Map<String, dynamic>>? campaignInfo;
  final int couponDiscount;
  final int giftCardAmountVnd;
  final int pointsRedeemed;
  final int pointsDiscount;
  final bool isGift;
  final String? giftMessage;
  final String? giftRecipientName;
  final String? giftRecipientPhone;
  final bool giftWrap;
  final bool hidePrice;
  final String source;
  final String settlementMode;
  final String? requestingStoreName;
  final String? destinationStoreName;
  final String? requestingStoreId;
  final String? destinationStoreId;
  final String? wholesaleCompanyName;
  final String? wholesaleDeliveryAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order toDomain() => Order(
        id: id,
        code: code,
        customerId: customerId,
        storeId: storeId,
        storeName: storeName,
        fulfillmentType: FulfillmentType.fromWire(fulfillmentType),
        status: OrderStatus.fromWire(status),
        kitchenId: kitchenId,
        kitchenStatus: kitchenStatus == null
            ? null
            : KitchenStatus.fromWire(kitchenStatus!),
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        items: items.map((i) => i.toDomain()).toList(),
        mfgItems: mfgItems.map((i) => i.toDomain()).toList(),
        statusEvents: statusEvents.map((e) => e.toDomain()).toList(),
        payments: payments.map((p) => p.toDomain()).toList(),
        refunds: refunds.map((r) => r.toDomain()).toList(),
        address: address?.toDomain(),
        scheduledFor:
            scheduledFor == null ? null : DateTime.tryParse(scheduledFor!),
        notes: notes,
        requestVatInvoice: requestVatInvoice,
        invoiceCompanyName: invoiceCompanyName,
        invoiceTaxId: invoiceTaxId,
        invoiceAddress: invoiceAddress,
        invoiceEmail: invoiceEmail,
        invoiceIssuedAt: invoiceIssuedAt == null
            ? null
            : DateTime.tryParse(invoiceIssuedAt!),
        invoiceFileUrl: invoiceFileUrl,
        campaignDiscount: campaignDiscount,
        bundleDiscount: bundleDiscount,
        campaignInfo: campaignInfo,
        couponDiscount: couponDiscount,
        giftCardAmountVnd: giftCardAmountVnd,
        pointsRedeemed: pointsRedeemed,
        pointsDiscount: pointsDiscount,
        isGift: isGift,
        giftMessage: giftMessage,
        giftRecipientName: giftRecipientName,
        giftRecipientPhone: giftRecipientPhone,
        giftWrap: giftWrap,
        hidePrice: hidePrice,
        source: source,
        settlementMode: settlementMode,
        requestingStoreName: requestingStoreName,
        destinationStoreName: destinationStoreName,
        requestingStoreId: requestingStoreId,
        destinationStoreId: destinationStoreId,
        wholesaleCompanyName: wholesaleCompanyName,
        wholesaleDeliveryAddress: wholesaleDeliveryAddress,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
