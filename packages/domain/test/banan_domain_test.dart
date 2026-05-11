import 'package:banan_domain/banan_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Role.fromWire', () {
    test('parses every server-side role string', () {
      expect(Role.fromWire('CUSTOMER'), Role.customer);
      expect(Role.fromWire('MERCHANT_OWNER'), Role.merchantOwner);
      expect(Role.fromWire('MERCHANT_STAFF'), Role.merchantStaff);
      expect(Role.fromWire('KITCHEN_MANAGER'), Role.kitchenManager);
      expect(Role.fromWire('KITCHEN_STAFF'), Role.kitchenStaff);
      expect(Role.fromWire('ADMIN'), Role.admin);
    });

    test('isMerchant / isKitchen / isCustomer / isAdmin partitions cleanly', () {
      expect(Role.merchantOwner.isMerchant, isTrue);
      expect(Role.merchantOwner.isKitchen, isFalse);
      expect(Role.kitchenStaff.isKitchen, isTrue);
      expect(Role.customer.isCustomer, isTrue);
      expect(Role.admin.isAdmin, isTrue);
    });

    test('throws on unknown wire value', () {
      expect(() => Role.fromWire('UNKNOWN'), throwsFormatException);
    });
  });

  group('OrderStatus', () {
    test('round-trips wire value', () {
      for (final s in OrderStatus.values) {
        expect(OrderStatus.fromWire(s.wire), s);
      }
    });

    test('terminal statuses are flagged', () {
      expect(OrderStatus.completed.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
      expect(OrderStatus.refunded.isTerminal, isTrue);
      expect(OrderStatus.pending.isTerminal, isFalse);
    });

    test('only PENDING and ACCEPTED allow customer self-cancel', () {
      expect(OrderStatus.pending.customerCanCancel, isTrue);
      expect(OrderStatus.accepted.customerCanCancel, isTrue);
      expect(OrderStatus.inPreparation.customerCanCancel, isFalse);
      expect(OrderStatus.completed.customerCanCancel, isFalse);
    });
  });
}
