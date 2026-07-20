import 'package:equatable/equatable.dart';

import 'address.dart';
import 'kitchen_status.dart';
import 'order_status.dart';
import 'payment.dart';
import 'refund.dart';

class OrderItem extends Equatable {
  const OrderItem({
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

  final String id;
  final String productId;
  final String? variantId;
  final String productName;
  final String? variantLabel;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? customMessage;

  /// Cake personalization payload — wizard output. Free-form JSON map.
  /// Only set when the customer used the wizard at checkout.
  final Map<String, dynamic>? personalization;

  @override
  List<Object?> get props => [
        id,
        productId,
        variantId,
        productName,
        variantLabel,
        quantity,
        unitPrice,
        lineTotal,
        customMessage,
        personalization,
      ];
}

class OrderStatusEvent extends Equatable {
  const OrderStatusEvent({
    required this.id,
    required this.toStatus,
    required this.createdAt,
    this.fromStatus,
    this.actorId,
    this.note,
  });

  final String id;
  final OrderStatus? fromStatus;
  final OrderStatus toStatus;
  final String? actorId;
  final String? note;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [id, fromStatus, toStatus, actorId, note, createdAt];
}

class Order extends Equatable {
  const Order({
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

  final String id;
  final String code;
  final String customerId;
  final String storeId;
  final String? storeName;
  final FulfillmentType fulfillmentType;
  final OrderStatus status;
  final String? kitchenId;
  final KitchenStatus? kitchenStatus;
  final double subtotal;
  final double deliveryFee;
  final double total;

  /// Total promotion (campaign) discount applied to this order, in VND.
  /// 0 when no campaign matched. Drives the "Khuyến mãi −{amount}₫" line.
  final int campaignDiscount;

  /// Combo savings recorded as a single "Giảm combo" discount line, in VND.
  /// 0 when the order has no combo. The combo's constituent products appear
  /// as normal line items at their regular price.
  final int bundleDiscount;

  /// Optional breakdown of which campaigns applied — each entry is
  /// `{id, name, type, discountVnd}`. Null when the API omits it.
  final List<Map<String, dynamic>>? campaignInfo;

  /// Coupon-code discount applied, in VND. Drives the "Mã giảm giá −{amount}₫" line.
  final int couponDiscount;

  /// Gift-card amount applied to this order, in VND. Drives the
  /// "Thẻ quà tặng −{amount}₫" line.
  final int giftCardAmountVnd;

  /// Loyalty points the customer redeemed on this order. 0 when none.
  final int pointsRedeemed;

  /// Discount granted by the redeemed points, in VND (= pointsRedeemed × 100).
  /// 0 when no points were redeemed. Drives the "Đổi điểm −{amount}₫" line.
  final int pointsDiscount;
  final List<OrderItem> items;
  final List<OrderStatusEvent> statusEvents;
  final List<PaymentSummary> payments;
  final List<Refund> refunds;
  final Address? address;
  final DateTime? scheduledFor;
  final String? notes;

  /// VAT invoice (hóa đơn đỏ) — `requestVatInvoice` toggles the section in
  /// the customer order detail; the 4 company fields are the snapshot the
  /// merchant uses to issue the invoice externally. `invoiceIssuedAt` +
  /// `invoiceFileUrl` are filled by the merchant once the invoice exists.
  final bool requestVatInvoice;
  final String? invoiceCompanyName;
  final String? invoiceTaxId;
  final String? invoiceAddress;
  final String? invoiceEmail;
  final DateTime? invoiceIssuedAt;
  final String? invoiceFileUrl;

  /// Gift order (tặng quà) — `isGift` toggles the gift block in both apps.
  /// When true, the fields below carry the greeting-card message + recipient
  /// and the staff prep flags. `giftWrap` adds wrapping/box; `hidePrice` hides
  /// all amounts on the slip placed in the gift box.
  final bool isGift;
  final String? giftMessage;
  final String? giftRecipientName;
  final String? giftRecipientPhone;
  final bool giftWrap;
  final bool hidePrice;

  /// Order channel (wire value): WEB | STAFF_COUNTER | WHOLESALE |
  /// INTERNAL_TRANSFER. Drives the source badge on staff boards — always
  /// from the backend field, never inferred from notes.
  final String source;

  /// ONLINE | COUNTER_PAID | COUNTER_UNPAID | ON_ACCOUNT | INTERNAL_LEDGER.
  final String settlementMode;

  /// INTERNAL_TRANSFER only — the branch that asked / the branch receiving.
  final String? requestingStoreName;
  final String? destinationStoreName;
  final String? requestingStoreId;
  final String? destinationStoreId;

  /// WHOLESALE only — the buyer's company name.
  final String? wholesaleCompanyName;
  final String? wholesaleDeliveryAddress;

  final DateTime createdAt;
  final DateTime updatedAt;

  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  /// Most recent payment (server returns them ordered desc by createdAt).
  PaymentSummary? get currentPayment =>
      payments.isEmpty ? null : payments.first;

  /// Most recent active refund — used by the order detail screen.
  Refund? get currentRefund => refunds.isEmpty ? null : refunds.first;

  @override
  List<Object?> get props => [
        id,
        code,
        customerId,
        storeId,
        storeName,
        fulfillmentType,
        status,
        kitchenId,
        kitchenStatus,
        subtotal,
        deliveryFee,
        total,
        items,
        statusEvents,
        payments,
        refunds,
        address,
        scheduledFor,
        notes,
        requestVatInvoice,
        invoiceCompanyName,
        invoiceTaxId,
        invoiceAddress,
        invoiceEmail,
        invoiceIssuedAt,
        invoiceFileUrl,
        campaignDiscount,
        bundleDiscount,
        campaignInfo,
        couponDiscount,
        giftCardAmountVnd,
        pointsRedeemed,
        pointsDiscount,
        isGift,
        giftMessage,
        giftRecipientName,
        giftRecipientPhone,
        giftWrap,
        hidePrice,
        source,
        settlementMode,
        requestingStoreName,
        destinationStoreName,
        requestingStoreId,
        destinationStoreId,
        wholesaleCompanyName,
        wholesaleDeliveryAddress,
        createdAt,
        updatedAt,
      ];
}

class OrderPage extends Equatable {
  const OrderPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
  });

  final List<Order> items;
  final int page;
  final int perPage;
  final int total;

  @override
  List<Object?> get props => [items, page, perPage, total];
}
