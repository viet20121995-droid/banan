import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

/// Snapshot of `/health` — used by the splash to verify the backend is up
/// before we route into the app.
class HealthStatus {
  const HealthStatus({
    required this.ok,
    required this.environment,
    required this.timestamp,
  });

  final bool ok;
  final String environment;
  final DateTime timestamp;
}

class HealthApi {
  HealthApi(this._dio);
  final Dio _dio;

  /// `GET /health` — returns the result envelope-mapped to a [HealthStatus].
  /// On failure returns a typed [AppFailure].
  Future<Result<HealthStatus, AppFailure>> getHealth() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/health');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (res.statusCode == 200 && data != null) {
        return Result.success(
          HealthStatus(
            ok: data['ok'] as bool? ?? false,
            environment: data['environment'] as String? ?? 'unknown',
            timestamp: DateTime.tryParse(data['timestamp'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      }
      return const Result.failure(
        ServerFailure(
          code: 'HEALTH_BAD_RESPONSE',
          message: 'Unexpected response from /health',
        ),
      );
    } on DioException catch (e, st) {
      log('health').warning('health probe failed', e, st);
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return Result.failure(TimeoutFailure(cause: e));
      }
      return Result.failure(NetworkFailure(message: e.message, cause: e));
    } catch (e, st) {
      log('health').severe('unexpected health error', e, st);
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
