import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/change_password_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/kanban/kanban_screen.dart';
import '../features/production/mo_detail_screen.dart';
import '../features/production/mo_list_screen.dart';
import '../features/production/production_dashboard_screen.dart';
import '../features/production/stock_screen.dart';

const _login = '/login';
const _wrongApp = '/wrong-app';
const _home = '/';

/// Kitchen dashboard router. Only KITCHEN_* roles allowed past login.
final kitchenRouterProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final refresh = GoRouterRefreshStream(repo.watchSession());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: _home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = repo.currentSession;
      final loc = state.matchedLocation;
      if (session == null) {
        return loc == _login ? null : _login;
      }
      if (!session.user.role.isKitchen && !session.user.role.isAdmin) {
        return loc == _wrongApp ? null : _wrongApp;
      }
      if (loc == _login || loc == _wrongApp) return _home;
      return null;
    },
    routes: [
      GoRoute(path: _home, builder: (_, __) => const KanbanScreen()),
      GoRoute(
        path: '/analytics',
        builder: (_, __) => const KitchenAnalyticsScreen(),
      ),
      // ── "Sản xuất" (manufacturing / MES) — separate from the orders board. ──
      GoRoute(
        path: '/production',
        builder: (_, __) => const ProductionDashboardScreen(),
      ),
      GoRoute(
        path: '/production/orders',
        builder: (_, state) =>
            MoListScreen(state: state.uri.queryParameters['state']),
      ),
      GoRoute(
        path: '/production/orders/:id',
        builder: (_, state) =>
            MoDetailScreen(moId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/production/stock',
        builder: (_, __) => const StockScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: _login,
        builder: (_, __) => const LoginScreen(
          title: 'Banan · Kitchen',
          subtitle: "Sign in to view today's production board.",
        ),
      ),
      GoRoute(
        path: _wrongApp,
        builder: (_, __) => const WrongAppScreen(
          expected: 'kitchen staff',
          actual: 'a different role',
        ),
      ),
    ],
  );
});
