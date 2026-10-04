import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('API errors are translated by code, Vietnamese keeps the server text',
      () {
    const vi = 'Banan Test hiện đang đóng cửa.';
    Response<dynamic> res() => Response<dynamic>(
          requestOptions: RequestOptions(),
          statusCode: 400,
          data: {
            'error': {'code': 'STORE_CLOSED', 'message': vi},
          },
        );
    addTearDown(() => apiLocale = 'vi');
    apiLocale = 'vi';
    expect(mapHttpStatusToFailure(res()).message, vi);
    apiLocale = 'ja';
    expect(mapHttpStatusToFailure(res()).message, contains('営業時間'));
    apiLocale = 'en';
    final f = mapHttpStatusToFailure(res()) as ValidationFailure;
    expect(f.message, contains('closed'));
    expect(f.serverCode, 'STORE_CLOSED');
  });
}
