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
  final List<OrderItem> items;
  final List<OrderStatusEvent> statusEvents;
  final List<PaymentSummary> payments;
  final List<Refund> refunds;
  final Address? address;
  final DateTime? scheduledFor;
  final String? notes;
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
