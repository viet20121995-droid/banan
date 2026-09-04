import 'package:banan_data/banan_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays the new-ticket chime. Defaults to a no-op so this file (and the
/// alert rule below) stays free of web-only code; `main.dart` overrides it
/// with the WebAudio chime.
final kitchenChimeProvider = Provider<void Function()>((_) => () {});

/// Realtime events that mean "a new ticket just landed in this kitchen".
///   - a web order the merchant transferred → status_changed to SENT_TO_KITCHEN
///   - a counter / internal-transfer order created straight onto the board
///     → order.created with status SENT_TO_KITCHEN
bool isNewKitchenTicket(RealtimeEvent event) {
  final data = event.data;
  switch (event.event) {
    case 'order.status_changed':
    case 'order.kitchen_status_changed':
      return data['toStatus'] == 'SENT_TO_KITCHEN';
    case 'order.created':
      return data['status'] == 'SENT_TO_KITCHEN';
    default:
      return false;
  }
}

/// Whether the board should refetch after this event.
bool isKitchenBoardEvent(RealtimeEvent event) =>
    event.event == RealtimeEvent.reconnected ||
    event.event == 'order.status_changed' ||
    event.event == 'order.kitchen_status_changed' ||
    (event.event == 'order.created' &&
        event.data['status'] == 'SENT_TO_KITCHEN');

/// App-wide alert: chimes on every new ticket no matter which screen the
/// staff is on. NOT autoDispose — it is watched once from the app root and
/// lives for the whole session (the board's own controller is disposed the
/// moment staff open another page, which used to silence the chime).
final kitchenAlertsProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (isNewKitchenTicket(event)) ref.read(kitchenChimeProvider)();
    });
  });
});
