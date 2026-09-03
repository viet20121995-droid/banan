import 'package:banan_customer/app/analytics_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Map<String, dynamic>> sent;
  late AnalyticsQueue q;

  setUp(() {
    sent = [];
    q = AnalyticsQueue(
      send: (b) async => sent.add(b),
      visitorId: 'visitor-1234567890',
      sessionId: 'session-1234567890',
      flushEvery: const Duration(hours: 1), // never fires in these tests
    );
  });

  tearDown(() => q.dispose());

  test('session start + page views + funnel events queue with the current path',
      () async {
    q
      ..start(device: 'mobile', referrer: 'facebook.com')
      ..pageView('/')
      ..pageView('/product/abc')
      ..event('add_to_cart', label: 'Mousse');
    await q.flush();
    expect(sent, hasLength(1));
    expect(sent.single['visitorId'], 'visitor-1234567890');
    final events = (sent.single['events'] as List).cast<Map<String, dynamic>>();
    expect(
      events.map((e) => e['type']),
      ['session_start', 'page_view', 'page_view', 'add_to_cart'],
    );
    expect(events[0]['device'], 'mobile');
    expect(events[0]['referrer'], 'facebook.com');
    expect(events.last['path'], '/product/:id');
    expect(events.last['label'], 'Mousse');
  });

  test(
    'an empty path (router before first navigation) is not a page view',
    () async {
      q
        ..pageView('')
        ..pageView('/');
      await q.flush();
      final events =
          (sent.single['events'] as List).cast<Map<String, dynamic>>();
      expect(events.map((e) => e['path']), ['/']);
    },
  );

  test(
      'dynamic route ids, including public tracking capabilities, are never queued',
      () async {
    q
      ..pageView('/track/secret-order-id?utm=x')
      ..pageView('/product/product-uuid');
    await q.flush();
    final events = (sent.single['events'] as List).cast<Map<String, dynamic>>();
    expect(events.map((e) => e['path']), ['/track/:id', '/product/:id']);
  });

  test('only the max scroll depth of a page is reported, when the page closes',
      () async {
    q
      ..pageView('/')
      ..scroll(0.3)
      ..scroll(0.8)
      ..scroll(0.5)
      ..pageView('/faq'); // closes "/" → one scroll event with 80
    await q.flush();
    final events = (sent.single['events'] as List).cast<Map<String, dynamic>>();
    final scrolls = events.where((e) => e['type'] == 'scroll').toList();
    expect(scrolls, hasLength(1));
    expect(scrolls.single['path'], '/');
    expect(scrolls.single['value'], 80);
  });

  test('flush(closingPage) reports the open page before a tab closes',
      () async {
    q
      ..pageView('/product/x')
      ..scroll(1);
    await q.flush(closingPage: true);
    final events = (sent.single['events'] as List).cast<Map<String, dynamic>>();
    expect(
      events.last,
      {'type': 'scroll', 'path': '/product/:id', 'value': 100},
    );
  });

  test('batches are capped and a failed send never throws', () async {
    for (var i = 0; i < 30; i++) {
      q.click();
    }
    // 25 auto-flushed at the cap, 5 still pending.
    await Future<void>.delayed(Duration.zero);
    expect(sent.single['events'], hasLength(25));
    expect(q.pendingCount, 5);

    final failing = AnalyticsQueue(
      send: (_) async => throw Exception('offline'),
      visitorId: 'visitor-1234567890',
      sessionId: 'session-1234567890',
    );
    await expectLater((failing..click()).flush(), completes);
    failing.dispose();
  });
}
