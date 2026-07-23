import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_merchant/shared/shell/merchant_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The sidebar must only offer what the backend will actually serve. Each
/// expectation below mirrors the @Roles on the controller behind the route —
/// when those change, this test is the thing that notices.

AuthSession _session(Role role) => AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      user: User(
        id: 'u1',
        email: 'u@banan.local',
        fullName: 'Test',
        role: role,
        membershipTier: MembershipTier.bronze,
        pointsBalance: 0,
        storeId: 's1',
      ),
    );

Future<void> _pumpSidebar(WidgetTester tester, Role role) async {
  // The sidebar only renders at desktop width; a phone-sized surface swaps it
  // for the bottom bar and the labels never mount.
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/orders',
    routes: [
      GoRoute(
        path: '/orders',
        builder: (_, __) => const MerchantShell(
          title: 'Đơn hàng',
          body: SizedBox.shrink(),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream.value(_session(role))),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Sections start collapsed, so open every group before reading the labels.
Future<void> _expandAll(WidgetTester tester) async {
  for (final label in ['MARKETING', 'VẬN HÀNH', 'CÀI ĐẶT']) {
    final finder = find.text(label);
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  group('merchant sidebar role gating', () {
    testWidgets('owner is not offered Khuyến mãi — /campaigns is ADMIN-only',
        (tester) async {
      // backend/src/promotions/promotions.controller.ts:
      //   @Controller('merchant/campaigns') @Roles(Role.ADMIN)
      // Class-level, so an owner 403s on the list itself.
      await _pumpSidebar(tester, Role.merchantOwner);
      await _expandAll(tester);
      expect(find.text('Khuyến mãi'), findsNothing);
    });

    testWidgets('admin is offered Khuyến mãi', (tester) async {
      await _pumpSidebar(tester, Role.admin);
      await _expandAll(tester);
      expect(find.text('Khuyến mãi'), findsOneWidget);
    });

    testWidgets('staff is not offered Popup quảng cáo', (tester) async {
      // backend/src/promo-popup: @Controller('admin/promo-popup')
      //   @Roles(Role.ADMIN, Role.MERCHANT_OWNER) — staff 403s.
      await _pumpSidebar(tester, Role.merchantStaff);
      await _expandAll(tester);
      expect(find.text('Popup quảng cáo'), findsNothing);
    });

    testWidgets('owner is offered Popup quảng cáo', (tester) async {
      await _pumpSidebar(tester, Role.merchantOwner);
      await _expandAll(tester);
      expect(find.text('Popup quảng cáo'), findsOneWidget);
    });

    testWidgets('owner keeps Chương trình ưu đãi — merchant/marketing allows it',
        (tester) async {
      // @Roles(ADMIN, MERCHANT_OWNER) at the class level: the owner really can
      // read this one, so hiding it would be the opposite bug.
      await _pumpSidebar(tester, Role.merchantOwner);
      await _expandAll(tester);
      expect(find.text('Chương trình ưu đãi'), findsOneWidget);
    });

    testWidgets('owner is offered Thẻ quà tặng — merchant/gift-cards allows it',
        (tester) async {
      // @Roles(ADMIN, MERCHANT_OWNER) on MerchantGiftCardsController; the
      // route existed but had no nav entry, so owners could never find it.
      await _pumpSidebar(tester, Role.merchantOwner);
      await _expandAll(tester);
      expect(find.text('Thẻ quà tặng'), findsOneWidget);
    });

    testWidgets('staff is not offered Thẻ quà tặng', (tester) async {
      await _pumpSidebar(tester, Role.merchantStaff);
      await _expandAll(tester);
      expect(find.text('Thẻ quà tặng'), findsNothing);
    });
  });
}
