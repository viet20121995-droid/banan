import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import '../dtos/coupon_dto.dart';
import '../dtos/loyalty_dto.dart';
import 'errors.dart';

class LoyaltyApi {
  LoyaltyApi(this._dio);
  final Dio _dio;

  Future<Result<MembershipSummaryDto, AppFailure>> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/loyalty');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(MembershipSummaryDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}

class CouponsApi {
  CouponsApi(this._dio);
  final Dio _dio;

  Future<Result<CouponPreviewDto, AppFailure>> validate({
    required String code,
    required int subtotalVnd,
    required int deliveryFeeVnd,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/coupons/validate',
        data: {
          'code': code,
          'subtotal': subtotalVnd,
          'deliveryFee': deliveryFeeVnd,
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (res.statusCode != 200 && res.statusCode != 201) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(CouponPreviewDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// The signed-in customer's voucher wallet (GET /coupons/mine).
  Future<Result<VoucherWalletDto, AppFailure>> myWallet() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/coupons/mine');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (res.statusCode != 200 || data == null) {
        return Result.failure(mapHttpStatusToFailure(res));
      }
      return Result.success(VoucherWalletDto.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
