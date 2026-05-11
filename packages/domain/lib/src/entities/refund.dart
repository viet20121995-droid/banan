import 'package:equatable/equatable.dart';

enum RefundStatus {
  requested,
  approved,
  processing,
  completed,
  rejected;

  static RefundStatus fromWire(String value) {
    switch (value) {
      case 'REQUESTED':
        return RefundStatus.requested;
      case 'APPROVED':
        return RefundStatus.approved;
      case 'PROCESSING':
        return RefundStatus.processing;
      case 'COMPLETED':
        return RefundStatus.completed;
      case 'REJECTED':
        return RefundStatus.rejected;
      default:
        throw FormatException('Unknown refund status: $value');
    }
  }

  String get label {
    switch (this) {
      case RefundStatus.requested:
        return 'Refund requested';
      case RefundStatus.approved:
        return 'Refund approved';
      case RefundStatus.processing:
        return 'Refund processing';
      case RefundStatus.completed:
        return 'Refunded';
      case RefundStatus.rejected:
        return 'Refund rejected';
    }
  }

  bool get isTerminal =>
      this == RefundStatus.completed || this == RefundStatus.rejected;
}

class Refund extends Equatable {
  const Refund({
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

  final String id;
  final String orderId;
  final String? paymentId;
  final double amount;
  final String reason;
  final RefundStatus status;
  final String? providerRef;
  final String? requestedById;
  final String? approvedById;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        orderId,
        paymentId,
        amount,
        reason,
        status,
        providerRef,
        requestedById,
        approvedById,
        createdAt,
        updatedAt,
      ];
}
