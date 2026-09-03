import 'dart:async';
import 'dart:math';

/// Keep reports useful without persisting order-tracking capabilities or
/// producing one top-page row per product/order id.
String normalizeAnalyticsPath(String raw) {
  final path = raw.split('?').first.split('#').first;
  for (final prefix in ['track', 'orders', 'product', 'bundles']) {
    if (RegExp('^/$prefix/[^/]+').hasMatch(path)) return '/$prefix/:id';
  }
  return path;
}

/// The pure part — batching, scroll-depth max, flush cadence — kept free of
/// Flutter/Dio so it can be unit tested with a fake sender and clock.
class AnalyticsQueue {
  AnalyticsQueue({
    required this.send,
    required this.visitorId,
    this.maxBatch = 25,
    this.flushEvery = const Duration(seconds: 8),
    String? sessionId,
  }) : sessionId = sessionId ?? _randomId();

  final Future<void> Function(Map<String, dynamic> batch) send;
  final int maxBatch;
  final Duration flushEvery;
  final String visitorId;
  final String sessionId;

  final List<Map<String, dynamic>> _pending = [];
  String _path = '/';
  int _maxScrollPct = 0;
  bool _started = false;
  Timer? _timer;

  static String _randomId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return List.generate(20, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  int get pendingCount => _pending.length;

  void start({required String device, required String referrer}) {
    if (_started) return;
    _started = true;
    _push({
      'type': 'session_start',
      'path': _path,
      'device': device,
      'referrer': referrer,
    });
    _timer = Timer.periodic(flushEvery, (_) => flush());
  }

  void dispose() => _timer?.cancel();

  /// A route change: close the previous page (its max scroll depth) and
  /// open the new one. Same path twice in a row is not a new view.
  void pageView(String path) {
    final normalizedPath = normalizeAnalyticsPath(path);
    // GoRouter reports an empty uri before its first navigation — not a page.
    if (normalizedPath.isEmpty) return;
    if (normalizedPath == _path &&
        _pending.any((e) => e['type'] == 'page_view')) {
      return;
    }
    _closeScroll();
    _path = normalizedPath;
    _maxScrollPct = 0;
    _push({'type': 'page_view', 'path': normalizedPath});
  }

  /// [fraction] 0..1 of the page reached; only the max per page is reported.
  void scroll(double fraction) {
    final pct = (fraction.clamp(0, 1) * 100).round();
    if (pct > _maxScrollPct) _maxScrollPct = pct;
  }

  void click() => _push({'type': 'click', 'path': _path});

  void event(String type, {String? label}) =>
      _push({'type': type, 'path': _path, if (label != null) 'label': label});

  void _closeScroll() {
    if (_maxScrollPct <= 0) return;
    _push({'type': 'scroll', 'path': _path, 'value': _maxScrollPct});
    _maxScrollPct = 0;
  }

  void _push(Map<String, dynamic> e) {
    _pending.add(e);
    if (_pending.length >= maxBatch) unawaited(flush());
  }

  /// Sends up to [maxBatch] queued events; the scroll depth of the current
  /// page is included so a closed tab still reports what it reached.
  Future<void> flush({bool closingPage = false}) async {
    if (closingPage) _closeScroll();
    if (_pending.isEmpty) return;
    final batch = _pending.take(maxBatch).toList();
    _pending.removeRange(0, batch.length);
    try {
      await send({
        'visitorId': visitorId,
        'sessionId': sessionId,
        'events': batch,
      });
    } catch (_) {
      // Dropped on purpose — analytics must never surface to the customer.
    }
  }
}
