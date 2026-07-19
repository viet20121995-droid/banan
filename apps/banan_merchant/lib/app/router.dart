import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin_mgmt/accounts_screen.dart';
import '../features/admin_mgmt/delivery_config_screen.dart';
import '../features/admin_mgmt/display_config_screen.dart';
import '../features/admin_mgmt/promo_popup_screen.dart';
import '../features/banners_mgmt/banners_screen.dart';
import '../features/broadcast_mgmt/broadcast_screen.dart';
import '../features/bulk_tools/bulk_tools_screen.dart';
import '../features/bundles_mgmt/bundle_editor_screen.dart';
import '../features/bundles_mgmt/bundles_list_screen.dart';
import '../features/campaigns_mgmt/campaigns_screen.dart';
import '../features/categories_mgmt/categories_list_screen.dart';
import '../features/categories_mgmt/category_editor_screen.dart';
import '../features/collections_mgmt/collection_editor_screen.dart';
import '../features/collections_mgmt/collections_list_screen.dart';
import '../features/content_mgmt/site_content_editor_screen.dart';
import '../features/coupons_mgmt/coupons_screen.dart';
import '../features/customers_mgmt/customer_detail_screen.dart';
import '../features/customers_mgmt/customers_list_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/gift_cards_mgmt/gift_cards_screen.dart';
import '../features/kitchens_mgmt/kitchen_editor_screen.dart';
import '../features/kitchens_mgmt/kitchens_list_screen.dart';
import '../features/marketing_mgmt/marketing_screen.dart';
import '../features/menu_mgmt/menu_list_screen.dart';
import '../features/menu_mgmt/product_editor_screen.dart';
import '../features/newsletter_mgmt/newsletter_screen.dart';
import '../features/orders_mgmt/channel_order_screens.dart';
import '../features/orders_mgmt/order_detail_screen.dart';
import '../features/orders_mgmt/orders_screen.dart';
import '../features/refunds/refunds_screen.dart';
import '../features/reports_mgmt/reports_screen.dart';
import '../features/reviews_mgmt/reviews_screen.dart';
import '../features/store_settings/store_settings_screen.dart';
import '../features/stores_mgmt/store_editor_screen.dart';
import '../features/stores_mgmt/stores_list_screen.dart';
import '../features/threads_mgmt/thread_editor_screen.dart';
import '../features/threads_mgmt/threads_list_screen.dart';
import '../features/wholesale_mgmt/wholesale_admin_screen.dart';

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
      // NOTE: static paths must precede the '/orders/:id' matcher.
      GoRoute(
        path: '/orders/counter',
        builder: (_, __) => const CounterOrderScreen(),
      ),
      GoRoute(
        path: '/orders/internal-transfer',
        redirect: (_, __) {
          final role = repo.currentSession?.user.role;
          return role == Role.merchantOwner || role == Role.admin
              ? null
              : _home;
        },
        builder: (_, __) => const InternalTransferScreen(),
      ),
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
      // P4 — bulk ops (CSV import + bulk price) and campaign broadcast.
      GoRoute(
        path: '/tools/bulk',
        builder: (_, __) => const BulkToolsScreen(),
      ),
      GoRoute(
        path: '/broadcast',
        builder: (_, __) => const BroadcastScreen(),
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
        path: '/categories',
        builder: (_, __) => const CategoriesListScreen(),
      ),
      GoRoute(
        path: '/categories/new',
        builder: (_, __) => const CategoryEditorScreen(),
      ),
      GoRoute(
        path: '/categories/:id/edit',
        builder: (context, state) =>
            CategoryEditorScreen(categoryId: state.pathParameters['id']),
      ),
      // Chain infrastructure — admin-only (nav hides these from non-admins).
      GoRoute(
        path: '/stores',
        builder: (_, __) => const StoresListScreen(),
      ),
      GoRoute(
        path: '/stores/new',
        builder: (_, __) => const StoreEditorScreen(),
      ),
      GoRoute(
        path: '/stores/:id/edit',
        builder: (context, state) =>
            StoreEditorScreen(storeId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/kitchens',
        builder: (_, __) => const KitchensListScreen(),
      ),
      GoRoute(
        path: '/kitchens/new',
        builder: (_, __) => const KitchenEditorScreen(),
      ),
      GoRoute(
        path: '/kitchens/:id/edit',
        builder: (context, state) =>
            KitchenEditorScreen(kitchenId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/bundles',
        builder: (_, __) => const BundlesListScreen(),
      ),
      GoRoute(
        path: '/bundles/new',
        builder: (_, __) => const BundleEditorScreen(),
      ),
      GoRoute(
        path: '/bundles/:id',
        builder: (context, state) =>
            BundleEditorScreen(bundleId: state.pathParameters['id']),
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
        path: '/admin/accounts',
        builder: (_, __) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/admin/wholesale',
        redirect: (_, __) =>
            repo.currentSession?.user.role == Role.admin ? null : _home,
        builder: (_, __) => const WholesaleAdminScreen(),
      ),
      GoRoute(
        path: '/admin/delivery-config',
        builder: (_, __) => const DeliveryConfigScreen(),
      ),
      GoRoute(
        path: '/admin/promo-popup',
        builder: (_, __) => const PromoPopupScreen(),
      ),
      GoRoute(
        path: '/admin/display',
        builder: (_, __) => const DisplayConfigScreen(),
      ),
      GoRoute(
        path: '/reviews',
        builder: (_, __) => const ReviewsModerationScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/newsletter',
        builder: (_, __) => const NewsletterScreen(),
      ),
      GoRoute(
        path: '/banners',
        builder: (_, __) => const BannersScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const StoreSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/content',
        builder: (_, __) => const SiteContentEditorScreen(),
      ),
      GoRoute(
        path: '/marketing',
        builder: (_, __) => const MarketingScreen(),
      ),
      GoRoute(
        path: '/gift-cards',
        builder: (_, __) => const GiftCardsScreen(),
      ),
      GoRoute(
        path: '/coupons',
        builder: (_, __) => const CouponsScreen(),
      ),
      GoRoute(
        path: '/campaigns',
        builder: (_, __) => const CampaignsScreen(),
      ),
      GoRoute(
        path: '/customers',
        builder: (_, __) => const CustomersListScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) => CustomerDetailScreen(
          customerId: state.pathParameters['id']!,
        ),
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
