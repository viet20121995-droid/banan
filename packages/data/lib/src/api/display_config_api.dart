import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

/// Chain-wide customer-display preferences — stock badge toggle plus the
/// channels surfaced by the contact widget. Each channel field null →
/// that channel is hidden from the FAB sheet; when every channel is null
/// the FAB itself is hidden.
class DisplayConfig {
  const DisplayConfig({
    required this.showStockToCustomers,
    this.contactPhone,
    this.contactZaloOaId,
    this.contactMessengerId,
    this.contactEmail,
  });

  factory DisplayConfig.fromJson(Map<String, dynamic> j) => DisplayConfig(
        showStockToCustomers:
            j['showStockToCustomers'] as bool? ?? false,
        contactPhone: j['contactPhone'] as String?,
        contactZaloOaId: j['contactZaloOaId'] as String?,
        contactMessengerId: j['contactMessengerId'] as String?,
        contactEmail: j['contactEmail'] as String?,
      );

  final bool showStockToCustomers;
  final String? contactPhone;
  final String? contactZaloOaId;
  final String? contactMessengerId;
  final String? contactEmail;

  bool get hasAnyContactChannel =>
      (contactPhone?.isNotEmpty ?? false) ||
      (contactZaloOaId?.isNotEmpty ?? false) ||
      (contactMessengerId?.isNotEmpty ?? false) ||
      (contactEmail?.isNotEmpty ?? false);
}

class DisplayConfigApi {
  DisplayConfigApi(this._dio);
  final Dio _dio;

  Future<Result<DisplayConfig, AppFailure>> get() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/display-config');
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(DisplayConfig.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<DisplayConfig, AppFailure>> update({
    bool? showStockToCustomers,
    String? contactPhone,
    String? contactZaloOaId,
    String? contactMessengerId,
    String? contactEmail,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/display-config',
        data: {
          if (showStockToCustomers != null)
            'showStockToCustomers': showStockToCustomers,
          // Empty string is a valid value here — merchant sending "" means
          // "clear this channel". Service-side normalises to null.
          if (contactPhone != null) 'contactPhone': contactPhone,
          if (contactZaloOaId != null) 'contactZaloOaId': contactZaloOaId,
          if (contactMessengerId != null)
            'contactMessengerId': contactMessengerId,
          if (contactEmail != null) 'contactEmail': contactEmail,
        },
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(DisplayConfig.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
