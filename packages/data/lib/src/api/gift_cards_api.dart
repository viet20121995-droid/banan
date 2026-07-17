import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

class GiftCard {
  const GiftCard({
    required this.id,
    required this.code,
    required this.initialVnd,
    required this.balanceVnd,
    required this.isActive,
    this.expiresAt,
    this.note,
  });
  factory GiftCard.fromJson(Map<String, dynamic> j) => GiftCard(
        id: j['id'] as String,
        code: j['code'] as String,
        initialVnd: (j['initialVnd'] as num).toInt(),
        balanceVnd: (j['balanceVnd'] as num).toInt(),
        isActive: j['isActive'] as bool? ?? true,
        expiresAt: j['expiresAt'] == null
            ? null
            : DateTime.tryParse(j['expiresAt'] as String),
        note: j['note'] as String?,
      );
  final String id;
  final String code;
  final int initialVnd;
  final int balanceVnd;
  final bool isActive;
  final DateTime? expiresAt;
  final String? note;
}

class GiftCardValidation {
  const GiftCardValidation({
    required this.valid,
    this.code,
    this.balanceVnd,
    this.reason,
  });
  final bool valid;
  final String? code;
  final int? balanceVnd;
  final String? reason;
}

class GiftCardsApi {
  GiftCardsApi(this._dio);
  final Dio _dio;

  /// Public — check a code before applying it at checkout.
  Future<Result<GiftCardValidation, AppFailure>> validate(String code) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/gift-cards/validate',
        data: {'code': code},
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(GiftCardValidation(
        valid: m['valid'] as bool? ?? false,
        code: m['code'] as String?,
        balanceVnd: (m['balanceVnd'] as num?)?.toInt(),
        reason: m['reason'] as String?,
      ),);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  // ── Admin ──────────────────────────────────────────────────────────────
  Future<Result<List<GiftCard>, AppFailure>> list() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/merchant/gift-cards');
      if (!isOk(res)) return Result.failure(mapHttpStatusToFailure(res));
      final raw = (res.data?['data'] as List?) ?? const [];
      return Result.success(
        raw
            .map((e) => GiftCard.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<GiftCard, AppFailure>> issue({
    required int valueVnd,
    String? expiresAt,
    String? note,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/merchant/gift-cards',
        data: {
          'valueVnd': valueVnd,
          if (expiresAt != null) 'expiresAt': expiresAt,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(GiftCard.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<GiftCard, AppFailure>> deactivate(String id) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/merchant/gift-cards/$id/deactivate',
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(GiftCard.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
