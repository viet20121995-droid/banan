import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import '../dtos/customer_directory_dto.dart';
import 'errors.dart';

class CustomersApi {
  CustomersApi(this._dio);
  final Dio _dio;

  Future<Result<CustomerPage, AppFailure>> list({
    String? q,
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/customers',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          'page': page,
          'perPage': perPage,
        },
      );
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>?;
      return Result.success(
        CustomerPage(
          items: raw
              .map((e) =>
                  CustomerSummaryDto.fromJson(e as Map<String, dynamic>)
                      .toDomain(),)
              .toList(),
          page: (meta?['page'] as num?)?.toInt() ?? page,
          perPage: (meta?['perPage'] as num?)?.toInt() ?? perPage,
          total: (meta?['total'] as num?)?.toInt() ?? raw.length,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<CustomerDetail, AppFailure>> detail(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/customers/$id',
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(CustomerDetailDto.fromJson(data).toDomain());
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<void, AppFailure>> notify(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<dynamic>(
        '/merchant/customers/$id/notify',
        data: body,
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

  /// Create a brand-new customer account from the merchant side — used
  /// when a phone customer places an order and the merchant wants a record.
  /// Returns the minimal `{id, fullName, phone, email}` shape.
  Future<Result<Map<String, dynamic>, AppFailure>> create({
    required String fullName,
    required String phone,
    String? email,
    String? notes,
  }) =>
      post('/merchant/customers', {
        'fullName': fullName,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

  Future<Result<Map<String, dynamic>, AppFailure>> post(
    String path,
    Map<String, dynamic> body,
  ) =>
      _send(() => _dio.post<Map<String, dynamic>>(path, data: body));

  Future<Result<Map<String, dynamic>, AppFailure>> patch(
    String path,
    Map<String, dynamic> body,
  ) =>
      _send(() => _dio.patch<Map<String, dynamic>>(path, data: body));

  Future<Result<Map<String, dynamic>, AppFailure>> _send(
    Future<Response<Map<String, dynamic>>> Function() run,
  ) async {
    try {
      final res = await run();
      final code = res.statusCode ?? 0;
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (code < 200 || code >= 300 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(data);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
