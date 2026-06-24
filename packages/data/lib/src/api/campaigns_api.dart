import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import '../dtos/campaign_dto.dart';
import 'errors.dart';

/// Admin-only promotions API. Base path `/merchant/campaigns`. Responses are
/// enveloped as `{ data: ... }` — same envelope pattern as the merchant
/// coupons API.
class CampaignsApi {
  CampaignsApi(this._dio);
  final Dio _dio;

  /// Lists campaigns, optionally filtered to a single [type] (wire string).
  Future<Result<List<Campaign>, AppFailure>> list({String? type}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/campaigns',
        queryParameters: type == null ? null : {'type': type},
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map(
              (e) =>
                  CampaignDto.fromJson(e as Map<String, dynamic>).toDomain(),
            )
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Campaign, AppFailure>> get(String id) =>
      _send(() => _dio.get<Map<String, dynamic>>('/merchant/campaigns/$id'));

  Future<Result<Campaign, AppFailure>> create(Map<String, dynamic> body) =>
      _send(
        () => _dio.post<Map<String, dynamic>>(
          '/merchant/campaigns',
          data: body,
        ),
      );

  Future<Result<Campaign, AppFailure>> update(
    String id,
    Map<String, dynamic> body,
  ) =>
      _send(
        () => _dio.patch<Map<String, dynamic>>(
          '/merchant/campaigns/$id',
          data: body,
        ),
      );

  Future<Result<void, AppFailure>> delete(String id) async {
    try {
      final res = await _dio.delete<Map<String, dynamic>>(
        '/merchant/campaigns/$id',
      );
      final code = res.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Campaign, AppFailure>> _send(
    Future<Response<Map<String, dynamic>>> Function() run,
  ) async {
    try {
      final res = await run();
      final code = res.statusCode ?? 0;
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (code < 200 || code >= 300 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(CampaignDto.fromJson(data).toDomain());
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
