import 'package:banan_core/banan_core.dart';
import 'package:banan_internal/data/internal_api.dart';
import 'package:banan_internal/data/internal_models.dart';
import 'package:banan_internal/features/public_form/ms_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> pumpForm(
  WidgetTester tester,
  Result<MsPublicView, AppFailure> viewResult, {
  Size size = const Size(375, 812),
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        internalPublicApiProvider.overrideWithValue(FakePublicApi(viewResult)),
      ],
      child: const MaterialApp(home: MsFormScreen(token: 't-test')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('expired link shows a clear expired state with retry', (tester) async {
    await pumpForm(
      tester,
      const Result.failure(ServerFailure(code: 'INTERNAL_MS_LINK_EXPIRED')),
    );
    expect(find.text('Link đã hết hạn'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('revoked link shows the revoked state', (tester) async {
    await pumpForm(
      tester,
      const Result.failure(ServerFailure(code: 'INTERNAL_MS_LINK_REVOKED')),
    );
    expect(find.text('Link đã bị thu hồi'), findsOneWidget);
  });

  testWidgets('already-submitted link shows the thank-you state, no form', (tester) async {
    await pumpForm(
      tester,
      Result.success(MsPublicView.fromJson(publicViewJson(status: 'SUBMITTED'))),
    );
    expect(find.text('Đã nộp bài — cảm ơn bạn!'), findsOneWidget);
    expect(find.text('Gửi bài kiểm tra'), findsNothing);
  });

  testWidgets('open form renders mobile-first without overflow and blocks empty submit',
      (tester) async {
    await pumpForm(
      tester,
      Result.success(MsPublicView.fromJson(publicViewJson(status: 'OPENED'))),
    );
    // Overflow would surface as a FlutterError in the test harness — reaching
    // here means the 375px layout is clean. Scroll down to the submit button
    // (the ListView builds lazily).
    await tester.scrollUntilVisible(
      find.text('Gửi bài kiểm tra'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Gửi bài kiểm tra'), findsOneWidget);

    await tester.tap(find.text('Gửi bài kiểm tra'));
    await tester.pumpAndSettle();
    // Unanswered questions → validation snack, no confirm dialog.
    expect(find.textContaining('Còn câu chưa trả lời'), findsOneWidget);
    expect(find.text('Gửi bài'), findsNothing);
  });
}
