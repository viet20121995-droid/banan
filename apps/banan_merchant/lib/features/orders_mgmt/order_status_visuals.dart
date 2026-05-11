import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_domain/banan_domain.dart';

StatusIntent intentForStatus(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return StatusIntent.warning;
    case OrderStatus.accepted:
    case OrderStatus.inPreparation:
    case OrderStatus.sentToKitchen:
      return StatusIntent.progress;
    case OrderStatus.readyForPickup:
    case OrderStatus.delivering:
      return StatusIntent.info;
    case OrderStatus.completed:
      return StatusIntent.success;
    case OrderStatus.cancelled:
    case OrderStatus.refunded:
      return StatusIntent.danger;
  }
}
