import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/collections_mgmt/collection_editor_screen.dart';
import '../features/collections_mgmt/collections_list_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/menu_mgmt/menu_list_screen.dart';
import '../features/menu_mgmt/product_editor_screen.dart';
import '../features/orders_mgmt/order_detail_screen.dart';
import '../features/orders_mgmt/orders_screen.dart';
import '../features/refunds/refunds_screen.dart';
import '../features/threads_mgmt/thread_editor_screen.dart';
import '../features/threads_mgmt/threads_list_screen.dart';

const _login = '/login';
const _wrongApp = '/wrong-app';
const _home = '/';

/// Merchant dashboard router. Only `MERCHANT_OWNER` and `MERCHANT_STAFF` roles
/// are allowed past `/login`. Anything else lands on `/wrong-app`.
final merchantRouterProvider = Provider<GoRouter>((ref) {
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
      if (!session.user.role.isMerchant && !session.user.role.isAdmin) {
        return loc == _wrongApp ? null : _wrongApp;
      }
      if (loc == _login || loc == _wrongApp) return _home;
      return null;
    },
    routes: [
      // Default: orders queue (merchant's daily focus).
      GoRoute(path: _home, builder: (_, __) => const MerchantOrdersScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) => MerchantOrderDetailScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/menu',
        builder: (_, __) => const MerchantMenuListScreen(),
      ),
      GoRoute(
        path: '/refunds',
        builder: (_, __) => const RefundsScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const MerchantDashboardScreen(),
      ),
      GoRoute(
        path: '/collections',
        builder: (_, __) => const CollectionsListScreen(),
      ),
      GoRoute(
        path: '/collections/new',
        builder: (_, __) => const CollectionEditorScreen(),
      ),
      GoRoute(
        path: '/collections/:id',
        builder: (context, state) =>
            CollectionEditorScreen(collectionId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/threads',
        builder: (_, __) => const ThreadsListScreen(),
      ),
      GoRoute(
        path: '/threads/new',
        builder: (_, __) => const ThreadEditorScreen(),
      ),
      GoRoute(
        path: '/threads/:id',
        builder: (context, state) =>
            ThreadEditorScreen(threadId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/menu/new',
        builder: (_, __) => const ProductEditorScreen(),
      ),
      GoRoute(
        path: '/menu/:id',
        builder: (context, state) =>
            ProductEditorScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(
        path: _login,
        builder: (_, __) => const LoginScreen(
          title: 'Banan · Merchant',
          subtitle: 'Sign in to manage your store.',
        ),
      ),
      GoRoute(
        path: _wrongApp,
        builder: (_, __) => const WrongAppScreen(
          expected: 'store staff',
          actual: 'a different role',
        ),
      ),
    ],
  );
});
