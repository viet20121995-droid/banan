import 'package:banan_data/banan_data.dart';
import 'package:flutter/foundation.dart';

import 'analytics_env.dart' as env;
import 'analytics_queue.dart';

export 'analytics_queue.dart';

/// "Hotjar-lite" behaviour beacon for the storefront: page views, max scroll
/// depth per page, clicks and the shopping funnel (add to cart → checkout →
/// order placed), batched to `POST /metrics/events` every few seconds and
/// summarised in the daily traffic email. Anonymous — the same random
/// visitor id the visit beacon uses, plus a per-tab session id. Never
/// throws and never blocks the UI: a failed batch is simply dropped.
class Analytics {
  Analytics._();

  static AnalyticsQueue? _queue;

  /// Call once at launch (web only): records the session start with device
  /// class + traffic source, and starts the periodic flush.
  static void start() {
    if (!kIsWeb || _queue != null) return;
    final queue = AnalyticsQueue(
      send: (batch) =>
          createDioClient().post<void>('/metrics/events', data: batch),
      visitorId: env.visitorId(),
    );
    _queue = queue;
    queue.start(
      device: env.deviceClass(),
      referrer: env.trafficSource(),
    );
  }

  static void pageView(String path) => _queue?.pageView(path);
  static void scroll(double fraction) => _queue?.scroll(fraction);
  static void click() => _queue?.click();
  static void addToCart(String label) =>
      _queue?.event('add_to_cart', label: label);
  static void checkout() => _queue?.event('checkout');
  static void orderPlaced() => _queue?.event('order_placed');
}
