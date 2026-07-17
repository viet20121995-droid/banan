import 'package:banan_core/banan_core.dart';
import 'package:dio/dio.dart';

import 'errors.dart';

class FaqItem {
  const FaqItem(this.q, this.a);
  final String q;
  final String a;
  Map<String, dynamic> toJson() => {'q': q, 'a': a};
}

class AboutSection {
  const AboutSection(this.heading, this.body);
  final String heading;
  final String body;
  Map<String, dynamic> toJson() => {'heading': heading, 'body': body};
}

/// Editable static page content (FAQ, About). `data` is the raw payload;
/// typed getters parse the known shapes.
class SiteContent {
  const SiteContent({
    required this.key,
    required this.data,
    required this.isDefault,
  });

  factory SiteContent.fromJson(Map<String, dynamic> j) => SiteContent(
        key: j['key'] as String? ?? '',
        data: (j['content'] as Map?)?.cast<String, dynamic>() ?? const {},
        isDefault: j['isDefault'] as bool? ?? false,
      );

  final String key;
  final Map<String, dynamic> data;
  final bool isDefault;

  List<FaqItem> get faqItems {
    final raw = (data['items'] as List?) ?? const [];
    return raw
        .map((e) => (e as Map).cast<String, dynamic>())
        .map((m) => FaqItem(m['q'] as String? ?? '', m['a'] as String? ?? ''))
        .where((it) => it.q.isNotEmpty || it.a.isNotEmpty)
        .toList();
  }

  String get aboutIntro => data['intro'] as String? ?? '';

  List<AboutSection> get aboutSections {
    final raw = (data['sections'] as List?) ?? const [];
    return raw
        .map((e) => (e as Map).cast<String, dynamic>())
        .map((m) => AboutSection(
              m['heading'] as String? ?? '',
              m['body'] as String? ?? '',
            ),)
        .where((s) => s.heading.isNotEmpty || s.body.isNotEmpty)
        .toList();
  }
}

class SiteContentApi {
  SiteContentApi(this._dio);
  final Dio _dio;

  /// Public read (customer app).
  Future<Result<SiteContent, AppFailure>> get(String key) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/site-content/$key');
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(SiteContent.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Merchant/admin read (same data; separate auth-scoped route).
  Future<Result<SiteContent, AppFailure>> getForEdit(String key) async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/merchant/site-content/$key');
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(SiteContent.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Future<Result<SiteContent, AppFailure>> update(
    String key,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/merchant/site-content/$key',
        data: {'data': data},
      );
      final m = res.data?['data'] as Map<String, dynamic>?;
      if (m == null) return Result.failure(mapHttpStatusToFailure(res));
      return Result.success(SiteContent.fromJson(m));
    } on DioException catch (e) {
      return Result.failure(mapDioErrorToFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }
}
