import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/cart_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/membership/membership_screen.dart';
import '../features/menu/menu_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/orders_list_screen.dart';
import '../features/payment_return/payment_return_screen.dart';
import '../features/product_detail/product_detail_screen.dart';

const _login = '/login';
const _register = '/register';
const _wrongApp = '/wrong-app';
const _home = '/';

/// Customer app router. Auth-aware: redirects unauthenticated traffic to
/// /login, sends non-customer accounts to /wrong-app, and bounces logged-in
/// users away from /login or /register.
final customerRouterProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final refresh = GoRouterRefreshStream(repo.watchSession());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: _home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = repo.currentSession;
      final loc = state.matchedLocation;
      final atAuthPage = loc == _login || loc == _register;

      if (session == null) {
        return atAuthPage ? null : _login;
      }
      if (!session.user.role.isCustomer) {
        return loc == _wrongApp ? null : _wrongApp;
      }
      if (atAuthPage || loc == _wrongApp) return _home;
      return null;
    },
    routes: [
      GoRoute(path: _home, builder: (_, __) => const MenuScreen()),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersListScreen()),
      GoRoute(
        path: '/membership',
        builder: (_, __) => const MembershipScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/payments/return/:provider',
        builder: (context, state) => PaymentReturnScreen(
          provider: state.pathParameters['provider']!,
          params: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: _login,
        builder: (context, state) => LoginScreen(
          title: 'Banan',
          subtitle: "Sign in to order today's creations.",
          showRegisterLink: true,
          onRegisterTapped: () => context.go(_register),
        ),
      ),
      GoRoute(
        path: _register,
        builder: (context, state) => RegisterScreen(
          onBackToLogin: () => context.go(_login),
        ),
      ),
      GoRoute(
        path: _wrongApp,
        builder: (_, __) => const WrongAppScreen(
          expected: 'Customers',
          actual: 'staff',
        ),
      ),
    ],
  );
});
