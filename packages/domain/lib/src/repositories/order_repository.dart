import 'package:banan_core/banan_core.dart';
import 'package:equatable/equatable.dart';

import '../entities/auth_session.dart';
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
    this.wardCode,
  });

  final String recipient;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String? district;

  /// HCMC ward catalog code — drives the delivery distance check.
  final String? wardCode;

  Map<String, dynamic> toJson() => {
        'recipient': recipient,
        'phone': phone,
        'line1': line1,
        if (line2 != null && line2!.isNotEmpty) 'line2': line2,
        'city': city,
        if (district != null && district!.isNotEmpty) 'district': district,
        if (wardCode != null && wardCode!.isNotEmpty) 'wardCode': wardCode,
      };
}

class NewOrderItem {
  const NewOrderItem({
    required this.productId,
    required this.quantity,
    this.variantId,
    this.customMessage,
    this.personalization,
  });

  final String productId;
  final String? variantId;
  final int quantity;
  final String? customMessage;

  /// Cake personalization payload — wizard output. Free-form JSON map
  /// (text-on-cake, candle count, reference image URL, …).
  final Map<String, dynamic>? personalization;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        if (variantId != null) 'variantId': variantId,
        'quantity': quantity,
        if (customMessage != null && customMessage!.isNotEmpty)
          'customMessage': customMessage,
        if (personalization != null && personalization!.isNotEmpty)
          'personalization': personalization,
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
    this.giftCardCode,
    this.pointsToRedeem,
    this.guestFullName,
    this.guestPhone,
    this.guestEmail,
    this.pickupStoreId,
    this.deliveryStoreId,
    this.requestVatInvoice = false,
    this.invoiceCompanyName,
    this.invoiceTaxId,
    this.invoiceAddress,
    this.invoiceEmail,
    this.isGift = false,
    this.giftMessage,
    this.giftRecipientName,
    this.giftRecipientPhone,
    this.giftWrap = false,
    this.hidePrice = false,
  });

  final List<NewOrderItem> items;
  final FulfillmentType fulfillmentType;
  final PaymentMethod paymentMethod;
  final NewAddress? address;
  final DateTime? scheduledFor;
  final String? notes;
  final String? couponCode;
  final String? giftCardCode;
  final int? pointsToRedeem;

  /// Guest-checkout fields. Sent only when the customer is unauthenticated.
  final String? guestFullName;
  final String? guestPhone;
  final String? guestEmail;

  /// For PICKUP orders — which Banan branch the customer wants to collect
  /// from. Null falls back to the product's catalog store on the backend.
  final String? pickupStoreId;

  /// For DELIVERY orders — which Banan branch fulfills the delivery. Null
  /// falls back to the catalog store. Setting this lets the customer choose
  /// the branch closest to the delivery address, and lets the merchant
  /// pause delivery for a single branch without affecting the others.
  final String? deliveryStoreId;

  /// VAT invoice (hóa đơn đỏ) — optional company-invoice request. When true,
  /// the 4 company fields below are sent and required by the backend.
  final bool requestVatInvoice;
  final String? invoiceCompanyName;
  final String? invoiceTaxId;
  final String? invoiceAddress;
  final String? invoiceEmail;

  /// Gift order (tặng quà) — when `isGift` is false the gift fields are
  /// omitted from the payload entirely. When true, the greeting message,
  /// recipient name/phone and the `giftWrap` / `hidePrice` flags are sent.
  final bool isGift;
  final String? giftMessage;
  final String? giftRecipientName;
  final String? giftRecipientPhone;
  final bool giftWrap;
  final bool hidePrice;

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'fulfillmentType': fulfillmentType.wire,
        'paymentMethod': paymentMethod.wire,
        if (address != null) 'address': address!.toJson(),
        if (scheduledFor != null)
          'scheduledFor': scheduledFor!.toUtc().toIso8601String(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (couponCode != null && couponCode!.isNotEmpty) 'couponCode': couponCode,
        if (giftCardCode != null && giftCardCode!.isNotEmpty)
          'giftCardCode': giftCardCode,
        if (pointsToRedeem != null && pointsToRedeem! > 0)
          'pointsToRedeem': pointsToRedeem,
        if (guestFullName != null && guestFullName!.isNotEmpty)
          'guestFullName': guestFullName,
        if (guestPhone != null && guestPhone!.isNotEmpty)
          'guestPhone': guestPhone,
        if (guestEmail != null && guestEmail!.isNotEmpty)
          'guestEmail': guestEmail,
        if (pickupStoreId != null && pickupStoreId!.isNotEmpty)
          'pickupStoreId': pickupStoreId,
        if (deliveryStoreId != null && deliveryStoreId!.isNotEmpty)
          'deliveryStoreId': deliveryStoreId,
        if (requestVatInvoice) ...{
          'requestVatInvoice': true,
          if (invoiceCompanyName != null && invoiceCompanyName!.isNotEmpty)
            'invoiceCompanyName': invoiceCompanyName,
          if (invoiceTaxId != null && invoiceTaxId!.isNotEmpty)
            'invoiceTaxId': invoiceTaxId,
          if (invoiceAddress != null && invoiceAddress!.isNotEmpty)
            'invoiceAddress': invoiceAddress,
          if (invoiceEmail != null && invoiceEmail!.isNotEmpty)
            'invoiceEmail': invoiceEmail,
        },
        if (isGift) ...{
          'isGift': true,
          if (giftMessage != null && giftMessage!.isNotEmpty)
            'giftMessage': giftMessage,
          if (giftRecipientName != null && giftRecipientName!.isNotEmpty)
            'giftRecipientName': giftRecipientName,
          if (giftRecipientPhone != null && giftRecipientPhone!.isNotEmpty)
            'giftRecipientPhone': giftRecipientPhone,
          'giftWrap': giftWrap,
          'hidePrice': hidePrice,
        },
      };
}

/// Returned by `OrderRepository.placeOrder`. The customer UI uses this to
/// either navigate inline (CASH) or redirect to a payment provider.
class PlaceOrderResult extends Equatable {
  const PlaceOrderResult({
    required this.order,
    required this.payment,
    this.guestSession,
  });

  final Order order;
  final PaymentInstructions payment;

  /// Set only when the backend created a brand-new guest user during this
  /// checkout. The UI passes this to `AuthRepository.adoptSession` to
  /// auto-log-in so the customer can view their order and survive a refresh.
  final AuthSession? guestSession;

  @override
  List<Object?> get props => [order, payment, guestSession];
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

  /// Merchant: mark the VAT invoice as issued for [id]. Optional
  /// `invoiceFileUrl` is the PDF link the merchant just generated from
  /// their external invoice provider (e.g. MISA, Easyinvoice).
  Future<Result<Order, AppFailure>> issueInvoice(
    String id, {
    String? invoiceFileUrl,
  });

  // Kitchen-side
  Future<Result<List<Order>, AppFailure>> kitchenQueue({
    KitchenStatus? status,
    bool includeDoneToday,
  });
  Future<Result<Order, AppFailure>> transitionKitchen(
    String id,
    KitchenStatus toKitchenStatus,
  );
  Future<Result<Order, AppFailure>> dispatchFromKitchen(String id);
}
