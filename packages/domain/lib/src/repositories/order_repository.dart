import 'package:banan_core/banan_core.dart';
import 'package:equatable/equatable.dart';

import '../entities/kitchen_status.dart';
import '../entities/order.dart';
import '../entities/order_status.dart';
import '../entities/payment.dart';

class NewAddress {
  const NewAddress({
    required this.recipient,
    required this.phone,
    required this.line1,
    required this.city,
    this.line2,
    this.district,
  });

  final String recipient;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String? district;

  Map<String, dynamic> toJson() => {
        'recipient': recipient,
        'phone': phone,
        'line1': line1,
        if (line2 != null && line2!.isNotEmpty) 'line2': line2,
        'city': city,
        if (district != null && district!.isNotEmpty) 'district': district,
      };
}

class NewOrderItem {
  const NewOrderItem({
    required this.productId,
    required this.quantity,
    this.variantId,
    this.customMessage,
  });

  final String productId;
  final String? variantId;
  final int quantity;
  final String? customMessage;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        if (variantId != null) 'variantId': variantId,
        'quantity': quantity,
        if (customMessage != null && customMessage!.isNotEmpty)
          'customMessage': customMessage,
      };
}

class NewOrder {
  const NewOrder({
    required this.items,
    required this.fulfillmentType,
    required this.paymentMethod,
    this.address,
    this.scheduledFor,
    this.notes,
    this.couponCode,
    this.pointsToRedeem,
  });

  final List<NewOrderItem> items;
  final FulfillmentType fulfillmentType;
  final PaymentMethod paymentMethod;
  final NewAddress? address;
  final DateTime? scheduledFor;
  final String? notes;
  final String? couponCode;
  final int? pointsToRedeem;

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'fulfillmentType': fulfillmentType.wire,
        'paymentMethod': paymentMethod.wire,
        if (address != null) 'address': address!.toJson(),
        if (scheduledFor != null)
          'scheduledFor': scheduledFor!.toUtc().toIso8601String(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (couponCode != null && couponCode!.isNotEmpty) 'couponCode': couponCode,
        if (pointsToRedeem != null && pointsToRedeem! > 0)
          'pointsToRedeem': pointsToRedeem,
      };
}

/// Returned by `OrderRepository.placeOrder`. The customer UI uses this to
/// either navigate inline (CASH) or redirect to a payment provider.
class PlaceOrderResult extends Equatable {
  const PlaceOrderResult({required this.order, required this.payment});

  final Order order;
  final PaymentInstructions payment;

  @override
  List<Object?> get props => [order, payment];
}

abstract class OrderRepository {
  // Customer-side
  Future<Result<PlaceOrderResult, AppFailure>> placeOrder(NewOrder draft);
  Future<Result<OrderPage, AppFailure>> myOrders({int page = 1, int perPage = 20});
  Future<Result<Order, AppFailure>> order(String id);
  Future<Result<Order, AppFailure>> cancel(String id, {String? reason});

  // Merchant-side
  Future<Result<OrderPage, AppFailure>> storeOrders({
    OrderStatus? status,
    int page = 1,
    int perPage = 30,
  });
  Future<Result<Order, AppFailure>> transition(
    String id,
    OrderStatus toStatus, {
    String? note,
  });

  /// Merchant: route an in-preparation order to the central kitchen.
  Future<Result<Order, AppFailure>> transferToKitchen(
    String id, {
    String? kitchenId,
    String? note,
  });

  // Kitchen-side
  Future<Result<List<Order>, AppFailure>> kitchenQueue({
    KitchenStatus? status,
  });
  Future<Result<Order, AppFailure>> transitionKitchen(
    String id,
    KitchenStatus toKitchenStatus,
  );
  Future<Result<Order, AppFailure>> dispatchFromKitchen(String id);
}
