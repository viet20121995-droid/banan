import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:banan_internal/app/app.dart';
import 'package:banan_internal/data/internal_api.dart';
import 'package:banan_internal/features/home/home_screen.dart';
import 'package:banan_internal/features/ms_create/ms_create_screen.dart';
import 'package:banan_internal/features/training/trainee_training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester tester, AuthSession? session) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(session)),
        internalApiProvider.overrideWithValue(FakeInternalApi()),
        internalPublicApiProvider.overrideWithValue(
          FakePublicApi(const Result.failure(ServerFailure(code: 'INTERNAL_MS_LINK_INVALID'))),
        ),
      ],
      child: const BananInternalApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guest sees the public home page with all 5 function cards', (tester) async {
    await pumpApp(tester, null);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('QC chi nhánh'), findsOneWidget);
    expect(find.text('Mystery Shopper'), findsOneWidget);
    expect(find.text('Đào tạo'), findsOneWidget);
    expect(find.text('Lịch làm việc'), findsOneWidget);
    expect(find.text('Khảo sát khách hàng'), findsOneWidget);
    // Role badges are visible so a non-tech employee knows what needs what.
    expect(find.text('Nhân viên có thể tạo link'), findsOneWidget);
    expect(find.text('Trainee / Admin'), findsOneWidget);
  });

  testWidgets('guest tapping Khảo sát khách hàng is sent to login (admin area)', (tester) async {
    await pumpApp(tester, null);
    await tester.tap(find.text('Khảo sát khách hàng'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('guest tapping QC is sent to login (returnTo preserved)', (tester) async {
    await pumpApp(tester, null);
    await tester.tap(find.text('QC chi nhánh'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('guest tapping Lịch làm việc is sent to login', (tester) async {
    await pumpApp(tester, null);
    await tester.tap(find.text('Lịch làm việc'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('guest CAN open the MS link generator without any account', (tester) async {
    await pumpApp(tester, null);
    await tester.tap(find.text('Tạo link Mystery Shopper'));
    await tester.pumpAndSettle();
    expect(find.byType(MsCreateScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    // Branches came from the public endpoint.
    expect(find.text('Chi nhánh Mystery Shopper sẽ đánh giá *'), findsOneWidget);
  });

  testWidgets('other staff roles are blocked at the guarded areas, not at home', (tester) async {
    for (final role in [Role.merchantOwner, Role.kitchenManager, Role.customer]) {
      await pumpApp(tester, testSession(role: role));
      expect(find.byType(HomeScreen), findsOneWidget, reason: 'home is public for $role');
      await tester.tap(find.text('QC chi nhánh'));
      await tester.pumpAndSettle();
      expect(find.byType(WrongAppScreen), findsOneWidget, reason: 'role $role must be blocked');
    }
  });

  testWidgets('TRAINEE reaches their training screen from the Đào tạo card', (tester) async {
    await pumpApp(tester, testSession(role: Role.trainee));
    await tester.tap(find.text('Đào tạo'));
    await tester.pumpAndSettle();
    expect(find.byType(TraineeTrainingScreen), findsOneWidget);
    expect(find.byType(WrongAppScreen), findsNothing);
  });

  testWidgets('TRAINEE is blocked from QC and Lịch làm việc', (tester) async {
    await pumpApp(tester, testSession(role: Role.trainee));
    await tester.tap(find.text('QC chi nhánh'));
    await tester.pumpAndSettle();
    expect(find.byType(WrongAppScreen), findsOneWidget);
  });

  testWidgets('ADMIN reaches QC with the 5-item sidebar (Khảo sát included)', (tester) async {
    await pumpApp(tester, testSession());
    await tester.tap(find.text('QC chi nhánh'));
    await tester.pumpAndSettle();
    expect(find.byType(WrongAppScreen), findsNothing);
    expect(find.text('QC'), findsWidgets);
    expect(find.text('Mystery Shopper'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Lịch làm'), findsOneWidget);
    expect(find.text('Khảo sát'), findsOneWidget);
  });
}
