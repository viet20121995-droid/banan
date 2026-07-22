import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/change_password_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/kanban/kanban_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/production/bom_editor_screen.dart';
import '../features/production/bom_list_screen.dart';
import '../features/production/maintenance_screen.dart';
import '../features/production/mo_detail_screen.dart';
import '../features/production/mo_list_screen.dart';
import '../features/production/oee_screen.dart';
import '../features/production/product_form_screen.dart';
import '../features/production/production_dashboard_screen.dart';
import '../features/production/products_screen.dart';
import '../features/production/purchasing_screens.dart';
import '../features/production/quality_alerts_screen.dart';
import '../features/production/receipt_form_screen.dart';
import '../features/production/replenishment_screen.dart';
import '../features/production/reports_screen.dart';
import '../features/production/schedule_screen.dart';
import '../features/production/scrap_form_screen.dart';
import '../features/production/shop_floor_screen.dart';
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
        path: '/production/shop-floor',
        builder: (_, __) => const ShopFloorScreen(),
      ),
      GoRoute(
        path: '/production/schedule',
        builder: (_, __) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/production/reports',
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/production/replenishment',
        builder: (_, __) => const ReplenishmentScreen(),
      ),
      GoRoute(
        path: '/production/scrap',
        builder: (_, __) => const ScrapFormScreen(),
      ),
      GoRoute(
        path: '/production/receipt',
        builder: (_, __) => const ReceiptFormScreen(),
      ),
      GoRoute(
        path: '/production/alerts',
        builder: (_, __) => const QualityAlertsScreen(),
      ),
      GoRoute(
        path: '/production/products',
        builder: (_, __) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/production/products/new',
        builder: (_, __) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/production/products/:id/edit',
        builder: (_, state) =>
            ProductFormScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/production/products/:id/history',
        builder: (_, state) =>
            PurchaseHistoryScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/production/suppliers',
        builder: (_, __) => const SuppliersScreen(),
      ),
      GoRoute(
        path: '/production/purchase-orders',
        builder: (_, __) => const PurchaseOrdersScreen(),
      ),
      GoRoute(
        path: '/production/purchase-orders/new',
        builder: (_, __) => const PoFormScreen(),
      ),
      GoRoute(
        path: '/production/purchase-orders/:id',
        builder: (_, state) =>
            PoDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/production/boms',
        builder: (_, __) => const BomListScreen(),
      ),
      GoRoute(
        path: '/production/boms/new',
        builder: (_, __) => const BomEditorScreen(),
      ),
      GoRoute(
        path: '/production/boms/:id/edit',
        builder: (_, state) =>
            BomEditorScreen(bomId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/production/maintenance',
        builder: (_, __) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/production/oee',
        builder: (_, __) => const OeeScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: _login,
        builder: (_, __) => const LoginScreen(
          title: 'Banan · Bếp',
          subtitle: 'Đăng nhập để xem bảng sản xuất hôm nay.',
        ),
      ),
      GoRoute(
        path: _wrongApp,
        builder: (_, __) => const WrongAppScreen(
          expected: 'nhân viên bếp',
          actual: 'vai trò khác',
        ),
      ),
    ],
  );
});
