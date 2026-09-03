import 'package:banan_domain/banan_domain.dart';
import 'package:banan_kitchen/features/kanban/order_row.dart';
import 'package:banan_kitchen/shared/theme/kitchen_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 8, 30, 9);

Order _order({
  String code = 'BAN-2026-TEST01',
  KitchenStatus? kitchenStatus = KitchenStatus.pendingAck,
  OrderStatus status = OrderStatus.sentToKitchen,
  String source = 'WEB',
  DateTime? scheduledFor,
  DateTime? createdAt,
  String? notes,
  List<OrderItem>? items,
  List<TransferMfgItem> mfgItems = const [],
}) =>
    Order(
      id: 'id-$code',
      code: code,
      customerId: 'c1',
      storeId: 's1',
      storeName: 'Banan – Lê Thánh Tôn',
      fulfillmentType: FulfillmentType.pickup,
      status: status,
      kitchenStatus: kitchenStatus,
      source: source,
      subtotal: 0,
      deliveryFee: 0,
      total: 0,
      items: items ??
          const [
            OrderItem(
              id: 'i1',
              productId: 'p1',
              productName: 'Mousse chanh dây',
              quantity: 2,
              unitPrice: 0,
              lineTotal: 0,
              variantLabel: 'Size 18cm',
            ),
            OrderItem(
              id: 'i2',
              productId: 'p2',
              productName: 'Bánh kem dâu tươi trang trí hoa hồng đặc biệt',
              quantity: 1,
              unitPrice: 0,
              lineTotal: 0,
              customMessage: 'Chúc mừng sinh nhật Mai',
            ),
          ],
      mfgItems: mfgItems,
      statusEvents: const [],
      payments: const [],
      refunds: const [],
      createdAt: createdAt ?? _now,
      updatedAt: _now,
      scheduledFor: scheduledFor,
      notes: notes,
      destinationStoreName: source == 'INTERNAL_TRANSFER' ? 'Banan – Trường Sa' : null,
    );

Future<void> _pump(WidgetTester tester, Widget child, {double width = 1200}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: KitchenTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('KitchenOrderRow', () {
    testWidgets('one row: identity + items underneath + stage action on the same row',
        (tester) async {
      var accepted = 0;
      await _pump(
        tester,
        KitchenOrderRow(
          order: _order(notes: 'Giao trước 10h'),
          tab: KitchenBoardTab.pending,
          clock: _now,
          onAccept: () async {
            accepted++;
            return true;
          },
        ),
      );
      expect(find.text('BAN-2026-TEST01'), findsOneWidget);
      expect(find.text('Mousse chanh dây'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // quantity badge
      expect(find.textContaining('Chúc mừng sinh nhật Mai'), findsOneWidget);
      expect(find.text('Giao trước 10h'), findsOneWidget);
      expect(find.text('Nhận đơn'), findsOneWidget);
      // Other stages' actions never leak onto this row.
      expect(find.text('Làm xong'), findsNothing);
      expect(find.text('Xuất khỏi bếp'), findsNothing);

      await tester.tap(find.text('Nhận đơn'));
      await tester.pumpAndSettle();
      expect(accepted, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('preparing → "Làm xong"; ready internal transfer → adjust + dispatch',
        (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            KitchenOrderRow(
              order: _order(code: 'PREP', kitchenStatus: KitchenStatus.preparing),
              tab: KitchenBoardTab.preparing,
              clock: _now,
              onReady: () async => true,
            ),
            KitchenOrderRow(
              order: _order(
                code: 'XFER',
                kitchenStatus: KitchenStatus.readyDispatch,
                source: 'INTERNAL_TRANSFER',
                mfgItems: const [
                  TransferMfgItem(
                    id: 'm1',
                    mfgProductId: 'mp1',
                    code: 'FLOUR',
                    name: 'Bột mì',
                    uomCode: 'kg',
                    qty: 2.5,
                  ),
                ],
              ),
              tab: KitchenBoardTab.ready,
              clock: _now,
              onDispatch: () async => true,
              onAdjust: () {},
            ),
          ],
        ),
      );
      expect(find.text('Làm xong'), findsOneWidget);
      expect(find.text('Sửa số lượng'), findsOneWidget);
      expect(find.text('Xuất khỏi bếp'), findsOneWidget);
      expect(find.text('Nội bộ'), findsOneWidget);
      expect(find.textContaining('Giao về Banan – Trường Sa'), findsOneWidget);
      expect(find.text('2.5 kg'), findsOneWidget);
      expect(find.text('vật tư'), findsOneWidget);
    });

    testWidgets('done tab shows the outcome, no buttons', (tester) async {
      await _pump(
        tester,
        KitchenOrderRow(
          order: _order(kitchenStatus: null, status: OrderStatus.completed),
          tab: KitchenBoardTab.done,
          clock: _now,
        ),
      );
      expect(find.text('Hoàn tất'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('failed action surfaces a snackbar and re-enables the button',
        (tester) async {
      await _pump(
        tester,
        KitchenOrderRow(
          order: _order(),
          tab: KitchenBoardTab.pending,
          clock: _now,
          onAccept: () async => false,
        ),
      );
      await tester.tap(find.text('Nhận đơn'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa nhận được đơn, thử lại.'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    for (final width in [390.0, 820.0, 1440.0]) {
      testWidgets('no overflow at ${width.toInt()}px', (tester) async {
        await _pump(
          tester,
          KitchenOrderRow(
            order: _order(
              source: 'WHOLESALE',
              scheduledFor: _now.add(const Duration(minutes: 30)),
              notes: 'Khách yêu cầu gói riêng từng hộp, giao trước 10 giờ sáng.',
            ),
            tab: KitchenBoardTab.ready,
            clock: _now,
            onDispatch: () async => true,
          ),
          width: width,
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Ưu tiên · còn 30 phút'), findsOneWidget);
      });
    }
  });

  group('KitchenStatusTabs', () {
    testWidgets('shows live counts and reports the tapped stage', (tester) async {
      KitchenBoardTab? picked;
      await _pump(
        tester,
        KitchenStatusTabs(
          selected: KitchenBoardTab.pending,
          counts: const {
            KitchenBoardTab.pending: 3,
            KitchenBoardTab.preparing: 2,
            KitchenBoardTab.ready: 0,
            KitchenBoardTab.done: 12,
          },
          onSelected: (t) => picked = t,
        ),
      );
      for (final label in ['Chờ nhận', 'Đang làm', 'Sẵn sàng giao', 'Xong hôm nay']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('3'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      await tester.tap(find.text('Đang làm'));
      expect(picked, KitchenBoardTab.preparing);
    });

    testWidgets('fits a phone without overflow', (tester) async {
      await _pump(
        tester,
        KitchenStatusTabs(
          selected: KitchenBoardTab.ready,
          counts: const {},
          onSelected: (_) {},
        ),
        width: 390,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('kitchenPriority', () {
    test('overdue scheduled order, soon-due order, stale unaccepted order', () {
      expect(
        kitchenPriority(
          _order(scheduledFor: _now.subtract(const Duration(minutes: 20))),
          _now,
        )?.reason,
        'quá giờ 20 phút',
      );
      expect(
        kitchenPriority(_order(scheduledFor: _now.add(const Duration(hours: 1))), _now)
            ?.overdue,
        isFalse,
      );
      expect(
        kitchenPriority(
          _order(createdAt: _now.subtract(const Duration(minutes: 16))),
          _now,
        )?.reason,
        'chờ nhận 16 phút',
      );
      expect(kitchenPriority(_order(), _now), isNull);
    });
  });
}
