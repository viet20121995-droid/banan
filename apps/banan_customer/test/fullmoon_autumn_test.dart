import 'package:banan_customer/features/menu/fullmoon_autumn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retired Mid-Autumn decoration stays disabled', () {
    expect(fullmoonAutumnCampaignEnabled, isFalse);
  });
}
