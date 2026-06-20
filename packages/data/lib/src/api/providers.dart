import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/json_cache.dart';
import '../local/secure_token_storage.dart';
import '../repositories/addresses_repository_impl.dart';
import '../repositories/admin_repository_impl.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/banners_repository_impl.dart';
import '../repositories/catalog_repository_impl.dart';
import '../repositories/collections_repository_impl.dart';
import '../repositories/customers_repository_impl.dart';
import '../repositories/loyalty_repository_impl.dart';
import '../repositories/merchant_coupons_repository_impl.dart';
import '../repositories/notifications_repository_impl.dart';
import '../repositories/order_repository_impl.dart';
import '../repositories/refund_repository_impl.dart';
import '../repositories/store_settings_repository_impl.dart';
import '../repositories/stores_repository_impl.dart';
import '../repositories/threads_repository_impl.dart';
import '../ws/socket_client.dart';
import 'addresses_api.dart';
import 'admin_api.dart';
import 'analytics_api.dart';
import 'auth_api.dart';
import 'banners_api.dart';
import 'bundles_api.dart';
import 'campaigns_api.dart';
import 'catalog_api.dart';
import 'collections_api.dart';
import 'contact_api.dart';
import 'customers_api.dart';
import 'devices_api.dart';
import 'dio_client.dart';
import 'display_config_api.dart';
import 'geo_api.dart';
import 'gift_cards_api.dart';
import 'health_api.dart';
import 'interceptors/auth_interceptor.dart';
import 'loyalty_api.dart';
import 'marketing_api.dart';
import 'merchant_coupons_api.dart';
import 'merchant_tools_api.dart';
import 'newsletter_api.dart';
import 'notifications_api.dart';
import 'orders_api.dart';
import 'promo_popup_api.dart';
import 'refunds_api.dart';
import 'reports_api.dart';
import 'reviews_api.dart';
import 'site_content_api.dart';
import 'store_settings_api.dart';
import 'stores_api.dart';
import 'threads_api.dart';
import 'wishlist_api.dart';

/// Singleton Dio instance shared across the app — wired with the auth
/// interceptor so every repository call inherits "attach token + refresh on 401".
// Explicit type annotations break a top-level inference cycle:
// dioProvider → AuthInterceptor → authRepositoryProvider → authApiProvider → dioProvider.
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final dio = createDioClient();
  final storage = ref.watch(tokenStorageProvider);

  // Lazy refresh callback — breaks the dio ↔ repo construction cycle.
  Future<bool> refresh() async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.refresh();
    return result.isSuccess;
  }

  dio.interceptors.add(
    AuthInterceptor(tokenStorage: storage, refresh: refresh, dio: dio),
  );

  ref.onDispose(dio.close);
  return dio;
});

/// Persistent token storage (Keychain / Keystore / encrypted web storage).
final Provider<TokenStorage> tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

/// Low-level auth API — used by the repository, never by widgets.
final Provider<AuthApi> authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);

/// Repository: the only auth surface widgets / controllers should use.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    storage: ref.watch(tokenStorageProvider),
  ),
);

/// Reactive auth session stream. UI watches this for redirect decisions.
final StreamProvider<AuthSession?> authSessionProvider =
    StreamProvider<AuthSession?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchSession();
});

/// `/health` probe API — used by the splash screen.
final Provider<HealthApi> healthApiProvider = Provider<HealthApi>(
  (ref) => HealthApi(ref.watch(dioProvider)),
);

/// Geo / ward catalog + delivery-fee quote API. Public endpoints.
final Provider<GeoApi> geoApiProvider = Provider<GeoApi>(
  (ref) => GeoApi(ref.watch(dioProvider)),
);

/// Product reviews API — public read, customer create/delete, merchant moderate.
final Provider<ReviewsApi> reviewsApiProvider = Provider<ReviewsApi>(
  (ref) => ReviewsApi(ref.watch(dioProvider)),
);

/// Merchant + admin reports API — KPIs, best-sellers, XLSX export.
final Provider<ReportsApi> reportsApiProvider = Provider<ReportsApi>(
  (ref) => ReportsApi(ref.watch(dioProvider)),
);

/// Chain-wide customer display preferences (stock badge on/off, …).
final Provider<DisplayConfigApi> displayConfigApiProvider =
    Provider<DisplayConfigApi>(
  (ref) => DisplayConfigApi(ref.watch(dioProvider)),
);

/// Newsletter subscribe (public) + merchant subscriber CRUD.
final Provider<NewsletterApi> newsletterApiProvider = Provider<NewsletterApi>(
  (ref) => NewsletterApi(ref.watch(dioProvider)),
);

