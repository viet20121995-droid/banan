import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:banan_data/src/dtos/order_dto.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../tool/receipt_demo.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  testWidgets('capture includes the entire long receipt as a PNG',
      (tester) async {
    Uint8List? png;
    String? filename;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderReceipt(
              order: OrderDto.fromJson(demoOrderJson(count: 24)).toDomain(),
              saveImage: (bytes, name) {
                png = bytes;
                filename = name;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Chụp hóa đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chụp hóa đơn'));
    await tester.pump();
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && png == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(png, isNotNull);
      expect(filename, 'Banan-BAN-DEMO-001.png');
      expect(png!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(png!);
      final frame = await codec.getNextFrame();
      expect(frame.image.height, greaterThan(3000));
      expect(frame.image.width, greaterThan(300));
      frame.image.dispose();
      codec.dispose();
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('only server-confirmed full capture is labelled paid', () {
    for (final status in [
      'INITIATED',
      'AUTHORIZED',
      'FAILED',
      'VOIDED',
      'REFUNDED',
    ]) {
      expect(
          receiptIsPaid(
              OrderDto.fromJson(demoOrderJson(status: status)).toDomain(),),
          isFalse,);
    }
    expect(
        receiptIsPaid(OrderDto.fromJson(demoOrderJson()).toDomain()), isTrue,);
    final partial = demoOrderJson();
    ((partial['payments'] as List).first as Map<String, dynamic>)['amount'] =
        1000;
    expect(receiptIsPaid(OrderDto.fromJson(partial).toDomain()), isFalse);
    final cancelled = demoOrderJson()..['status'] = 'CANCELLED';
    expect(receiptIsPaid(OrderDto.fromJson(cancelled).toDomain()), isFalse);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('receipt fits at $width, including long order and discounts',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderReceipt(
                  order: OrderDto.fromJson(
                          demoOrderJson(count: 24, discounts: true),)
                      .toDomain(),),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Mã giảm giá'), findsOneWidget);
      expect(find.text('Phí giao hàng'), findsOneWidget);
      await tester.ensureVisible(find.text('Chụp hóa đơn'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('delayed capture refreshes the guest receipt without login',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderReceipt(
              order: OrderDto.fromJson(demoOrderJson(status: 'INITIATED'))
                  .toDomain(),
              reload: () async {
                calls++;
                return OrderDto.fromJson(demoOrderJson()).toDomain();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Chưa thanh toán'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Đã thanh toán'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    expect(calls, 1);
  });

  testWidgets('counter form creates demo order and opens capturable receipt',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ReceiptDemo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Signature Strawberry Cake'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    for (final field in fields.evaluate()) {
      final widget = field.widget as TextField;
      if (widget.decoration?.labelText == 'Tên khách') {
        await tester.enterText(find.byWidget(widget), 'Khách Demo');
      }
      if (widget.decoration?.labelText == 'Số điện thoại') {
        await tester.enterText(find.byWidget(widget), '0900000000');
      }
    }
    await tester.ensureVisible(find.text('Tạo & gửi bếp'));
    await tester.tap(find.text('Tạo & gửi bếp'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderReceipt), findsOneWidget);
    expect(find.text('BAN-DEMO-001'), findsOneWidget);
    expect(find.text('Chụp hóa đơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
