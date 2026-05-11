/// Banan data layer — Dio HTTP client, WebSocket client, DTOs, repository
/// implementations. Auth surface lands in M1; richer endpoints follow.
library;

export 'src/api/analytics_api.dart';
export 'src/api/auth_api.dart' show kSkipAuthRefresh;
export 'src/api/catalog_api.dart';
export 'src/api/collections_api.dart';
export 'src/api/dio_client.dart';
export 'src/api/errors.dart';
export 'src/api/health_api.dart';
export 'src/api/loyalty_api.dart';
export 'src/api/notifications_api.dart';
export 'src/api/orders_api.dart';
export 'src/api/providers.dart';
export 'src/api/refunds_api.dart';
export 'src/api/threads_api.dart';
export 'src/local/catalog_cache_init.dart';
export 'src/local/json_cache.dart';
export 'src/local/secure_token_storage.dart';
export 'src/ws/socket_client.dart' show RealtimeEvent, SocketClient;
