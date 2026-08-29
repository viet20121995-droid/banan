import 'package:banan_core/banan_core.dart';
import 'package:banan_internal/data/internal_api.dart';
import 'package:banan_internal/data/survey_models.dart';
import 'package:banan_internal/features/survey/survey_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<FakePublicApi> pumpSurvey(
  WidgetTester tester, {
  FakePublicApi? api,
  SurveyDraftStore? draftStore,
  Size size = const Size(390, 844),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final publicApi = api ??
      FakePublicApi(const Result.failure(ServerFailure(code: 'INTERNAL_MS_LINK_INVALID')));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [internalPublicApiProvider.overrideWithValue(publicApi)],
      child: MaterialApp(
        home: SurveyScreen(draftStore: draftStore ?? MemoryDraftStore()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return publicApi;
}

Future<void> next(WidgetTester tester, {String label = 'Tiếp tục'}) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('branch list comes from the API — both fake stores render, none preselected',
      (tester) async {
    await pumpSurvey(tester);
    expect(find.text('Bạn đang trải nghiệm tại chi nhánh nào?'), findsOneWidget);
    expect(find.text('Banan – Lê Thánh Tôn'), findsOneWidget);
    expect(find.text('Banan – Sư Vạn Hạnh'), findsOneWidget);
    expect(find.text('15 Lê Thánh Tôn, Q1'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
  });

  testWidgets('branch is REQUIRED — next without a pick shows the error and stays',
      (tester) async {
    await pumpSurvey(tester);
    await next(tester);
    expect(find.text('Vui lòng chọn chi nhánh bạn đã ghé.'), findsOneWidget);
    expect(find.text('Bạn đang trải nghiệm tại chi nhánh nào?'), findsOneWidget);
  });

  testWidgets('required overall blocks advancing until answered', (tester) async {
    await pumpSurvey(tester);
    await tester.tap(find.text('Banan – Lê Thánh Tôn'));
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.text('Trải nghiệm tại Banan hôm nay thế nào?'), findsOneWidget);
    await next(tester);
    expect(find.text('Vui lòng chọn câu trả lời để tiếp tục.'), findsOneWidget);
  });

  testWidgets('POSITIVE branch: overall 5 shows praise (not improve), submits, thanks + reward',
      (tester) async {
    final api = FakePublicApi(
      const Result.failure(ServerFailure(code: 'INTERNAL_MS_LINK_INVALID')),
      surveySubmitResult: Result.success(
        SurveySubmitResult.fromJson(const {
          'id': 'resp1',
          'reward': {
            'mode': 'VOUCHER_CODE',
            'name': 'Bánh mini cảm ơn',
            'voucherCode': 'BAN-ABCD-2345',
          },
        }),
      ),
    );
    await pumpSurvey(tester, api: api);
    await tester.tap(find.text('Banan – Lê Thánh Tôn'));
    await tester.pumpAndSettle();
    await next(tester); // → overall
    await tester.tap(find.byIcon(Icons.sentiment_very_satisfied));
    await tester.pumpAndSettle();
    await next(tester); // → ratings group
    expect(find.text('Bánh / đồ uống'), findsOneWidget);
    expect(find.text('Thái độ phục vụ'), findsOneWidget);
    await next(tester); // ratings optional → praise
    expect(find.text('Điều gì làm bạn thích nhất?'), findsOneWidget);
    expect(find.text('Banan cần cải thiện điều gì?'), findsNothing);
    await tester.tap(find.text('Hương vị bánh & đồ uống'));
    await tester.pumpAndSettle();
    await next(tester); // → NPS
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    await next(tester); // → comment
    await tester.enterText(find.byType(TextFormField), 'Tuyệt vời!');
    await next(tester, label: 'Gửi khảo sát');
    // Thank-you + the gift is only revealed AFTER submit.
    expect(find.text('Cảm ơn bạn đã chia sẻ!'), findsOneWidget);
    expect(find.text('BAN-ABCD-2345'), findsOneWidget);
    // The wire body carried the API question ids + our answers.
    expect(api.surveySubmits, hasLength(1));
    final body = api.surveySubmits.single;
    expect(body['storeId'], 's1');
    final answers = (body['answers'] as List).cast<Map<String, dynamic>>();
    expect(
      answers.any((a) => a['questionId'] == 'q-overall' && a['numberValue'] == 5),
      isTrue,
    );
    expect(
      answers.any(
        (a) => a['questionId'] == 'q-praise' && (a['optionValues'] as List).contains('taste'),
      ),
      isTrue,
    );
    expect(body['contact'], isNull);
  });

  testWidgets('NEGATIVE branch: overall 1 shows improve + contact; consent sends PII',
      (tester) async {
    final api = await pumpSurvey(tester);
    await tester.tap(find.text('Banan – Sư Vạn Hạnh'));
    await tester.pumpAndSettle();
    await next(tester); // → overall
    await tester.tap(find.byIcon(Icons.sentiment_very_dissatisfied));
    await tester.pumpAndSettle();
    await next(tester); // → ratings
    await next(tester); // → improve
    expect(find.text('Banan cần cải thiện điều gì?'), findsOneWidget);
    expect(find.text('Điều gì làm bạn thích nhất?'), findsNothing);
    await tester.tap(find.text('Tốc độ phục vụ').last);
    await tester.pumpAndSettle();
    await next(tester); // → NPS
    await next(tester); // → comment
    await next(tester); // → contact_request
    expect(
      find.text('Bạn có muốn Banan liên hệ để xử lý vấn đề không?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Có'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại'),
      '0900000001',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await next(tester, label: 'Gửi khảo sát');
    expect(find.text('Cảm ơn bạn đã chia sẻ!'), findsOneWidget);
    final body = api.surveySubmits.single;
    expect((body['contact'] as Map)['consent'], isTrue);
    expect((body['contact'] as Map)['phone'], '0900000001');
    final answers = (body['answers'] as List).cast<Map<String, dynamic>>();
    expect(
      answers.any((a) => a['questionId'] == 'q-contact' && a['numberValue'] == 1),
      isTrue,
    );
  });

  testWidgets('consent with an invalid phone is blocked before anything is sent',
      (tester) async {
    final api = await pumpSurvey(tester);
    await tester.tap(find.text('Banan – Sư Vạn Hạnh'));
    await tester.pumpAndSettle();
    await next(tester); // → overall
    await tester.tap(find.byIcon(Icons.sentiment_very_dissatisfied));
    await tester.pumpAndSettle();
    await next(tester); // → ratings
    await next(tester); // → improve
    await tester.tap(find.text('Tốc độ phục vụ').last);
    await tester.pumpAndSettle();
    await next(tester); // → NPS
    await next(tester); // → comment
    await next(tester); // → contact_request
    await tester.tap(find.text('Có'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Số điện thoại'),
      '123',
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await next(tester, label: 'Gửi khảo sát');
    // Blocked client-side: validation message shown, nothing was sent.
    expect(find.textContaining('số điện thoại hợp lệ'), findsOneWidget);
    expect(api.surveySubmits, isEmpty);
  });

  testWidgets('answers survive a "refresh" (new widget tree, same draft store)',
      (tester) async {
    final store = MemoryDraftStore();
    await pumpSurvey(tester, draftStore: store);
    await tester.tap(find.text('Banan – Lê Thánh Tôn'));
    await tester.pumpAndSettle();
    await next(tester); // now on the overall step; draft saved
    expect(find.text('Trải nghiệm tại Banan hôm nay thế nào?'), findsOneWidget);

    // "Refresh": brand-new widget tree fed the same persisted draft.
    await pumpSurvey(tester, draftStore: store);
    expect(find.text('Trải nghiệm tại Banan hôm nay thế nào?'), findsOneWidget);
    // Going back shows the branch still selected.
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets('no published template → friendly holding message, no crash', (tester) async {
    final api = FakePublicApi(
      const Result.failure(ServerFailure(code: 'INTERNAL_MS_LINK_INVALID')),
      surveyInfoResult: Result.success(
        SurveyPublicInfo.fromJson(const {'template': null, 'stores': <Object>[], 'reward': null}),
      ),
    );
    await pumpSurvey(tester, api: api);
    expect(find.text('Khảo sát đang được chuẩn bị — quay lại sau nhé!'), findsOneWidget);
  });

  for (final size in [const Size(390, 844), const Size(820, 1180), const Size(1440, 900)]) {
    testWidgets('no overflow at ${size.width.toInt()}px', (tester) async {
      await pumpSurvey(tester, size: size);
      await tester.tap(find.text('Banan – Lê Thánh Tôn'));
      await tester.pumpAndSettle();
      await next(tester);
      await tester.tap(find.byIcon(Icons.sentiment_very_satisfied));
      await tester.pumpAndSettle();
      await next(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
