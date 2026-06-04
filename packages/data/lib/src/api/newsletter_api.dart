import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

class SubscribeResult {
  const SubscribeResult({required this.pending, required this.alreadyConfirmed});
  final bool pending;
  final bool alreadyConfirmed;
}

class NewsletterSubscriber {
  const NewsletterSubscriber({
    required this.id,
    required this.email,
    required this.subscribedAt,
    this.fullName,
    this.source,
    this.confirmedAt,
    this.unsubscribedAt,
  });
  factory NewsletterSubscriber.fromJson(Map<String, dynamic> j) =>
      NewsletterSubscriber(
        id: j['id'] as String,
        email: j['email'] as String,
        fullName: j['fullName'] as String?,
        source: j['source'] as String?,
        subscribedAt: DateTime.parse(j['subscribedAt'] as String),
        confirmedAt: j['confirmedAt'] == null
            ? null
            : DateTime.parse(j['confirmedAt'] as String),
        unsubscribedAt: j['unsubscribedAt'] == null
            ? null
            : DateTime.parse(j['unsubscribedAt'] as String),
      );
  final String id;
  final String email;
  final String? fullName;
  final String? source;
  final DateTime subscribedAt;
  final DateTime? confirmedAt;
  final DateTime? unsubscribedAt;

  bool get isActive => confirmedAt != null && unsubscribedAt == null;
}

class SubscriberPage {
  const SubscriberPage({
    required this.items,
    required this.total,
    required this.activeCount,
    required this.pendingCount,
    required this.unsubscribedCount,
  });
  final List<NewsletterSubscriber> items;
  final int total;
  final int activeCount;
  final int pendingCount;
  final int unsubscribedCount;
}

class NewsletterApi {
  NewsletterApi(this._dio);
  final Dio _dio;

  Future<Result<SubscribeResult, AppFailure>> subscribe({
    required String email,
    String? fullName,
    String? source,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/newsletter/subscribe',
        data: {
          'email': email,
          if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
          if (source != null && source.isNotEmpty) 'source': source,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(
        SubscribeResult(
          pending: m['pending'] as bool? ?? true,
          alreadyConfirmed: m['alreadyConfirmed'] as bool? ?? false,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  // ── Merchant side ──────────────────────────────────────────────────

  Future<Result<SubscriberPage, AppFailure>> list({
    String? q,
    bool? confirmed,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/newsletter',
        queryParameters: {
          if (q != null && q.isNotEmpty) 'q': q,
          if (confirmed != null) 'confirmed': confirmed.toString(),
          'page': page,
          'perPage': perPage,
        },
      );
      final raw = res.data?['data'] as List? ?? const [];
      final meta = res.data?['meta'] as Map<String, dynamic>? ?? const {};
      final stats = res.data?['stats'] as Map<String, dynamic>? ?? const {};
      return Result.success(
        SubscriberPage(
          items: raw
              .map((e) => NewsletterSubscriber.fromJson(e as Map<String, dynamic>))
              .toList(),
          total: (meta['total'] as num?)?.toInt() ?? raw.length,
          activeCount: (stats['active'] as num?)?.toInt() ?? 0,
          pendingCount: (stats['pending'] as num?)?.toInt() ?? 0,
          unsubscribedCount: (stats['unsubscribed'] as num?)?.toInt() ?? 0,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<Uint8List, AppFailure>> exportCsv() async {
    try {
      final res = await _dio.get<List<int>>(
        '/merchant/newsletter/export.csv',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'text/csv'},
        ),
      );
      final data = res.data;
      if (data == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(Uint8List.fromList(data));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
