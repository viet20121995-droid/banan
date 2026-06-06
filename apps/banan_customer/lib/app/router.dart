import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/addresses/addresses_screen.dart';
import '../features/auth/change_email_confirm_screen.dart';
import '../features/auth/change_password_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/content/about_screen.dart';
import '../features/content/contact_screen.dart';
import '../features/content/faq_screen.dart';
import '../features/content/legal_screens.dart';
import '../features/locations/locations_screen.dart';
import '../features/marketing/marketing_pages.dart';
import '../features/membership/membership_screen.dart';
import '../features/menu/menu_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/orders_list_screen.dart';
import '../features/payment_return/payment_return_screen.dart';
import '../features/bundles/bundle_detail_screen.dart';
import '../features/product_detail/product_detail_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/vouchers/voucher_wallet_screen.dart';
import '../features/wishlist/wishlist_screen.dart';

const _login = '/login';
const _register = '/register';
const _forgotPassword = '/forgot-password';
const _resetPassword = '/reset-password';
const _changePassword = '/change-password';
const _changeEmail = '/change-email';
const _wrongApp = '/wrong-app';
const _home = '/';

/// Routes a guest (unauthenticated) shopper is allowed to access. Browsing,
/// product detail, cart, checkout (with guest fields), payment return, and
/// the auth screens themselves. Everything else (orders history, membership,
/// notifications) is gated to logged-in customers.
const _guestAllowed = <String>{
  _home,
  '/cart',
  '/checkout',
  '/locations',
  // Public trust / legal / help pages (P3) — browsable without an account.
  '/privacy',
  '/terms',
  '/faq',
  '/about',
  '/contact',
  // P2 marketing surfaces — browsable; the pages themselves gate on the
  // admin toggle + prompt login where needed (referral / rewards).
  '/referral',
  '/gift-cards',
  '/subscription',
  '/catering',
  '/rewards',
  _login,
  _register,
  // Account recovery — reachable without a session (the user is locked out).
  _forgotPassword,
  _resetPassword,
  // Email-change confirmation — opened from the link emailed to the new
  // address; the change logs the user out, so it must be guest-allowed.
  _changeEmail,
};

bool _isGuestAllowed(String loc) {
  if (_guestAllowed.contains(loc)) return true;
  // Path-prefix matches (these accept :id segments). Browsing surfaces —
  // products, bundles/combos, and the payment-return bridge — are all
  // open to guests so they can shop before signing in.
  if (loc.startsWith('/product/')) return true;
  if (loc.startsWith('/bundles/')) return true;
  if (loc.startsWith('/payments/return/')) return true;
  return false;
}

/// Customer app router. Guests can browse + check out; signed-in customers
/// get the full surface. Non-customer accounts land on /wrong-app.
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
        if (_isGuestAllowed(loc)) return null;
        // Stash where the user wanted to go so we can send them back there
        // after sign-in. Example: protected /orders → /login?next=/orders.
        final next = Uri.encodeComponent(loc);
        return '$_login?next=$next';
      }
      if (!session.user.role.isCustomer) {
        return loc == _wrongApp ? null : _wrongApp;
      }
      if (atAuthPage || loc == _wrongApp) {
        // Just signed in — honour ?next= if the caller set it, else home.
        final next = state.uri.queryParameters['next'];
        if (next != null && next.isNotEmpty && next.startsWith('/')) {
          return next;
        }
        return _home;
      }
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
      GoRoute(
        path: '/locations',
        builder: (_, __) => const LocationsScreen(),
      ),
      // P3 — trust / legal / help content pages.
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
      GoRoute(path: '/faq', builder: (_, __) => const FaqScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),
      // P2 — marketing programs (each gates internally on admin toggle).
      GoRoute(path: '/referral', builder: (_, __) => const ReferralScreen()),
      GoRoute(path: '/gift-cards', builder: (_, __) => const GiftCardScreen()),
      GoRoute(
          path: '/subscription',
          builder: (_, __) => const SubscriptionScreen()),
      GoRoute(path: '/catering', builder: (_, __) => const CateringScreen()),
      GoRoute(path: '/rewards', builder: (_, __) => const RewardsScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersListScreen()),
      GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(
        path: '/bundles/:id',
        builder: (context, state) => BundleDetailScreen(
          bundleId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/membership',
        builder: (_, __) => const MembershipScreen(),
      ),
      // Voucher wallet — CUSTOMER-only (not in `_guestAllowed`, so the
      // redirect bounces guests to /login and non-customers to /wrong-app).
      GoRoute(
        path: '/vouchers',
        builder: (_, __) => const VoucherWalletScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: _changePassword,
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/addresses',
        builder: (_, __) => const AddressesScreen(),
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
        builder: (context, state) {
          // Carry `?next=` through to the register screen so users who
          // bounce between login/register still end up where they wanted.
          final next = state.uri.queryParameters['next'];
          final regPath = next == null
              ? _register
              : '$_register?next=${Uri.encodeComponent(next)}';
          return Stack(
            children: [
              LoginScreen(
                title: 'Banan Fukuoka Saigon',
                subtitle: "Sign in to order today's creations.",
                showRegisterLink: true,
                onRegisterTapped: () => context.go(regPath),
              ),
              // "Forgot password?" link pinned below the centred login form.
              // LoginScreen is a shared widget without a slot for it, so we
              // overlay it here in the customer route.
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: SafeArea(
                  child: Center(
                    child: TextButton(
                      onPressed: () => context.push(_forgotPassword),
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      GoRoute(
        path: _register,
        builder: (context, state) {
          final next = state.uri.queryParameters['next'];
          final loginPath = next == null
              ? _login
              : '$_login?next=${Uri.encodeComponent(next)}';
          return RegisterScreen(
            onBackToLogin: () => context.go(loginPath),
          );
        },
      ),
      GoRoute(
        path: _forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: _resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: _changeEmail,
        builder: (context, state) => ChangeEmailConfirmScreen(
          token: state.uri.queryParameters['token'] ?? '',
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
