import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/merchant_coupon_dto.dart';
import 'errors.dart';

class MerchantCouponsApi {
  MerchantCouponsApi(this._dio);
  final Dio _dio;

  Future<Result<List<MerchantCouponDto>, AppFailure>> list() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/merchant/coupons');
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) =>
                MerchantCouponDto.fromJson(e as Map<String, dynamic>),)
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<MerchantCouponDto, AppFailure>> create(
    Map<String, dynamic> body,
  ) =>
      _send(
        () => _dio.post<Map<String, dynamic>>(
          '/merchant/coupons',
          data: body,
        ),
      );

  Future<Result<MerchantCouponDto, AppFailure>> update(
    String id,
    Map<String, dynamic> body,
  ) =>
      _send(
        () => _dio.patch<Map<String, dynamic>>(
          '/merchant/coupons/$id',
          data: body,
        ),
      );

  Future<Result<MerchantCouponDto, AppFailure>> _send(
    Future<Response<Map<String, dynamic>>> Function() run,
  ) async {
    try {
      final res = await run();
      final code = res.statusCode ?? 0;
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (code < 200 || code >= 300 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(MerchantCouponDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
