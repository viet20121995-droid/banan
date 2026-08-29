import 'package:banan_data/banan_data.dart';
import 'package:banan_internal/data/internal_api.dart';
import 'package:banan_internal/features/survey/admin/survey_cases_screen.dart';
import 'package:banan_internal/features/survey/admin/survey_editor_screen.dart';
import 'package:banan_internal/features/survey/admin/survey_link_screen.dart';
import 'package:banan_internal/features/survey/admin/survey_reports_screen.dart';
import 'package:banan_internal/features/survey/admin/survey_rewards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'helpers.dart';

/// InternalShell reads GoRouterState — every admin screen is pumped inside a
/// one-route router at its real path.
Future<FakeInternalApi> pumpAdmin(
  WidgetTester tester,
  Widget screen,
  String path, {
  FakeInternalApi? api,
  Size size = const Size(1280, 800),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final fake = api ?? FakeInternalApi();
  final router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (_, __) => screen)],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(testSession())),
        internalApiProvider.overrideWithValue(fake),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('reports', () {
    testWidgets('dashboard renders totals, NPS, stores, categories, tops and comments',
        (tester) async {
      await pumpAdmin(tester, const SurveyReportsScreen(), '/survey/reports');
      expect(find.text('Tổng phản hồi'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('4.25'), findsOneWidget);
      expect(find.text('NPS'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Case chưa xử lý'), findsOneWidget);
      expect(find.textContaining('Banan – Sư Vạn Hạnh'), findsWidgets);
      expect(find.text('Bánh / đồ uống'), findsOneWidget);
      expect(find.text('Tốc độ phục vụ · 3'), findsOneWidget);
      expect(find.text('Bánh ngon lắm!'), findsOneWidget);
      // No response-rate tile — there is no honest denominator yet.
      expect(find.textContaining('Tỷ lệ phản hồi'), findsNothing);
    });

    testWidgets('changing a filter re-queries with the filter applied', (tester) async {
      final api = await pumpAdmin(tester, const SurveyReportsScreen(), '/survey/reports');
      expect(api.surveySummaryQueries, hasLength(1));
      await tester.tap(find.text('Mọi điểm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5/5').last);
      await tester.pumpAndSettle();
      expect(api.surveySummaryQueries.last['overall'], 5);
    });
  });

  group('cases', () {
    testWidgets('case list shows contact ONLY as provided and status actions work',
        (tester) async {
      final api = await pumpAdmin(tester, const SurveyCasesScreen(), '/survey/cases');
      expect(find.textContaining('Chị Mai'), findsOneWidget);
      expect(find.text('“Phục vụ chậm quá”'), findsOneWidget);
      await tester.tap(find.text('Bắt đầu xử lý'));
      await tester.pumpAndSettle();
      expect(api.caseUpdates.single.$2, {'status': 'IN_PROGRESS'});
    });
  });

  group('editor', () {
    testWidgets('lists versions; published template is read-only with clone hint',
        (tester) async {
      await pumpAdmin(tester, const SurveyEditorScreen(), '/survey/editor');
      expect(find.textContaining('v1 · Khảo sát trải nghiệm tại quán'), findsWidgets);
      expect(find.text('Đang chạy'), findsOneWidget);
      expect(
        find.text('Bản đã publish là bất biến — nhân bản để sửa'),
        findsOneWidget,
      );
      // Question rows visible, no editing affordances on a published version.
      expect(find.text('Trải nghiệm tại Banan hôm nay thế nào?'), findsOneWidget);
      expect(find.text('Lưu câu hỏi'), findsNothing);
    });

    testWidgets('mobile preview opens the REAL guest flow', (tester) async {
      await pumpAdmin(tester, const SurveyEditorScreen(), '/survey/editor');
      await tester.tap(find.text('Xem thử'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đang trải nghiệm tại chi nhánh nào?'), findsOneWidget);
      expect(find.text('Banan – Chi nhánh mẫu'), findsOneWidget);
    });
  });

  group('link & QR', () {
    test('surveyUrl targets the CUSTOMER domain and trims trailing slashes', () {
      expect(
        SurveyLinkScreen.surveyUrl(customerBase: 'https://banancakes.vn'),
        'https://banancakes.vn/survey',
      );
      expect(
        SurveyLinkScreen.surveyUrl(customerBase: 'https://banancakes.vn/'),
        'https://banancakes.vn/survey',
      );
      // Whatever Env.customerAppUrl is, the link NEVER points at this app.
      expect(SurveyLinkScreen.surveyUrl(), isNot(contains('internal.')));
      expect(SurveyLinkScreen.surveyUrl(), endsWith('/survey'));
    });

    testWidgets('shows the ONE fixed customer /survey link with copy + QR + PNG/PDF buttons',
        (tester) async {
      await pumpAdmin(tester, const SurveyLinkScreen(), '/survey/link');
      // Rendered link = the customer-domain URL, never internal (the QR
      // encodes the same `url` variable the text renders).
      expect(find.text(SurveyLinkScreen.surveyUrl()), findsOneWidget);
      expect(find.text('https://internal.banancakes.vn/survey'), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Quét để chia sẻ trải nghiệm'), findsOneWidget);
      expect(find.text('Tải QR PNG'), findsOneWidget);
      expect(find.text('Tải PDF để in'), findsOneWidget);
      // NO per-table/per-branch QR list.
      expect(find.textContaining('QR theo bàn'), findsNothing);
    });
  });

  group('rewards', () {
    testWidgets('campaign card shows DISABLED default + caps; redeem happy path',
        (tester) async {
      await pumpAdmin(tester, const SurveyRewardsScreen(), '/survey/rewards');
      expect(find.text('Bánh mini cảm ơn'), findsOneWidget);
      expect(find.text('Đang tắt'), findsOneWidget);
      expect(find.textContaining('tổng 4/100'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'BAN-GOOD-CODE');
      await tester.tap(find.text('Xác nhận đổi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã đổi BAN-GOOD-CODE'), findsOneWidget);
    });

    testWidgets('redeeming an unknown code surfaces the server message', (tester) async {
      await pumpAdmin(tester, const SurveyRewardsScreen(), '/survey/rewards');
      await tester.enterText(find.byType(TextField).first, 'BAN-XXXX-XXXX');
      await tester.tap(find.text('Xác nhận đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy mã quà này.'), findsOneWidget);
    });
  });

  group('overflow', () {
    for (final size in [const Size(390, 844), const Size(820, 1180), const Size(1440, 900)]) {
      testWidgets('admin survey screens survive ${size.width.toInt()}px', (tester) async {
        for (final (screen, path) in <(Widget, String)>[
          (const SurveyReportsScreen(), '/survey/reports'),
          (const SurveyCasesScreen(), '/survey/cases'),
          (const SurveyEditorScreen(), '/survey/editor'),
          (const SurveyLinkScreen(), '/survey/link'),
          (const SurveyRewardsScreen(), '/survey/rewards'),
        ]) {
          await pumpAdmin(tester, screen, path, size: size);
          expect(tester.takeException(), isNull, reason: '$path @ ${size.width}');
        }
      });
    }
  });
}
