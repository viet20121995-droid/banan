import 'package:banan_data/banan_data.dart';
import 'package:banan_internal/data/internal_api.dart';
import 'package:banan_internal/data/internal_models.dart';
import 'package:banan_internal/features/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required Size size}) async {
    await tester.binding.setSurfaceSize(size);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const ScheduleScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(testSession())),
          internalApiProvider.overrideWithValue(
            FakeInternalApi(week: ScheduleWeek.fromJson(scheduleWeekJson())),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop shows all 4 branches in one screen', (tester) async {
    await pump(tester, size: const Size(1500, 1000));
    expect(find.text('Banan – Lê Thánh Tôn'), findsOneWidget);
    expect(find.text('Banan – Sư Vạn Hạnh'), findsOneWidget);
    expect(find.text('Banan – Ngô Quang Huy'), findsOneWidget);
    expect(find.text('Banan – Trường Sa'), findsOneWidget);
    // Free-text assignment renders with its note, Excel-style.
    expect(find.textContaining('Phương'), findsWidgets);
  });

  testWidgets('mobile layout does not overflow (grids scroll horizontally)', (tester) async {
    await pump(tester, size: const Size(390, 844));
    // Reaching here without a layout exception = no overflow; the store grid
    // scrolls inside its own horizontal scroll view.
    expect(find.text('Banan – Lê Thánh Tôn'), findsOneWidget);
  });
}
