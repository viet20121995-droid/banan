import 'dart:async';

import 'package:banan_data/banan_data.dart';
import 'package:banan_kitchen/features/kanban/kitchen_alerts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

RealtimeEvent _ev(String name, Map<String, dynamic> data) =>
    RealtimeEvent(event: name, data: data);

void main() {
  group('isNewKitchenTicket', () {
    test('a merchant transfer (status_changed → SENT_TO_KITCHEN) rings', () {
      expect(
        isNewKitchenTicket(_ev('order.status_changed', {'toStatus': 'SENT_TO_KITCHEN'})),
        isTrue,
      );
      expect(
        isNewKitchenTicket(_ev('order.status_changed', {'toStatus': 'COMPLETED'})),
        isFalse,
      );
    });

    test('a counter / internal-transfer order created straight onto the board rings',
        () {
      expect(
        isNewKitchenTicket(_ev('order.created', {'status': 'SENT_TO_KITCHEN'})),
        isTrue,
      );
      // A web order created at the store (PENDING) is not the kitchen's yet.
      expect(isNewKitchenTicket(_ev('order.created', {'status': 'PENDING'})), isFalse);
      expect(isNewKitchenTicket(_ev('order.payment_captured', {})), isFalse);
    });

    test('board refetch covers the same events plus kitchen stage changes', () {
      expect(
        isKitchenBoardEvent(_ev('order.kitchen_status_changed', {'toStatus': 'PREPARING'})),
        isTrue,
      );
      expect(isKitchenBoardEvent(_ev('order.created', {'status': 'PENDING'})), isFalse);
    });
  });

  test('kitchenAlertsProvider chimes once per new ticket, on any screen', () async {
    final events = StreamController<RealtimeEvent>();
    var chimes = 0;
    final container = ProviderContainer(
      overrides: [
        realtimeEventsProvider.overrideWith((_) => events.stream),
        kitchenChimeProvider.overrideWithValue(() => chimes++),
      ],
    );
    addTearDown(container.dispose);
    container.read(kitchenAlertsProvider); // the app root "watches" it once

    events
      ..add(_ev('order.created', {'status': 'SENT_TO_KITCHEN'}))
      ..add(_ev('order.status_changed', {'toStatus': 'SENT_TO_KITCHEN'}))
      ..add(_ev('order.kitchen_status_changed', {'toStatus': 'PREPARING'}));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(chimes, 2);
    await events.close();
  });
}
