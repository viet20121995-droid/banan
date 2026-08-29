import 'package:banan_customer/app/customer_redirect.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// /survey is THE printed-QR link — it must be reachable by literally
/// anyone: guests, signed-in customers, and even staff accounts that every
/// other route bounces to /wrong-app.
void main() {
  String? redirect(String loc, Role? role) =>
      customerRedirect(uri: Uri.parse(loc), role: role);

  test('guest opens /survey without being sent to login', () {
    expect(redirect('/survey', null), isNull);
  });

  test('signed-in customer still opens /survey', () {
    expect(redirect('/survey', Role.customer), isNull);
  });

  test('/survey is role-independent — even non-customer sessions stay', () {
    for (final role in Role.values) {
      expect(redirect('/survey', role), isNull, reason: 'role $role');
    }
  });

  test('protected routes still gate (the survey bypass is exact-path only)', () {
    expect(redirect('/orders', null), '/login?next=%2Forders');
    expect(redirect('/orders', Role.admin), '/wrong-app');
    // No /survey/* admin surface exists in the customer app.
    expect(redirect('/survey/reports', null), startsWith('/login?next='));
  });
}
