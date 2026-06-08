import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

class SubscribeResult {
  const SubscribeResult({required this.pending, required this.alreadyConfirmed});
  final bool pending;
  final bool alreadyConfirmed;
}

/// Outcome of a newsletter campaign send — how many recipients were
/// targeted, how many branded emails actually went out, and (when the
/// merchant also fired an in-app broadcast) how many in-app notifications
/// were created.
class NewsletterSendResult {
  const NewsletterSendResult({
    required this.recipients,
    required this.emailsSent,
    required this.inApp,
  });
  factory NewsletterSendResult.fromJson(Map<String, dynamic> j) =>
      NewsletterSendResult(
        recipients: (j['recipients'] as num?)?.toInt() ?? 0,
        emailsSent: (j['emailsSent'] as num?)?.toInt() ?? 0,
        inApp: (j['inApp'] as num?)?.toInt() ?? 0,
      );
  final int recipients;
  final int emailsSent;
  final int inApp;
}

/// One previously-sent newsletter campaign, kept as history so the merchant
/// can review what was sent, to whom, and how many landed.
class NewsletterCampaign {
  const NewsletterCampaign({
    required this.id,
    required this.subject,
    required this.body,
    required this.audience,
    required this.alsoInApp,
    required this.recipients,
    required this.emailsSent,
    required this.inAppSent,
    required this.createdAt,
    this.imageUrl,
  });
  factory NewsletterCampaign.fromJson(Map<String, dynamic> j) =>
      NewsletterCampaign(
        id: j['id'] as String,
        subject: j['subject'] as String? ?? '',
        body: j['body'] as String? ?? '',
        imageUrl: j['imageUrl'] as String?,
        audience: j['audience'] as String? ?? 'subscribers',
        alsoInApp: j['alsoInApp'] as bool? ?? false,
        recipients: (j['recipients'] as num?)?.toInt() ?? 0,
        emailsSent: (j['emailsSent'] as num?)?.toInt() ?? 0,
        inAppSent: (j['inAppSent'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
  final String id;
  final String subject;
  final String body;
  final String? imageUrl;
  final String audience;
  final bool alsoInApp;
  final int recipients;
  final int emailsSent;
  final int inAppSent;
  final DateTime createdAt;
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

  /// Compose + send a branded newsletter email to [audience]
  /// (`subscribers` | `customers` | `both`). The backend wraps [body] in a
  /// branded HTML template (newlines → <br>) and appends an unsubscribe link.
  /// When [alsoInApp] is true it additionally fires an in-app + push
  /// broadcast. Returns the recipient / email / in-app counts.
  Future<Result<NewsletterSendResult, AppFailure>> sendCampaign({
    required String subject,
    required String body,
    required String audience,
    String? imageUrl,
    bool alsoInApp = true,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/merchant/newsletter/send',
        data: {
          'subject': subject,
          'body': body,
          'audience': audience,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          'alsoInApp': alsoInApp,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(NewsletterSendResult.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Send a single test email of the campaign to [testEmail] so the merchant
  /// can preview the real branded email in their own inbox. Does not record
  /// history or fire any broadcast.
  Future<Result<bool, AppFailure>> sendTest({
    required String subject,
    required String body,
    required String testEmail,
    String? imageUrl,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/merchant/newsletter/test',
        data: {
          'subject': subject,
          'body': body,
          'testEmail': testEmail,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        },
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(m['ok'] as bool? ?? true);
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// History of previously-sent campaigns, newest first.
  Future<Result<List<NewsletterCampaign>, AppFailure>> listCampaigns() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/merchant/newsletter/campaigns',
      );
      final raw = res.data?['data'] as List? ?? const [];
      return Result.success(
        raw
            .map((e) => NewsletterCampaign.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
