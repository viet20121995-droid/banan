import 'package:equatable/equatable.dart';

enum RefundStatus {
  requested,
  approved,
  processing,
  completed,
  rejected,
  // Fallback for an unknown status — refunds are embedded in every order, so a
  // single un-mappable refund must not blank the whole order list. Never throws.
  unknown;

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
        return RefundStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case RefundStatus.requested:
        return 'Đã gửi yêu cầu';
      case RefundStatus.approved:
        return 'Đã duyệt';
      case RefundStatus.processing:
        return 'Đang xử lý';
      case RefundStatus.completed:
        return 'Đã hoàn tiền';
      case RefundStatus.rejected:
        return 'Bị từ chối';
      case RefundStatus.unknown:
        return 'Trạng thái khác';
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
