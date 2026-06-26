/// Mirrors the backend `KitchenStatus` enum.
///
/// Simplified 3-stage workflow (M11 trim-down from the original 6-stage one):
/// orders enter at [pendingAck] when the merchant transfers them, kitchen
/// staff explicitly accept into [preparing], then mark them [readyDispatch]
/// when finished. The kitchen UI shows a 4-column kanban with a virtual
/// "Completed" column populated from today's dispatched orders.
enum KitchenStatus {
  pendingAck,
  preparing,
  readyDispatch,
  // Fallback for a stage this client build doesn't know (the kitchen workflow
  // has changed before). Never throws; excluded from [orderedColumns] and has no
  // [next], so an unfamiliar stage degrades quietly instead of blanking the
  // whole kanban.
  unknown;

  static KitchenStatus fromWire(String value) {
    switch (value) {
      case 'PENDING_ACK':
        return KitchenStatus.pendingAck;
      case 'PREPARING':
        return KitchenStatus.preparing;
      case 'READY_DISPATCH':
        return KitchenStatus.readyDispatch;
      default:
        return KitchenStatus.unknown;
    }
  }

  String get wire {
    switch (this) {
      case KitchenStatus.pendingAck:
        return 'PENDING_ACK';
      case KitchenStatus.preparing:
        return 'PREPARING';
      case KitchenStatus.readyDispatch:
        return 'READY_DISPATCH';
      case KitchenStatus.unknown:
        return 'UNKNOWN';
    }
  }

  String get label {
    switch (this) {
      case KitchenStatus.pendingAck:
        return 'Chờ nhận';
      case KitchenStatus.preparing:
        return 'Đang chuẩn bị';
      case KitchenStatus.readyDispatch:
        return 'Sẵn sàng giao';
      case KitchenStatus.unknown:
        return 'Khác';
    }
  }

  /// Forward state-machine successor — null on the terminal `readyDispatch`.
  KitchenStatus? get next {
    switch (this) {
      case KitchenStatus.pendingAck:
        return KitchenStatus.preparing;
      case KitchenStatus.preparing:
        return KitchenStatus.readyDispatch;
      case KitchenStatus.readyDispatch:
        return null;
      case KitchenStatus.unknown:
        return null;
    }
  }

  /// Order in which active-kitchen columns appear on the kanban (left to
  /// right). The "Completed" column is rendered separately because it shows
  /// orders that have left this kitchen.
  static const orderedColumns = [
    KitchenStatus.pendingAck,
    KitchenStatus.preparing,
    KitchenStatus.readyDispatch,
  ];
}
