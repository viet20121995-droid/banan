import 'package:banan_domain/banan_domain.dart';

/// Pure route-access rules for the customer app — NO widget or web-only
/// imports, so VM tests can exercise the whole matrix by importing just
/// this file (router.dart transitively pulls `dart:js_interop` screens).
const loginPath = '/login';
const registerPath = '/register';
const forgotPasswordPath = '/forgot-password';
const resetPasswordPath = '/reset-password';
const changePasswordPath = '/change-password';
const changeEmailPath = '/change-email';
const wrongAppPath = '/wrong-app';
const homePath = '/';

/// Routes a guest (unauthenticated) shopper is allowed to access. Browsing,
/// product detail, cart, checkout (with guest fields), payment return, and
/// the auth screens themselves. Everything else (orders history, membership,
/// notifications) is gated to logged-in customers.
const _guestAllowed = <String>{
  homePath,
  '/cart',
  '/checkout',
  '/locations',
  // Public trust / legal / help pages (P3) — browsable without an account.
  '/privacy',
  '/terms',
  '/faq',
  '/about',
  '/contact',
  '/shipping',
  '/payment-policy',
  '/refund-policy',
  // P2 marketing surfaces — browsable; the pages themselves gate on the
  // admin toggle + prompt login where needed (referral / rewards).
  '/referral',
  '/gift-cards',
  '/subscription',
  '/catering',
  '/rewards',
  loginPath,
  registerPath,
  // Account recovery — reachable without a session (the user is locked out).
  forgotPasswordPath,
  resetPasswordPath,
  // Email-change confirmation — opened from the link emailed to the new
  // address; the change logs the user out, so it must be guest-allowed.
  changeEmailPath,
};

bool _isGuestAllowed(String loc) {
  if (_guestAllowed.contains(loc)) return true;
  // Path-prefix matches (these accept :id segments). Browsing surfaces —
  // products, bundles/combos, and the payment-return bridge — are all
  // open to guests so they can shop before signing in.
  if (loc.startsWith('/product/')) return true;
  if (loc.startsWith('/bundles/')) return true;
  if (loc.startsWith('/payments/return/')) return true;
  // Public order tracking — the merchant-shared link + post-payment redirect.
  // The order id in the path is the capability; no session required.
  if (loc.startsWith('/track/')) return true;
  return false;
}

/// Pure redirect rule — `role == null` means no session. Returns where to
/// send the user, or null to stay.
String? customerRedirect({required Uri uri, required Role? role}) {
  final loc = uri.path;
  final atAuthPage = loc == loginPath || loc == registerPath;

  // The dine-in survey is THE public link on every printed QR — open to
  // guests AND to any signed-in account (even non-customer roles, which
  // normally bounce to /wrong-app). Never gate it.
  if (loc == '/survey') return null;

  if (role == null) {
    if (_isGuestAllowed(loc)) return null;
    // Stash where the user wanted to go so we can send them back there
    // after sign-in. Example: protected /orders → /login?next=/orders.
    final next = Uri.encodeComponent(loc);
    return '$loginPath?next=$next';
  }
  if (!role.isCustomer) {
    return loc == wrongAppPath ? null : wrongAppPath;
  }
  if (atAuthPage || loc == wrongAppPath) {
    // Just signed in — honour ?next= if the caller set it, else home.
    final next = uri.queryParameters['next'];
    if (next != null && next.isNotEmpty && next.startsWith('/')) {
      return next;
    }
    return homePath;
  }
  return null;
}
