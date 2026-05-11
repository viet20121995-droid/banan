import 'package:banan_domain/banan_domain.dart';

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class RefundDto {
  const RefundDto({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paymentId,
    this.providerRef,
    this.requestedById,
    this.approvedById,
  });

  factory RefundDto.fromJson(Map<String, dynamic> json) {
    return RefundDto(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      paymentId: json['paymentId'] as String?,
      amount: _toDouble(json['amount']),
      reason: json['reason'] as String,
      status: json['status'] as String,
      providerRef: json['providerRef'] as String?,
      requestedById: json['requestedById'] as String?,
      approvedById: json['approvedById'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String orderId;
  final String? paymentId;
  final double amount;
  final String reason;
  final String status;
  final String? providerRef;
  final String? requestedById;
  final String? approvedById;
  final DateTime createdAt;
  final DateTime updatedAt;

  Refund toDomain() => Refund(
        id: id,
        orderId: orderId,
        paymentId: paymentId,
        amount: amount,
        reason: reason,
        status: RefundStatus.fromWire(status),
        providerRef: providerRef,
        requestedById: requestedById,
        approvedById: approvedById,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
