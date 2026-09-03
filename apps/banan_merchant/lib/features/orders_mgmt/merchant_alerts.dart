import 'package:banan_data/banan_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays the new-order chime. Defaults to a no-op so this file (and the
/// alert rule below) stays free of web-only code; `main.dart` overrides it
/// with the WebAudio chime.
final merchantChimeProvider = Provider<void Function()>((_) => () {});

/// Realtime events that mean "something new needs the counter's attention":
/// a brand-new order, or an online (9Pay) order that just got paid.
bool isNewMerchantOrderEvent(RealtimeEvent event) =>
    event.event == 'order.created' || event.event == 'order.payment_captured';

/// App-wide alert: chimes on every new order no matter which screen the
/// merchant is on (menu, reports, …). NOT autoDispose — watched once from the
/// app root; the orders list controller is disposed on other pages and used
/// to be the only thing that rang.
final merchantAlertsProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<RealtimeEvent>>(realtimeEventsProvider, (_, next) {
    next.whenData((event) {
      if (isNewMerchantOrderEvent(event)) ref.read(merchantChimeProvider)();
    });
  });
});
