import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// View-state for login/register forms.
@immutable
class AuthFormState {
  const AuthFormState({
    this.submitting = false,
    this.failure,
  });

  final bool submitting;
  final AppFailure? failure;

  AuthFormState copyWith({bool? submitting, AppFailure? failure, bool clearFailure = false}) {
    return AuthFormState(
      submitting: submitting ?? this.submitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class AuthController extends StateNotifier<AuthFormState> {
  AuthController(this._repo) : super(const AuthFormState());

  final AuthRepository _repo;

  Future<bool> login({
    required String emailOrPhone,
    required String password,
  }) async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final result = await _repo.login(
      emailOrPhone: emailOrPhone.trim(),
      password: password,
    );
    return result.when(
      success: (_) {
        state = state.copyWith(submitting: false);
        return true;
      },
      failure: (f) {
        state = state.copyWith(submitting: false, failure: f);
        return false;
      },
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    DateTime? birthday,
  }) async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final result = await _repo.register(
      email: email.trim(),
      password: password,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      birthday: birthday,
    );
    return result.when(
      success: (_) {
        state = state.copyWith(submitting: false);
        return true;
      },
      failure: (f) {
        state = state.copyWith(submitting: false, failure: f);
        return false;
      },
    );
  }

  Future<void> logout() async {
    await _repo.logout();
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);
}

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthController, AuthFormState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
