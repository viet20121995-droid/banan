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
      expect(Role.fromWire('TRAINEE'), Role.trainee);
    });

    test('isMerchant / isKitchen / isCustomer / isAdmin partitions cleanly', () {
      expect(Role.merchantOwner.isMerchant, isTrue);
      expect(Role.merchantOwner.isKitchen, isFalse);
      expect(Role.kitchenStaff.isKitchen, isTrue);
      expect(Role.customer.isCustomer, isTrue);
      expect(Role.admin.isAdmin, isTrue);
      expect(Role.trainee.isTrainee, isTrue);
      expect(Role.trainee.isAdmin, isFalse);
      expect(Role.trainee.isMerchant, isFalse);
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

  group('ProductOptionGroup.sizes', () {
    const cake = ProductOptionGroup(
      label: 'Bánh',
      choices: ['Mango Shortcake', 'Strawberry Shortcake'],
      sizes: ['Set 3'],
    );
    const sugar = ProductOptionGroup(label: 'Đường', choices: ['Ít', 'Vừa']);

    test('a sized group applies only to its sizes; an unsized one to all', () {
      expect(cake.appliesTo('Set 3'), isTrue);
      expect(cake.appliesTo('Set 1'), isFalse);
      expect(cake.appliesTo(null), isFalse);
      expect(sugar.appliesTo('Set 1'), isTrue);
      expect(sugar.appliesTo(null), isTrue);
    });

    test('JSON round-trip keeps sizes and omits them when empty', () {
      expect(ProductOptionGroup.fromJson(cake.toJson()), cake);
      expect(sugar.toJson().containsKey('sizes'), isFalse);
      expect(
        ProductOptionGroup.fromJson(const {'label': 'Đá', 'choices': ['Ít', 'Vừa']}).sizes,
        isEmpty,
      );
    });
  });
}
