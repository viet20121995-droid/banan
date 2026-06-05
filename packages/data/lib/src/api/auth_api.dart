import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/auth_response_dto.dart';
import '../dtos/user_dto.dart';
import 'errors.dart';

/// Marker on Dio request `extra` — when set, the auth interceptor will not
/// attempt to refresh on 401 (used internally for refresh / logout itself).
const kSkipAuthRefresh = 'banan.skipAuthRefresh';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<Result<AuthResponseDto, AppFailure>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    DateTime? birthday,
  }) async {
    return _post('/auth/register', {
      'email': email,
      'password': password,
      'fullName': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (birthday != null)
        'birthday':
            DateTime.utc(birthday.year, birthday.month, birthday.day)
                .toIso8601String(),
    });
  }

  Future<Result<AuthResponseDto, AppFailure>> login({
    required String emailOrPhone,
    required String password,
  }) async {
    return _post('/auth/login', {
      'emailOrPhone': emailOrPhone,
      'password': password,
    });
  }

  /// Refresh runs with `kSkipAuthRefresh` so the interceptor doesn't try to
  /// refresh-on-401 in a loop if this call itself returns 401.
  Future<Result<AuthResponseDto, AppFailure>> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: const {kSkipAuthRefresh: true}),
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (res.statusCode != 200 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(AuthResponseDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<UserDto, AppFailure>> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = res.data?['data'] as Map<String, dynamic>?;
      final userJson = data?['user'] as Map<String, dynamic>?;
      if (res.statusCode != 200 || userJson == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(UserDto.fromJson(userJson));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Self-service profile update. Sends only the fields the caller wants to
  /// change; returns the refreshed user.
  Future<Result<UserDto, AppFailure>> updateProfile({
    String? fullName,
    String? phone,
    DateTime? birthday,
    bool clearBirthday = false,
    String? avatarUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (clearBirthday)
          'birthday': null
        else if (birthday != null)
          'birthday':
              DateTime.utc(birthday.year, birthday.month, birthday.day)
                  .toIso8601String(),
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };
      final res = await _dio.patch<Map<String, dynamic>>(
        '/auth/me',
        data: body,
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      final userJson = data?['user'] as Map<String, dynamic>?;
      if (res.statusCode != 200 || userJson == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(UserDto.fromJson(userJson));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
        options: Options(extra: const {kSkipAuthRefresh: true}),
      );
    } catch (_) {
      // Logout is best-effort — local tokens get cleared regardless.
    }
  }

  /// Change password for the signed-in user (verifies current password).
  Future<Result<bool, AppFailure>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _ok('/auth/change-password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  /// Request a password-reset email. Server always returns 200 (no account
  /// enumeration), so success just means the request was accepted.
  Future<Result<bool, AppFailure>> forgotPassword(String email) =>
      _ok('/auth/forgot-password', {'email': email}, skipRefresh: true);

  /// Complete a password reset using the token from the email link.
  Future<Result<bool, AppFailure>> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _ok(
        '/auth/reset-password',
        {'token': token, 'newPassword': newPassword},
        skipRefresh: true,
      );

  /// POST a body and return success/failure only (no payload).
  Future<Result<bool, AppFailure>> _ok(
    String path,
    Map<String, dynamic> body, {
    bool skipRefresh = false,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        path,
        data: body,
        options:
            skipRefresh ? Options(extra: const {kSkipAuthRefresh: true}) : null,
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) return Result.success(true);
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<AuthResponseDto, AppFailure>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(extra: const {kSkipAuthRefresh: true}),
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if ((res.statusCode == 200 || res.statusCode == 201) && data != null) {
        return Result.success(AuthResponseDto.fromJson(data));
      }
      return Result.failure(mapHttpStatusToFailure(res));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
