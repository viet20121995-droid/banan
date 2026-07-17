import 'dart:async';

import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';

import '../api/auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthApi api, required TokenStorage storage})
      : _api = api,
        _storage = storage;

  final AuthApi _api;
  final TokenStorage _storage;

  final _sessionController = StreamController<AuthSession?>.broadcast();
  AuthSession? _session;
  Future<Result<AuthSession, AppFailure>>? _refreshing;

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> watchSession() => _sessionController.stream;

  @override
  Future<void> bootstrap() async {
    final tokens = await _storage.read();
    if (tokens == null) {
      _emit(null);
      return;
    }
    final meResult = await _api.me();
    await meResult.when(
      success: (userDto) async {
        _emit(
          AuthSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            user: userDto.toDomain(),
          ),
        );
      },
      failure: (failure) async {
        // /me failed — interceptor already attempted a refresh; if we got here
        // with a failure, tokens are dead. Wipe them.
        if (failure is AuthFailure) {
          await _storage.clear();
          _emit(null);
        } else {
          // Network / server error — keep tokens but emit null so app shows offline state.
          _emit(null);
        }
      },
    );
  }

  @override
  Future<Result<AuthSession, AppFailure>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    DateTime? birthday,
  }) async {
    final res = await _api.register(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      birthday: birthday,
    );
    return _completeAuth(res);
  }

  @override
  Future<Result<AuthSession, AppFailure>> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final res = await _api.login(
      emailOrPhone: emailOrPhone,
      password: password,
    );
    return _completeAuth(res);
  }

  @override
  Future<Result<User, AppFailure>> me() async {
    final res = await _api.me();
    return res.map((dto) => dto.toDomain());
  }

  @override
  Future<Result<bool, AppFailure>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

  @override
  Future<Result<bool, AppFailure>> forgotPassword(String email) =>
      _api.forgotPassword(email);

  @override
  Future<Result<bool, AppFailure>> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _api.resetPassword(token: token, newPassword: newPassword);

  @override
  Future<Result<bool, AppFailure>> deleteAccount(String password) =>
      _api.deleteAccount(password);

  @override
  Future<Result<bool, AppFailure>> requestEmailChange({
    required String newEmail,
    required String password,
  }) =>
      _api.requestEmailChange(newEmail: newEmail, password: password);

  @override
  Future<Result<String, AppFailure>> confirmEmailChange(String token) =>
      _api.confirmEmailChange(token);

  @override
  Future<Result<User, AppFailure>> updateProfile({
    String? fullName,
    String? phone,
    DateTime? birthday,
    bool clearBirthday = false,
    String? avatarUrl,
    Gender? gender,
    bool? marketingOptIn,
    bool? orderUpdatesOptIn,
  }) async {
    final res = await _api.updateProfile(
      fullName: fullName,
      phone: phone,
      birthday: birthday,
      clearBirthday: clearBirthday,
      avatarUrl: avatarUrl,
      gender: gender,
      marketingOptIn: marketingOptIn,
      orderUpdatesOptIn: orderUpdatesOptIn,
    );
    return res.when(
      success: (dto) {
        final user = dto.toDomain();
        // Keep tokens; swap the cached user so the app bar / greeting
        // refresh immediately.
        final current = _session;
        if (current != null) {
          _emit(current.copyWith(user: user));
        }
        return Result<User, AppFailure>.success(user);
      },
      failure: Result<User, AppFailure>.failure,
    );
  }

  @override
  Future<Result<AuthSession, AppFailure>> refresh() async {
    // Single-flight: collapse concurrent callers onto the same future.
    if (_refreshing != null) return _refreshing!;
    final future = _doRefresh();
    _refreshing = future;
    // Callers await `future` itself; this side-chain only clears the slot.
    unawaited(future.whenComplete(() => _refreshing = null));
    return future;
  }

  Future<Result<AuthSession, AppFailure>> _doRefresh() async {
    final tokens = await _storage.read();
    if (tokens == null) {
      return Result.failure(AuthFailure.tokenExpired());
    }
    final result = await _api.refresh(tokens.refreshToken);
    return result.when(
      success: (dto) async {
        await _storage.write(
          StoredTokens(
            accessToken: dto.accessToken,
            refreshToken: dto.refreshToken,
          ),
        );
        final session = dto.toDomain();
        _emit(session);
        return Result<AuthSession, AppFailure>.success(session);
      },
      failure: (f) async {
        await _storage.clear();
        _emit(null);
        return Result<AuthSession, AppFailure>.failure(f);
      },
    );
  }

  @override
  Future<void> logout() async {
    final tokens = await _storage.read();
    if (tokens != null) {
      await _api.logout(tokens.refreshToken);
    }
    await _storage.clear();
    _emit(null);
  }

  Future<Result<AuthSession, AppFailure>> _completeAuth(
    Result<dynamic, AppFailure> apiResult,
  ) async {
    return apiResult.when<Future<Result<AuthSession, AppFailure>>>(
      success: (dto) async {
        final session = (dto as dynamic).toDomain() as AuthSession;
        await _storage.write(
          StoredTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
          ),
        );
        _emit(session);
        return Result<AuthSession, AppFailure>.success(session);
      },
      failure: (f) async => Result<AuthSession, AppFailure>.failure(f),
    );
  }

  void _emit(AuthSession? session) {
    _session = session;
    _sessionController.add(session);
  }

  @override
  Future<AuthSession> adoptSession(AuthSession session) async {
    await _storage.write(
      StoredTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      ),
    );
    _emit(session);
    return session;
  }
}
