import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/json_cache.dart';
import '../local/secure_token_storage.dart';
import '../repositories/auth_repository_impl.dart';
import '../repositories/catalog_repository_impl.dart';
import '../repositories/collections_repository_impl.dart';
import '../repositories/loyalty_repository_impl.dart';
import '../repositories/notifications_repository_impl.dart';
import '../repositories/order_repository_impl.dart';
import '../repositories/refund_repository_impl.dart';
import '../repositories/threads_repository_impl.dart';
import '../ws/socket_client.dart';
import 'analytics_api.dart';
import 'auth_api.dart';
import 'catalog_api.dart';
import 'collections_api.dart';
import 'dio_client.dart';
import 'health_api.dart';
import 'interceptors/auth_interceptor.dart';
import 'loyalty_api.dart';
import 'notifications_api.dart';
import 'orders_api.dart';
import 'refunds_api.dart';
import 'threads_api.dart';

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
    final session = ref.watch(authSessionProvider).valueOrNull;
    if (session == null) return null;
    final client = SocketClient.connect(
      url: Env.wsUrl,
      accessToken: session.accessToken,
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

/// Threads — merchant CRUD + customer home reads.
final Provider<ThreadsApi> threadsApiProvider = Provider<ThreadsApi>(
  (ref) => ThreadsApi(ref.watch(dioProvider)),
);

final Provider<ThreadsRepository> threadsRepositoryProvider =
    Provider<ThreadsRepository>(
  (ref) => ThreadsRepositoryImpl(ref.watch(threadsApiProvider)),
);
