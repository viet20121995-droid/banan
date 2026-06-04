import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// Public customer-support contact form. Posts to `POST /contact`, which
/// emails the submission to the support inbox server-side.
class ContactApi {
  ContactApi(this._dio);
  final Dio _dio;

  Future<Result<void, AppFailure>> submit({
    required String name,
    required String email,
    required String message,
    String? phone,
    String? subject,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/contact',
        data: {
          'name': name,
          'email': email,
          'message': message,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (subject != null && subject.trim().isNotEmpty)
            'subject': subject.trim(),
        },
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(null);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
