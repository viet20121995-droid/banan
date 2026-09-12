import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cake payload renders text, candles and note', () {
    expect(
      personalizationText({
        'textOnCake': 'Happy birthday',
        'candleType': 'number',
        'candleNumber': 30,
        'note': 'ít ngọt',
      }),
      'Chữ: "Happy birthday" · nến số 30 · Ghi chú: ít ngọt',
    );
  });

  test('legacy candleCount without type is regular candles', () {
    expect(candleTicketLabel({'candleCount': 5}), '5 nến');
    expect(candleTicketLabel({'candleType': 'spiral', 'candleCount': 2}),
        '2 nến xoắn');
  });

  test('macaron flavours', () {
    expect(
      personalizationText({
        'flavors': {'Jasmine': 3, 'Lemon': 2},
      }),
      'Vị: 3× Jasmine, 2× Lemon',
    );
    expect(personalizationText({}), '');
  });
}
