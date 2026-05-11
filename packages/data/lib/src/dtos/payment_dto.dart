import 'package:banan_domain/banan_domain.dart';

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class PaymentDto {
  const PaymentDto({
    required this.id,
    required this.provider,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAt,
  });

  factory PaymentDto.fromJson(Map<String, dynamic> json) {
    return PaymentDto(
      id: json['id'] as String,
      provider: json['provider'] as String,
      status: json['status'] as String,
      amount: _toDouble(json['amount']),
      currency: json['currency'] as String? ?? 'VND',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String provider;
  final String status;
  final double amount;
  final String currency;
  final DateTime createdAt;

  PaymentSummary toDomain() => PaymentSummary(
        id: id,
        provider: PaymentMethod.fromWire(provider),
        status: PaymentStatus.fromWire(status),
        amount: amount,
        createdAt: createdAt,
      );
}

class PaymentInstructionsDto {
  const PaymentInstructionsDto({
    required this.provider,
    required this.paymentId,
    this.payAtPickup = false,
    this.redirectUrl,
    this.clientSecret,
    this.configurationError,
  });

  factory PaymentInstructionsDto.fromJson(Map<String, dynamic> json) {
    return PaymentInstructionsDto(
      provider: json['provider'] as String,
      paymentId: json['paymentId'] as String? ?? '',
      payAtPickup: json['payAtPickup'] as bool? ?? false,
      redirectUrl: json['redirectUrl'] as String?,
      clientSecret: json['clientSecret'] as String?,
      configurationError: json['configurationError'] as String?,
    );
  }

  final String provider;
  final String paymentId;
  final bool payAtPickup;
  final String? redirectUrl;
  final String? clientSecret;
  final String? configurationError;

  PaymentInstructions toDomain() => PaymentInstructions(
        provider: PaymentMethod.fromWire(provider),
        paymentId: paymentId,
        payAtPickup: payAtPickup,
        redirectUrl: redirectUrl,
        clientSecret: clientSecret,
        configurationError: configurationError,
      );
}
