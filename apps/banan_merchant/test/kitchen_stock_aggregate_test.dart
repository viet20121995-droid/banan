import 'package:banan_data/banan_data.dart';
import 'package:banan_merchant/features/kitchen_stock/kitchen_stock_screen.dart';
import 'package:flutter_test/flutter_test.dart';

MfgOnHand row({
  required String code,
  required String location,
  required double qty,
  double reserved = 0,
  String name = 'SP',
  String type = 'FINISHED',
  String? lot,
}) =>
    MfgOnHand(
      productNameVi: name,
      productCode: code,
      lotName: lot,
      locationCode: location,
      quantity: qty,
      uomCode: 'cái',
      reservedQty: reserved,
      productType: type,
    );

void main() {
  // The bug being pinned: summing every location cancels stock out — a move
  // SUPPLIER→STOCK leaves −100 at SUPPLIER and +100 at STOCK, so the naive
  // all-location sum shows 0 for a product that has 100 on the shelf.
  test('counts ONLY the STOCK location — other locations never cancel it out',
      () {
    final rows = aggregateKitchenStock([
      row(code: 'VT1', location: 'STOCK', qty: 100),
      row(code: 'VT1', location: 'SUPPLIER', qty: -100),
      row(code: 'VT1', location: 'PRODUCTION', qty: -40),
      row(code: 'VT1', location: 'STORE', qty: 30),
      row(code: 'VT1', location: 'SCRAP', qty: 5),
    ]);
    expect(rows, hasLength(1));
    expect(rows.single.qty, 100);
    expect(rows.single.free, 100);
  });

  test('a product with quants only outside STOCK does not appear', () {
    final rows = aggregateKitchenStock([
      row(code: 'VT2', location: 'STORE', qty: 30),
    ]);
    expect(rows, isEmpty);
  });

  test('sums multiple lots of one product inside STOCK', () {
    final rows = aggregateKitchenStock([
      row(code: 'VT1', location: 'STOCK', qty: 60, lot: 'L1'),
      row(code: 'VT1', location: 'STOCK', qty: 40, lot: 'L2'),
    ]);
    expect(rows.single.qty, 100);
  });

  test('free = quantity - reservedQty', () {
    final rows = aggregateKitchenStock([
      row(code: 'VT1', location: 'STOCK', qty: 100, reserved: 30),
      row(code: 'VT1', location: 'STOCK', qty: 50, reserved: 10, lot: 'L2'),
    ]);
    expect(rows.single.free, 110);
    expect(rows.single.qty, 150);
  });

  test('type filter and query still apply', () {
    final rows = [
      row(code: 'VT1', location: 'STOCK', qty: 10, name: 'Bánh dâu'),
      row(code: 'NL1', location: 'STOCK', qty: 500, name: 'Bột', type: 'RAW'),
    ];
    expect(aggregateKitchenStock(rows, type: 'RAW').single.code, 'NL1');
    expect(aggregateKitchenStock(rows, query: 'dâu').single.code, 'VT1');
    expect(aggregateKitchenStock(rows, query: 'không có'), isEmpty);
  });
}
