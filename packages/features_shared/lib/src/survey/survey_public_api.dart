import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'survey_public_models.dart';

/// Fully public survey API — plain Dio, NO auth interceptor and no tokens.
/// A guest (or any logged-in browser) hits the same two endpoints; the
/// backend path keeps its `/internal/survey/public` prefix (module layout),
/// but nothing about it requires a session.
class SurveyPublicApi {
  SurveyPublicApi(this._dio);
  final Dio _dio;

  /// Published template + LIVE store list + reward teaser, one call.
  Future<Result<SurveyPublicInfo, AppFailure>> surveyInfo() async {
    try {
      final res = await _dio.get<dynamic>('/internal/survey/public');
      final status = res.statusCode ?? 0;
      final body = res.data;
      if (status >= 400) return Result.failure(_failureOf(status, body));
      final data = body is Map<String, dynamic> ? body['data'] : body;
      return Result.success(SurveyPublicInfo.fromJson(data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(_failureOf(e.response!.statusCode ?? 0, e.response!.data));
      }
      return Result.failure(NetworkFailure(cause: e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  /// Submit — idempotent on `clientRequestId` (retry returns the same
  /// response + reward).
  Future<Result<SurveySubmitResult, AppFailure>> surveySubmit(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<dynamic>('/internal/survey/public/responses', data: body);
      final status = res.statusCode ?? 0;
      final resBody = res.data;
      if (status >= 400) return Result.failure(_failureOf(status, resBody));
      final data = resBody is Map<String, dynamic> ? resBody['data'] : resBody;
      return Result.success(SurveySubmitResult.fromJson(data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(_failureOf(e.response!.statusCode ?? 0, e.response!.data));
      }
      return Result.failure(NetworkFailure(cause: e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  AppFailure _failureOf(int status, dynamic body) {
    var code = 'HTTP_$status';
    String? message;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        code = (err['code'] as String?) ?? code;
        message = err['message'] as String?;
      }
    }
    return ServerFailure(code: code, message: message);
  }
}

/// Bare (unauthenticated) client — deliberately NOT the shared authed Dio,
/// so no Bearer token ever rides along with a guest submission.
final surveyPublicApiProvider = Provider<SurveyPublicApi>((ref) {
  return SurveyPublicApi(createDioClient());
});
