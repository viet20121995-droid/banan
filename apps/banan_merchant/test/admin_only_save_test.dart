import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_merchant/features/admin_mgmt/display_config_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Several chain-wide settings are readable by MERCHANT_OWNER but writable only
/// by ADMIN — `@Roles(Role.ADMIN)` sits on the PATCH while the GET is open.
/// The owner must not be able to *start* an edit the backend will reject: the
/// save has to be dead on arrival, not on submit.
///
/// DisplayConfig is the case with a cheaply-stubbed provider; /marketing and
/// /settings/content gate the same way against the same rule.

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

Future<void> _pump(WidgetTester tester, Role role) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/admin/display',
    routes: [
      GoRoute(
        path: '/admin/display',
        builder: (_, __) => const DisplayConfigScreen(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith((ref) => Stream.value(_session(role))),
        displayConfigProvider.overrideWith(
          (ref) async => const DisplayConfig(
            showStockToCustomers: false,
            contactPhone: '+84900000000',
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

bool _anyEnabled<T extends Widget>(
  WidgetTester tester,
  bool Function(T) isEnabled,
) =>
    tester.widgetList<T>(find.byType(T)).any(isEnabled);

void main() {
  group('display config — PATCH is @Roles(ADMIN)', () {
    testWidgets('owner is told why, and cannot start an edit', (tester) async {
      await _pump(tester, Role.merchantOwner);

      expect(
        find.textContaining('chỉ quản trị viên'),
        findsOneWidget,
        reason: 'a dead save button with no explanation reads as a bug',
      );
      expect(
        _anyEnabled<SwitchListTile>(tester, (w) => w.onChanged != null),
        isFalse,
        reason: 'the stock toggle PATCHes the same admin-only endpoint',
      );
      expect(
        _anyEnabled<FilledButton>(tester, (w) => w.onPressed != null),
        isFalse,
        reason: 'saving contact channels would 403',
      );
      expect(
        _anyEnabled<TextField>(tester, (w) => w.enabled ?? true),
        isFalse,
        reason: 'typing into a form that can never be saved is wasted work',
      );
    });

    testWidgets('admin gets the working screen', (tester) async {
      await _pump(tester, Role.admin);

      expect(find.textContaining('chỉ quản trị viên'), findsNothing);
      expect(
        _anyEnabled<SwitchListTile>(tester, (w) => w.onChanged != null),
        isTrue,
      );
      expect(
        _anyEnabled<FilledButton>(tester, (w) => w.onPressed != null),
        isTrue,
      );
      expect(_anyEnabled<TextField>(tester, (w) => w.enabled ?? true), isTrue);
    });
  });
}
