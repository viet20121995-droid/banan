import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_internal/data/internal_models.dart';
import 'package:banan_internal/features/ms_create/ms_create_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpSuccess(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: BananTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MsCreateSuccessView(
            result: MsCreateResult(
              code: 'MS-2026-ABCDE',
              storeName: 'Banan – Lê Thánh Tôn',
              url: 'https://internal.banancakes.vn/f/'
                  'NiNq6sEDV0Wnrklfeg4_2yDTQyHNSJ4paVobMH9yiKU',
              expiresAt: DateTime(2026, 9, 5),
            ),
            onCreateAnother: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in [('mobile 375×812', const Size(375, 812)), ('desktop 1280×800', const Size(1280, 800))]) {
    testWidgets('success view renders without overflow on $label', (tester) async {
      await pumpSuccess(tester, size);
      // A RenderFlex overflow surfaces as a FlutterError → takeException.
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Đã tạo link'), findsOneWidget);
      expect(find.text('Sao chép link'), findsOneWidget);
      expect(find.text('Tạo nhiệm vụ khác'), findsOneWidget);
      // The one-mission / don't-share warning is always visible.
      expect(find.textContaining('MỘT nhiệm vụ'), findsOneWidget);
    });
  }

  test('idempotency keys are unique per submission and backend-format-safe', () {
    final a = newIdempotencyKey();
    final b = newIdempotencyKey();
    expect(a, isNot(b));
    expect(RegExp(r'^[\w-]{16,64}$').hasMatch(a), isTrue);
  });
}
