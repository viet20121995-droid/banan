import 'dart:async';

import 'package:banan_data/banan_data.dart';
import 'package:banan_merchant/features/orders_mgmt/merchant_alerts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

RealtimeEvent _ev(String name, [Map<String, dynamic> data = const {}]) =>
    RealtimeEvent(event: name, data: data);

void main() {
  test('new orders and captured online payments ring; status changes do not', () {
    expect(isNewMerchantOrderEvent(_ev('order.created')), isTrue);
    expect(isNewMerchantOrderEvent(_ev('order.payment_captured')), isTrue);
    expect(isNewMerchantOrderEvent(_ev('order.status_changed')), isFalse);
    expect(isNewMerchantOrderEvent(_ev('order.due_soon')), isFalse);
  });

  test('merchantAlertsProvider chimes app-wide, once per event', () async {
    final events = StreamController<RealtimeEvent>();
    var chimes = 0;
    final container = ProviderContainer(
      overrides: [
        realtimeEventsProvider.overrideWith((_) => events.stream),
        merchantChimeProvider.overrideWithValue(() => chimes++),
      ],
    );
    addTearDown(container.dispose);
    container.read(merchantAlertsProvider);

    events
      ..add(_ev('order.created'))
      ..add(_ev('order.status_changed'))
      ..add(_ev('order.payment_captured'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(chimes, 2);
    await events.close();
  });
}
