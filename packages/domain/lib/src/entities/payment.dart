import 'package:equatable/equatable.dart';

/// Payment method chosen at checkout. Mirrors the backend `PaymentProvider`
/// enum exactly so wire (de)serialization is trivial.
enum PaymentMethod {
  cash,
  stripe,
  vnpay,
  momo;

  static PaymentMethod fromWire(String value) {
    switch (value) {
      case 'CASH':
        return PaymentMethod.cash;
      case 'STRIPE':
        return PaymentMethod.stripe;
      case 'VNPAY':
        return PaymentMethod.vnpay;
      case 'MOMO':
        return PaymentMethod.momo;
      default:
        throw FormatException('Unknown payment method: $value');
    }
  }

  String get wire {
    switch (this) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.stripe:
        return 'STRIPE';
      case PaymentMethod.vnpay:
        return 'VNPAY';
      case PaymentMethod.momo:
        return 'MOMO';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash on pickup';
      case PaymentMethod.stripe:
        return 'Card · Stripe';
      case PaymentMethod.vnpay:
        return 'VNPay';
      case PaymentMethod.momo:
        return 'MoMo';
    }
  }

  /// Cash has special UX (no redirect), and is only available for pickup.
  bool get requiresRedirect => this != PaymentMethod.cash;
}

enum PaymentStatus {
  initiated,
  authorized,
  captured,
  failed,
  voided,
  refunded;

  static PaymentStatus fromWire(String value) {
    switch (value) {
      case 'INITIATED':
        return PaymentStatus.initiated;
      case 'AUTHORIZED':
        return PaymentStatus.authorized;
      case 'CAPTURED':
        return PaymentStatus.captured;
      case 'FAILED':
        return PaymentStatus.failed;
      case 'VOIDED':
        return PaymentStatus.voided;
      case 'REFUNDED':
        return PaymentStatus.refunded;
      default:
        throw FormatException('Unknown payment status: $value');
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.initiated:
        return 'Awaiting payment';
      case PaymentStatus.authorized:
        return 'Pay at pickup';
      case PaymentStatus.captured:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Payment failed';
      case PaymentStatus.voided:
        return 'Payment voided';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}

class PaymentSummary extends Equatable {
  const PaymentSummary({
    required this.id,
    required this.provider,
    required this.status,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final PaymentMethod provider;
  final PaymentStatus status;
  final double amount;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, provider, status, amount, createdAt];
}

/// Result of placing an order — provider-specific payment instructions.
class PaymentInstructions extends Equatable {
  const PaymentInstructions({
    required this.provider,
    required this.paymentId,
    this.payAtPickup = false,
    this.redirectUrl,
    this.clientSecret,
    this.configurationError,
  });

  final PaymentMethod provider;
  final String paymentId;
  final bool payAtPickup;
  final String? redirectUrl;
  final String? clientSecret;
  final String? configurationError;

  bool get hasRedirect => redirectUrl != null && redirectUrl!.isNotEmpty;

  @override
  List<Object?> get props =>
      [provider, paymentId, payAtPickup, redirectUrl, clientSecret, configurationError];
}
