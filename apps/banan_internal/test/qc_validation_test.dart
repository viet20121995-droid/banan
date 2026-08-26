import 'package:banan_data/banan_data.dart';
import 'package:banan_internal/data/internal_api.dart';
import 'package:banan_internal/features/qc/qc_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

void main() {
  testWidgets('QC complete is blocked client-side while items are unanswered — '
      'risk block renders the red critical warning', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 950));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const QcDetailScreen(inspectionId: 'insp1'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(testSession())),
          internalApiProvider.overrideWithValue(FakeInternalApi(qcDetailJson: qcDetailJson())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // The RISK section warns loudly before completion.
    expect(find.textContaining('RISK', findRichText: true), findsWidgets);
    expect(find.textContaining('fail toàn bộ checklist'), findsOneWidget);

    // Try to complete with an unanswered item → blocked with guidance,
    // no confirm dialog opens.
    await tester.dragFrom(const Offset(400, 700), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hoàn tất & gửi báo cáo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Còn mục chưa hợp lệ'), findsOneWidget);
    expect(find.text('Hoàn tất & gửi'), findsNothing);
  });
}
