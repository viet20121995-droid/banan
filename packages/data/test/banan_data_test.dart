import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('errors', () {
    test('401 with AUTH_INVALID_CREDENTIALS maps to AuthFailure', () {
      final res = Response<dynamic>(
        statusCode: 401,
        data: {
          'error': {'code': 'AUTH_INVALID_CREDENTIALS', 'message': 'bad'},
        },
        requestOptions: RequestOptions(path: '/auth/login'),
      );
      final failure = mapHttpStatusToFailure(res);
      expect(failure, isA<AuthFailure>());
      expect(failure.code, 'AUTH_INVALID_CREDENTIALS');
    });

    test('500 maps to ServerFailure', () {
      final res = Response<dynamic>(
        statusCode: 500,
        data: null,
        requestOptions: RequestOptions(path: '/x'),
      );
      final failure = mapHttpStatusToFailure(res);
      expect(failure, isA<ServerFailure>());
    });
  });
}
