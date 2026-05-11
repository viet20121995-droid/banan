import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

/// Creates the singleton Dio instance used by every repository. Interceptors
/// for auth + structured error mapping are layered in M1.
Dio createDioClient({String? baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      // The backend uses { data, error } envelopes — repositories unwrap.
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  if (!Env.isProd) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => log('http').fine(obj.toString()),
      ),
    );
  }

  return dio;
}
