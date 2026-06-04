import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

class BulkPricePreviewRow {
  const BulkPricePreviewRow({
    required this.name,
    required this.from,
    required this.to,
  });
  factory BulkPricePreviewRow.fromJson(Map<String, dynamic> j) =>
      BulkPricePreviewRow(
        name: j['name'] as String? ?? '',
        from: (j['from'] as num?)?.toDouble() ?? 0,
        to: (j['to'] as num?)?.toDouble() ?? 0,
      );
  final String name;
  final double from;
  final double to;
}

class BulkPriceResult {
  const BulkPriceResult({
    required this.matched,
    required this.updated,
    required this.dryRun,
    required this.sample,
  });
  factory BulkPriceResult.fromJson(Map<String, dynamic> j) => BulkPriceResult(
        matched: (j['matched'] as num?)?.toInt() ?? 0,
        updated: (j['updated'] as num?)?.toInt() ?? 0,
        dryRun: j['dryRun'] as bool? ?? false,
        sample: ((j['sample'] as List?) ?? const [])
            .map((e) => BulkPricePreviewRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final int matched;
  final int updated;
  final bool dryRun;
  final List<BulkPricePreviewRow> sample;
}

class BulkImportError {
  const BulkImportError(this.row, this.name, this.error);
  factory BulkImportError.fromJson(Map<String, dynamic> j) => BulkImportError(
        (j['row'] as num?)?.toInt() ?? 0,
        j['name'] as String? ?? '',
        j['error'] as String? ?? '',
      );
  final int row;
  final String name;
  final String error;
}

class BulkImportResult {
  const BulkImportResult({
    required this.created,
    required this.skipped,
    required this.errors,
  });
  factory BulkImportResult.fromJson(Map<String, dynamic> j) => BulkImportResult(
        created: (j['created'] as num?)?.toInt() ?? 0,
        skipped: (j['skipped'] as num?)?.toInt() ?? 0,
        errors: ((j['errors'] as List?) ?? const [])
            .map((e) => BulkImportError.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final int created;
  final int skipped;
  final List<BulkImportError> errors;
}

/// Merchant bulk ops (CSV import, bulk price) + campaign broadcast.
class MerchantToolsApi {
  MerchantToolsApi(this._dio);
  final Dio _dio;

  Future<Result<BulkPriceResult, AppFailure>> bulkPrice({
    required String scope, // 'all' | 'category' | 'collection'
    required String mode, // 'percent' | 'fixed'
    required double amount,
    String? categoryId,
    String? collectionSlug,
    double? roundTo,
    bool dryRun = false,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/products/merchant/bulk-price',
        data: {
          'scope': scope,
          'mode': mode,
          'amount': amount,
          if (categoryId != null) 'categoryId': categoryId,
          if (collectionSlug != null) 'collectionSlug': collectionSlug,
          if (roundTo != null) 'roundTo': roundTo,
          'dryRun': dryRun,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(BulkPriceResult.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<BulkImportResult, AppFailure>> bulkImport(
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/products/merchant/bulk-import',
        data: {'rows': rows},
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(BulkImportResult.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Returns the recipient count.
  Future<Result<int, AppFailure>> broadcast({
    required String title,
    required String body,
    String? linkPath,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/merchant/broadcast',
        data: {
          'title': title,
          'body': body,
          if (linkPath != null && linkPath.isNotEmpty) 'linkPath': linkPath,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      return Result.success((m?['recipients'] as num?)?.toInt() ?? 0);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
