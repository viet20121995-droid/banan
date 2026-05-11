/// Mirrors the backend `KitchenStatus` enum.
enum KitchenStatus {
  preparing,
  baking,
  cooling,
  decorating,
  packed,
  readyDispatch;

  static KitchenStatus fromWire(String value) {
    switch (value) {
      case 'PREPARING':
        return KitchenStatus.preparing;
      case 'BAKING':
        return KitchenStatus.baking;
      case 'COOLING':
        return KitchenStatus.cooling;
      case 'DECORATING':
        return KitchenStatus.decorating;
      case 'PACKED':
        return KitchenStatus.packed;
      case 'READY_DISPATCH':
        return KitchenStatus.readyDispatch;
      default:
        throw FormatException('Unknown kitchen status: $value');
    }
  }

  String get wire {
    switch (this) {
      case KitchenStatus.preparing:
        return 'PREPARING';
      case KitchenStatus.baking:
        return 'BAKING';
      case KitchenStatus.cooling:
        return 'COOLING';
      case KitchenStatus.decorating:
        return 'DECORATING';
      case KitchenStatus.packed:
        return 'PACKED';
      case KitchenStatus.readyDispatch:
        return 'READY_DISPATCH';
    }
  }

  String get label {
    switch (this) {
      case KitchenStatus.preparing:
        return 'Preparing';
      case KitchenStatus.baking:
        return 'Baking';
      case KitchenStatus.cooling:
        return 'Cooling';
      case KitchenStatus.decorating:
        return 'Decorating';
      case KitchenStatus.packed:
        return 'Packed';
      case KitchenStatus.readyDispatch:
        return 'Ready to dispatch';
    }
  }

  /// Forward state-machine successor — null on the terminal `readyDispatch`.
  KitchenStatus? get next {
    switch (this) {
      case KitchenStatus.preparing:
        return KitchenStatus.baking;
      case KitchenStatus.baking:
        return KitchenStatus.cooling;
      case KitchenStatus.cooling:
        return KitchenStatus.decorating;
      case KitchenStatus.decorating:
        return KitchenStatus.packed;
      case KitchenStatus.packed:
        return KitchenStatus.readyDispatch;
      case KitchenStatus.readyDispatch:
        return null;
    }
  }

  /// Order in which columns appear on the kanban (left to right).
  static const orderedColumns = [
    KitchenStatus.preparing,
    KitchenStatus.baking,
    KitchenStatus.cooling,
    KitchenStatus.decorating,
    KitchenStatus.packed,
    KitchenStatus.readyDispatch,
  ];
}