/// Public customer-support contact form.
final Provider<ContactApi> contactApiProvider = Provider<ContactApi>(
  (ref) => ContactApi(ref.watch(dioProvider)),
);

/// Gift cards — public validate + admin issue/list/deactivate.
final Provider<GiftCardsApi> giftCardsApiProvider = Provider<GiftCardsApi>(
  (ref) => GiftCardsApi(ref.watch(dioProvider)),
);

/// Admin-controlled marketing programs (referral, gift card, subscription,
/// catering, rewards) — public read for gating + admin write.
final Provider<MarketingApi> marketingApiProvider = Provider<MarketingApi>(
  (ref) => MarketingApi(ref.watch(dioProvider)),
);

/// Reactive marketing config — customer surfaces gate on this. Falls back to
/// "all disabled" so a fetch failure simply hides every program.
final FutureProvider<MarketingConfig> marketingConfigProvider =
    FutureProvider<MarketingConfig>((ref) async {
  final res = await ref.watch(marketingApiProvider).get();
  return res.when(
    success: (c) => c,
    failure: (_) => MarketingConfig.empty,
  );
});

/// Push device-token registration (FCM web/mobile).
final Provider<DevicesApi> devicesApiProvider = Provider<DevicesApi>(
  (ref) => DevicesApi(ref.watch(dioProvider)),
);

/// Merchant bulk ops (CSV import, bulk price) + campaign broadcast.
final Provider<MerchantToolsApi> merchantToolsApiProvider =
    Provider<MerchantToolsApi>(
  (ref) => MerchantToolsApi(ref.watch(dioProvider)),
);

/// Editable static page content (FAQ, About) — public read + merchant edit.
final Provider<SiteContentApi> siteContentApiProvider =
    Provider<SiteContentApi>(
  (ref) => SiteContentApi(ref.watch(dioProvider)),
);

/// Customer-facing FAQ content (falls back to backend defaults).
final FutureProvider<SiteContent> faqContentProvider =
    FutureProvider<SiteContent>((ref) async {
  final res = await ref.watch(siteContentApiProvider).get('faq');
  return res.when(
    success: (c) => c,
    failure: (_) => const SiteContent(key: 'faq', data: {}, isDefault: true),
  );
});

/// Customer-facing About content (falls back to backend defaults).
final FutureProvider<SiteContent> aboutContentProvider =
    FutureProvider<SiteContent>((ref) async {
  final res = await ref.watch(siteContentApiProvider).get('about');
  return res.when(
    success: (c) => c,
    failure: (_) => const SiteContent(key: 'about', data: {}, isDefault: true),
  );
});

/// Bundles / combos — public read-only catalog.
final Provider<BundlesApi> bundlesApiProvider = Provider<BundlesApi>(
  (ref) => BundlesApi(ref.watch(dioProvider)),
);

/// Reactive snapshot of the display config — every widget that gates UI
/// on a preference (e.g. stock badges) watches this. Refetches when the
/// merchant toggles a value (provider invalidated by the admin screen).
final FutureProvider<DisplayConfig> displayConfigProvider =
    FutureProvider<DisplayConfig>((ref) async {
  final api = ref.watch(displayConfigApiProvider);
  final res = await api.get();
  return res.when(
    success: (c) => c,
    failure: (_) => const DisplayConfig(showStockToCustomers: false),
  );
});

/// Customer wishlist API.
final Provider<WishlistApi> wishlistApiProvider = Provider<WishlistApi>(
  (ref) => WishlistApi(ref.watch(dioProvider)),
);

