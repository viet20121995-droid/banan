import 'package:banan_core/banan_core.dart';

/// User-friendly message for an [AppFailure] in the auth context.
String authFailureMessage(AppFailure failure) {
  if (failure is AuthFailure) {
    switch (failure.code) {
      case 'AUTH_INVALID_CREDENTIALS':
        return 'Email hoặc mật khẩu không đúng.';
      case 'AUTH_FORBIDDEN':
        return 'Tài khoản của bạn không được phép thực hiện thao tác này.';
      case 'AUTH_REFRESH_INVALID':
        return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
    }
  }
  if (failure is ValidationFailure) {
    return failure.message ?? 'Vui lòng kiểm tra lại thông tin và thử lại.';
  }
  if (failure is NetworkFailure || failure is TimeoutFailure) {
    return 'Không kết nối được máy chủ, kiểm tra lại mạng của bạn.';
  }
  if (failure is ServerFailure && failure.code == 'AUTH_EMAIL_TAKEN') {
    return 'Email hoặc số điện thoại này đã có tài khoản.';
  }
  return failure.message ?? 'Có lỗi xảy ra. Vui lòng thử lại.';
}
