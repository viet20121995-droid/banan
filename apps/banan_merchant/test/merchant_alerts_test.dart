import 'package:banan_data/banan_data.dart';
import 'package:banan_merchant/features/orders_mgmt/merchant_alerts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RealtimeEvent ev(String name, Map<String, dynamic> data) =>
      RealtimeEvent(event: name, data: data);

  test('web orders and captured payments ring the counter', () {
    expect(isNewMerchantOrderEvent(ev('order.created', {'source': 'WEB'})),
        isTrue);
    expect(isNewMerchantOrderEvent(ev('order.created', {})), isTrue);
    expect(isNewMerchantOrderEvent(ev('order.payment_captured', {})), isTrue);
  });

  test('orders the staff keyed themselves stay silent', () {
    expect(
      isNewMerchantOrderEvent(ev('order.created', {'source': 'STAFF_COUNTER'})),
      isFalse,
    );
    expect(
      isNewMerchantOrderEvent(
        ev('order.created', {'source': 'INTERNAL_TRANSFER'}),
      ),
      isFalse,
    );
    expect(isNewMerchantOrderEvent(ev('order.status_changed', {})), isFalse);
  });
}
