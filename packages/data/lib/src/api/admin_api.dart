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
              .map(
                (e) =>
                    AdminUserDto.fromJson(e as Map<String, dynamic>).toDomain(),
              )
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

  /// Staff action trail (admin only), newest first. `from`/`to` are
  /// `yyyy-MM-dd` VN calendar days.
  Future<Result<AuditPage, AppFailure>> listAuditLog({
    String? q,
    String? from,
    String? to,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/admin/audit-log',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
          'page': page,
          'perPage': perPage,
        },
      );
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>?;
      return Result.success(
        AuditPage(
          items: raw
              .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
          total: (meta?['total'] as num?)?.toInt() ?? raw.length,
        ),
      );
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
            .map(
              (e) =>
                  OrgOptionDto.fromJson(e as Map<String, dynamic>).toDomain(),
            )
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

  /// Active staff records without a login yet, for linking a new TRAINEE
  /// account. Reuses the internal-ops people endpoint (ADMIN-only).
  Future<Result<List<OrgOption>, AppFailure>> unlinkedPeople() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/internal/training/people');
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success([
        for (final e in raw.whereType<Map<String, dynamic>>())
          if (e['userId'] == null && (e['isActive'] as bool? ?? true))
            OrgOption(
              id: e['id'] as String,
              name: [
                (e['fullName'] as String?) ?? '?',
                if (e['position'] is String) e['position'] as String,
                if ((e['store'] as Map<String, dynamic>?)?['name'] is String)
                  (e['store'] as Map<String, dynamic>)['name'] as String,
              ].join(' · '),
            ),
      ]);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}

/// One row of the staff action trail — read straight from the API.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.method,
    required this.path,
    required this.status,
    this.email,
    this.role,
    this.ip,
    this.userAgent,
    this.body,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id'] as String,
        at: DateTime.parse(json['at'] as String),
        method: json['method'] as String? ?? '',
        path: json['path'] as String? ?? '',
        status: (json['status'] as num?)?.toInt() ?? 0,
        email: json['email'] as String?,
        role: json['role'] as String?,
        ip: json['ip'] as String?,
        userAgent: json['userAgent'] as String?,
        body: json['body'],
      );

  final String id;
  final DateTime at;
  final String method;
  final String path;
  final int status;
  final String? email;
  final String? role;
  final String? ip;
  final String? userAgent;
  final Object? body;
}

class AuditPage {
  const AuditPage({required this.items, required this.total});
  final List<AuditEntry> items;
  final int total;
}
