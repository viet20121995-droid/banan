import 'package:banan_data/src/dtos/order_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _minimalJson({Map<String, dynamic>? customer}) => {
      'id': 'o1',
      'code': 'BAN-2026-TEST',
      'customerId': 'u1',
      'storeId': 's1',
      'fulfillmentType': 'PICKUP',
      'status': 'PENDING',
      'subtotal': '100000',
      'deliveryFee': '0',
      'total': '100000',
      'createdAt': '2026-08-12T03:07:00.000Z',
      'updatedAt': '2026-08-12T03:07:00.000Z',
      if (customer != null) 'customer': customer,
    };

void main() {
  test('parses orderer contact from the customer include', () {
    final order = OrderDto.fromJson(
      _minimalJson(
        customer: {
          'fullName': 'Nguyễn Văn A',
          'phone': '0901234567',
          'email': 'a@gmail.com',
        },
      ),
    ).toDomain();
    expect(order.customerName, 'Nguyễn Văn A');
    expect(order.customerPhone, '0901234567');
    expect(order.customerEmail, 'a@gmail.com');
  });

  test('synthetic guest @banan.local email is hidden (null)', () {
    final order = OrderDto.fromJson(
      _minimalJson(
        customer: {
          'fullName': 'Guest',
          'phone': '0900000001',
          'email': 'guest+0900000001@banan.local',
        },
      ),
    ).toDomain();
    expect(order.customerEmail, isNull);
    expect(order.customerPhone, '0900000001');
  });

  test('payload without customer include stays null (public track link)', () {
    final order = OrderDto.fromJson(_minimalJson()).toDomain();
    expect(order.customerName, isNull);
    expect(order.customerPhone, isNull);
    expect(order.customerEmail, isNull);
  });

  test('TransferMfgItemDto carries the drink-ingredient flag', () {
    final dto = TransferMfgItemDto.fromJson({
      'id': 'l1',
      'mfgProductId': 'm1',
      'qty': '2',
      'mfgProduct': {
        'code': 'DS-HC-004-2-G',
        'nameVi': 'Jam_Strawberry',
        'drinkIngredient': true,
        'uom': {'code': 'g'},
      },
    });
    expect(dto.isDrinkIngredient, isTrue);
    expect(dto.toDomain().isDrinkIngredient, isTrue);
    // Older payloads without the flag are plain supplies.
    expect(
      TransferMfgItemDto.fromJson({'id': 'l2', 'mfgProductId': 'm2', 'qty': 1})
          .isDrinkIngredient,
      isFalse,
    );
  });
}
