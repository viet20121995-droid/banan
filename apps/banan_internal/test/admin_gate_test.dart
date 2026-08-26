import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:banan_internal/app/app.dart';
import 'package:banan_internal/data/internal_api.dart';
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
      ],
      child: const BananInternalApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no session → login screen', (tester) async {
    await pumpApp(tester, null);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('non-ADMIN roles are blocked at the router, not just hidden', (tester) async {
    for (final role in [Role.merchantOwner, Role.merchantStaff, Role.kitchenManager, Role.customer]) {
      await pumpApp(tester, testSession(role: role));
      expect(find.byType(WrongAppScreen), findsOneWidget, reason: 'role $role must be blocked');
    }
  });

  testWidgets('ADMIN lands on QC with the 4-item sidebar', (tester) async {
    await pumpApp(tester, testSession());
    expect(find.byType(WrongAppScreen), findsNothing);
    expect(find.text('QC'), findsWidgets);
    expect(find.text('Mystery Shopper'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Lịch làm'), findsOneWidget);
  });
}
