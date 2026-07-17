import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:dio/dio.dart';

import '../dtos/admin_user_dto.dart';
import 'errors.dart';

class AdminApi {
  AdminApi(this._dio);
  final Dio _dio;

  Future<Result<AdminUserPage, AppFailure>> listUsers({
    String? role,
    String? q,
    int page = 1,
    int perPage = 30,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/users',
        queryParameters: {
          if (role != null && role.isNotEmpty) 'role': role,
          if (q != null && q.isNotEmpty) 'q': q,
          'page': page,
          'perPage': perPage,
        },
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>?;
      return Result.success(
        AdminUserPage(
          items: raw
              .map((e) =>
                  AdminUserDto.fromJson(e as Map<String, dynamic>).toDomain(),)
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

  Future<Result<AdminUser, AppFailure>> createUser(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/admin/users',
        data: body,
      );
      final code = res.statusCode ?? 0;
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (code < 200 || code >= 300 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(AdminUserDto.fromJson(data).toDomain());
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<AdminUser, AppFailure>> updateUser(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/admin/users/$id',
        data: body,
      );
      final code = res.statusCode ?? 0;
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (code < 200 || code >= 300 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(AdminUserDto.fromJson(data).toDomain());
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<bool, AppFailure>> resetUserPassword(
    String id,
    String password,
  ) async {
    try {
      final res = await _dio.post<dynamic>(
        '/admin/users/$id/reset-password',
        data: {'password': password},
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(true);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<bool, AppFailure>> deactivateUser(String id) async {
    try {
      final res = await _dio.delete<dynamic>('/admin/users/$id');
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return const Result.success(true);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<List<OrgOption>, AppFailure>> _options(String path) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path);
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) =>
                OrgOptionDto.fromJson(e as Map<String, dynamic>).toDomain(),)
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<List<OrgOption>, AppFailure>> stores() =>
      _options('/admin/stores');

  Future<Result<List<OrgOption>, AppFailure>> kitchens() =>
      _options('/admin/kitchens');
}
