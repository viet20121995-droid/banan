/// Mirrors the backend `OrderStatus` enum exactly. `fromWire` parses the
/// `ALL_CAPS` string from the API.
enum OrderStatus {
  pending,
  accepted,
  inPreparation,
  sentToKitchen,
  readyForPickup,
  delivering,
  completed,
  cancelled,
  refunded;

  static OrderStatus fromWire(String value) {
    switch (value) {
      case 'PENDING':
        return OrderStatus.pending;
      case 'ACCEPTED':
        return OrderStatus.accepted;
      case 'IN_PREPARATION':
        return OrderStatus.inPreparation;
      case 'SENT_TO_KITCHEN':
        return OrderStatus.sentToKitchen;
      case 'READY_FOR_PICKUP':
        return OrderStatus.readyForPickup;
      case 'DELIVERING':
        return OrderStatus.delivering;
      case 'COMPLETED':
        return OrderStatus.completed;
      case 'CANCELLED':
        return OrderStatus.cancelled;
      case 'REFUNDED':
        return OrderStatus.refunded;
      default:
        throw FormatException('Unknown order status: $value');
    }
  }

  String get wire {
    switch (this) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.accepted:
        return 'ACCEPTED';
      case OrderStatus.inPreparation:
        return 'IN_PREPARATION';
      case OrderStatus.sentToKitchen:
        return 'SENT_TO_KITCHEN';
      case OrderStatus.readyForPickup:
        return 'READY_FOR_PICKUP';
      case OrderStatus.delivering:
        return 'DELIVERING';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
      case OrderStatus.refunded:
        return 'REFUNDED';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.inPreparation:
        return 'In preparation';
      case OrderStatus.sentToKitchen:
        return 'Sent to kitchen';
      case OrderStatus.readyForPickup:
        return 'Ready for pickup';
      case OrderStatus.delivering:
        return 'Delivering';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
    }
  }

  bool get isTerminal =>
      this == OrderStatus.completed ||
      this == OrderStatus.cancelled ||
      this == OrderStatus.refunded;

  bool get customerCanCancel =>
      this == OrderStatus.pending || this == OrderStatus.accepted;
}

enum FulfillmentType {
  pickup,
  delivery;

  static FulfillmentType fromWire(String value) =>
      value == 'DELIVERY' ? FulfillmentType.delivery : FulfillmentType.pickup;

  String get wire =>
      this == FulfillmentType.delivery ? 'DELIVERY' : 'PICKUP';
}