/// HCMC ward catalog — cached for the session. Customer's address form
/// reads from this for the ward dropdown.
final FutureProvider<List<HcmWard>> hcmWardsProvider =
    FutureProvider<List<HcmWard>>((ref) async {
  final api = ref.watch(geoApiProvider);
  final res = await api.hcmWards();
  return res.when(
    success: (list) => list,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Optional read-through cache for catalog responses. Only set on the
/// customer app where we want offline browsing — staff apps leave it null.
/// Override this provider with a `JsonCache` backed by an open Hive box.
final Provider<JsonCache?> catalogCacheProvider = Provider<JsonCache?>(
  (ref) => null,
);

/// Catalog API surface (categories + products + uploads).
final Provider<CatalogApi> catalogApiProvider = Provider<CatalogApi>(
  (ref) => CatalogApi(
    ref.watch(dioProvider),
    cache: ref.watch(catalogCacheProvider),
  ),
);

/// Catalog repository — used by menu, product detail, and merchant editor.
final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(ref.watch(catalogApiProvider)),
);

/// Categories list. Cached for the session — invalidate on admin edits.
final FutureProvider<List<Category>> categoriesProvider =
    FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final result = await repo.categories();
  return result.when(
    success: (list) => list,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Pinned home categories — each carries its own `products` array, rendered as
/// horizontal strips on the customer home page. Invalidate on catalog change.
final FutureProvider<List<Category>> pinnedCategoriesProvider =
    FutureProvider<List<Category>>((ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final result = await repo.homeCategories();
  return result.when(
    success: (list) => list,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Orders API + repository (customer + merchant flows).
final Provider<OrdersApi> ordersApiProvider = Provider<OrdersApi>(
  (ref) => OrdersApi(ref.watch(dioProvider)),
);

final Provider<OrderRepository> orderRepositoryProvider =
    Provider<OrderRepository>(
  (ref) => OrderRepositoryImpl(ref.watch(ordersApiProvider)),
);

/// Owns the Socket.IO connection for the active session. Disposed when the
/// session goes null (logout) or the access token rotates (we reconnect with
/// the fresh token via the interceptor's session emission).
final Provider<SocketClient?> socketClientProvider = Provider<SocketClient?>(
  (ref) {
    // Connect for everyone — guests included — so realtime catalog sync
    // reaches browsers that haven't logged in. The token (when present) also
    // joins the user's order/store/kitchen rooms; rebuilt on login/logout so
    // the connection swaps between anonymous ↔ authed.
    final session = ref.watch(authSessionProvider).valueOrNull;
    final client = SocketClient.connect(
      url: Env.wsUrl,
      accessToken: session?.accessToken,
    );
    ref.onDispose(client.dispose);
    return client;
  },
);

/// Stream of realtime events for any consumer (orders list, tracking, etc.).
/// Filter by `event.event` and `event.data['orderId']` in the consumer.
final StreamProvider<RealtimeEvent> realtimeEventsProvider =
    StreamProvider<RealtimeEvent>((ref) {
  final client = ref.watch(socketClientProvider);
  if (client == null) return const Stream<RealtimeEvent>.empty();
  return client.events;
});

/// Refunds API + repository — merchant inbox + approve/reject flow.
final Provider<RefundsApi> refundsApiProvider = Provider<RefundsApi>(
  (ref) => RefundsApi(ref.watch(dioProvider)),
);

final Provider<RefundRepository> refundRepositoryProvider =
    Provider<RefundRepository>(
  (ref) => RefundRepositoryImpl(ref.watch(refundsApiProvider)),
);

/// Loyalty + coupons APIs and repositories.
final Provider<LoyaltyApi> loyaltyApiProvider = Provider<LoyaltyApi>(
  (ref) => LoyaltyApi(ref.watch(dioProvider)),
);
final Provider<CouponsApi> couponsApiProvider = Provider<CouponsApi>(
  (ref) => CouponsApi(ref.watch(dioProvider)),
);
final Provider<LoyaltyRepository> loyaltyRepositoryProvider =
    Provider<LoyaltyRepository>(
  (ref) => LoyaltyRepositoryImpl(ref.watch(loyaltyApiProvider)),
);
final Provider<CouponRepository> couponRepositoryProvider =
    Provider<CouponRepository>(
  (ref) => CouponRepositoryImpl(ref.watch(couponsApiProvider)),
);

/// Customer's membership summary — invalidate after orders complete to refresh.
final FutureProvider<MembershipSummary> membershipSummaryProvider =
    FutureProvider<MembershipSummary>((ref) async {
  final repo = ref.watch(loyaltyRepositoryProvider);
  final res = await repo.me();
  return res.when(
    success: (s) => s,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Customer's voucher wallet (GET /coupons/mine) — available / used / expired.
/// Auto-disposed: only alive while the wallet screen is mounted.
final voucherWalletProvider =
    FutureProvider.autoDispose<VoucherWallet>((ref) async {
  final repo = ref.watch(couponRepositoryProvider);
  final res = await repo.myWallet();
  return res.when(
    success: (w) => w,
    failure: (f) => throw Exception(f.message ?? f.code),
  );
});

/// Analytics — merchant + kitchen dashboard summary endpoints.
final Provider<AnalyticsApi> analyticsApiProvider = Provider<AnalyticsApi>(
  (ref) => AnalyticsApi(ref.watch(dioProvider)),
);

/// In-app notifications inbox.
final Provider<NotificationsApi> notificationsApiProvider =
    Provider<NotificationsApi>(
  (ref) => NotificationsApi(ref.watch(dioProvider)),
);

final Provider<NotificationsRepository> notificationsRepositoryProvider =
    Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(ref.watch(notificationsApiProvider)),
);

/// Collections — merchant CRUD + customer home reads.
final Provider<CollectionsApi> collectionsApiProvider =
    Provider<CollectionsApi>(
  (ref) => CollectionsApi(ref.watch(dioProvider)),
);

final Provider<CollectionsRepository> collectionsRepositoryProvider =
    Provider<CollectionsRepository>(
  (ref) => CollectionsRepositoryImpl(ref.watch(collectionsApiProvider)),
);

/// Public store directory — customer-facing locations list + pickup picker.
final Provider<StoresApi> storesApiProvider = Provider<StoresApi>(
  (ref) => StoresApi(ref.watch(dioProvider)),
);

final Provider<StoresRepository> storesRepositoryProvider =
    Provider<StoresRepository>(
  (ref) => StoresRepositoryImpl(ref.watch(storesApiProvider)),
);

/// Merchant-only — settings panel + blackout date manager.
final Provider<StoreSettingsApi> storeSettingsApiProvider =
    Provider<StoreSettingsApi>(
  (ref) => StoreSettingsApi(ref.watch(dioProvider)),
);

final Provider<StoreSettingsRepository> storeSettingsRepositoryProvider =
    Provider<StoreSettingsRepository>(
  (ref) =>
      StoreSettingsRepositoryImpl(ref.watch(storeSettingsApiProvider)),
);

/// Threads — merchant CRUD + customer home reads.
final Provider<ThreadsApi> threadsApiProvider = Provider<ThreadsApi>(
  (ref) => ThreadsApi(ref.watch(dioProvider)),
);

final Provider<ThreadsRepository> threadsRepositoryProvider =
    Provider<ThreadsRepository>(
  (ref) => ThreadsRepositoryImpl(ref.watch(threadsApiProvider)),
);

/// Saved addresses — the signed-in customer's address book.
final Provider<AddressesApi> addressesApiProvider = Provider<AddressesApi>(
  (ref) => AddressesApi(ref.watch(dioProvider)),
);

final Provider<AddressesRepository> addressesRepositoryProvider =
    Provider<AddressesRepository>(
  (ref) => AddressesRepositoryImpl(ref.watch(addressesApiProvider)),
);

/// Merchant customer directory — list/search + detail card.
final Provider<CustomersApi> customersApiProvider = Provider<CustomersApi>(
  (ref) => CustomersApi(ref.watch(dioProvider)),
);

final Provider<CustomersRepository> customersRepositoryProvider =
    Provider<CustomersRepository>(
  (ref) => CustomersRepositoryImpl(ref.watch(customersApiProvider)),
);

/// Admin console — provision sub-accounts (merchant / kitchen / customer).
final Provider<AdminApi> adminApiProvider = Provider<AdminApi>(
  (ref) => AdminApi(ref.watch(dioProvider)),
);

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(ref.watch(adminApiProvider)),
);

/// Admin-tunable customer-facing promotional popup.
final Provider<PromoPopupApi> promoPopupApiProvider = Provider<PromoPopupApi>(
  (ref) => PromoPopupApi(ref.watch(dioProvider)),
);

/// Home hero banners — public read + merchant CRUD.
final Provider<BannersApi> bannersApiProvider = Provider<BannersApi>(
  (ref) => BannersApi(ref.watch(dioProvider)),
);

final Provider<BannersRepository> bannersRepositoryProvider =
    Provider<BannersRepository>(
  (ref) => BannersRepositoryImpl(ref.watch(bannersApiProvider)),
);

/// Merchant promo-code manager — shared / single-use coupon CRUD.
final Provider<MerchantCouponsApi> merchantCouponsApiProvider =
    Provider<MerchantCouponsApi>(
  (ref) => MerchantCouponsApi(ref.watch(dioProvider)),
);

final Provider<MerchantCouponsRepository> merchantCouponsRepositoryProvider =
    Provider<MerchantCouponsRepository>(
  (ref) =>
      MerchantCouponsRepositoryImpl(ref.watch(merchantCouponsApiProvider)),
);

/// Admin promotions manager — chain-wide / per-store campaign CRUD.
/// The API surface returns domain [Campaign] objects directly, so the
/// merchant screen watches/reads this provider with no separate repository.
final Provider<CampaignsApi> campaignsApiProvider = Provider<CampaignsApi>(
  (ref) => CampaignsApi(ref.watch(dioProvider)),
);

/// Alias kept for parity with the other repository-style providers — points
/// at the same [CampaignsApi]. Widgets may `ref.watch`/`ref.read` either name.
final Provider<CampaignsApi> campaignsRepositoryProvider =
    Provider<CampaignsApi>((ref) => ref.watch(campaignsApiProvider));
