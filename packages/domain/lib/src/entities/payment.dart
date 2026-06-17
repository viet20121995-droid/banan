import 'package:equatable/equatable.dart';

/// Payment method chosen at checkout. Mirrors the backend `PaymentProvider`
/// enum exactly so wire (de)serialization is trivial.
enum PaymentMethod {
  cash,
  stripe,
  payos,
  momo;

  static PaymentMethod fromWire(String value) {
    switch (value) {
      case 'CASH':
        return PaymentMethod.cash;
      case 'STRIPE':
        return PaymentMethod.stripe;
      case 'PAYOS':
      case 'VNPAY': // legacy rows (VNPay was replaced by PayOS)
        return PaymentMethod.payos;
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
      case PaymentMethod.payos:
        return 'PAYOS';
      case PaymentMethod.momo:
        return 'MOMO';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tiền mặt khi nhận hàng';
      case PaymentMethod.stripe:
        return 'Thẻ quốc tế · Stripe';
      case PaymentMethod.payos:
        return 'PayOS · QR / Chuyển khoản';
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
        return 'Chờ thanh toán';
      case PaymentStatus.authorized:
        return 'Trả khi nhận hàng';
      case PaymentStatus.captured:
        return 'Đã thanh toán';
      case PaymentStatus.failed:
        return 'Thanh toán thất bại';
      case PaymentStatus.voided:
        return 'Đã huỷ thanh toán';
      case PaymentStatus.refunded:
        return 'Đã hoàn tiền';
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
