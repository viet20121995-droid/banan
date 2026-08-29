/// ADMIN view models for the dine-in survey. The public guest form (and the
/// template shapes the editor shares with it) lives in
/// `banan_features_shared` — served on the CUSTOMER domain; re-exported here
/// so admin screens keep one import.
library;

export 'package:banan_features_shared/banan_features_shared.dart'
    show SurveyOptionView, SurveyQuestionView, SurveyStoreRef, SurveyTemplateView;

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;
String? _s(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _i(dynamic v) => v is num ? v.toInt() : 0;
int? _iq(dynamic v) => v is num ? v.toInt() : null;
double? _d(dynamic v) => v is num ? v.toDouble() : null;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

// ── template list (admin) ───────────────────────────────────────────────────

class SurveyTemplateListItem {
  const SurveyTemplateListItem({
    required this.id,
    required this.name,
    required this.version,
    required this.status,
    required this.isDefault,
    required this.questionCount,
    required this.responseCount,
  });
  factory SurveyTemplateListItem.fromJson(Map<String, dynamic> json) => SurveyTemplateListItem(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        version: _i(json['version']),
        status: (json['status'] as String?) ?? 'DRAFT',
        isDefault: json['isDefault'] == true,
        questionCount: _i(json['questionCount']),
        responseCount: _i(json['responseCount']),
      );
  final String id;
  final String name;
  final int version;
  final String status;
  final bool isDefault;
  final int questionCount;
  final int responseCount;
}

// ── admin: reports ──────────────────────────────────────────────────────────

class SurveyTrendPoint {
  const SurveyTrendPoint({required this.bucket, required this.count, this.avgOverall});
  factory SurveyTrendPoint.fromJson(Map<String, dynamic> json) => SurveyTrendPoint(
        bucket: (json['bucket'] as String?) ?? '',
        count: _i(json['count']),
        avgOverall: _d(json['avgOverall']),
      );
  final String bucket;
  final int count;
  final double? avgOverall;
}

class SurveyStoreStat {
  const SurveyStoreStat({
    required this.storeId,
    required this.storeName,
    required this.count,
    required this.lowCount,
    this.avgOverall,
  });
  factory SurveyStoreStat.fromJson(Map<String, dynamic> json) => SurveyStoreStat(
        storeId: json['storeId'] as String,
        storeName: (json['storeName'] as String?) ?? '?',
        count: _i(json['count']),
        lowCount: _i(json['lowCount']),
        avgOverall: _d(json['avgOverall']),
      );
  final String storeId;
  final String storeName;
  final int count;
  final int lowCount;
  final double? avgOverall;
}

class SurveyCategoryStat {
  const SurveyCategoryStat({
    required this.code,
    required this.label,
    required this.count,
    this.avg,
  });
  factory SurveyCategoryStat.fromJson(Map<String, dynamic> json) => SurveyCategoryStat(
        code: (json['code'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        count: _i(json['count']),
        avg: _d(json['avg']),
      );
  final String code;
  final String label;
  final int count;
  final double? avg;
}

class SurveyTopOption {
  const SurveyTopOption({required this.value, required this.label, required this.count});
  factory SurveyTopOption.fromJson(Map<String, dynamic> json) => SurveyTopOption(
        value: (json['value'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        count: _i(json['count']),
      );
  final String value;
  final String label;
  final int count;
}

class SurveyRecentComment {
  const SurveyRecentComment({
    required this.id,
    required this.comment,
    required this.storeName,
    this.overall,
    this.createdAt,
  });
  factory SurveyRecentComment.fromJson(Map<String, dynamic> json) => SurveyRecentComment(
        id: json['id'] as String,
        comment: (json['comment'] as String?) ?? '',
        storeName: (json['storeName'] as String?) ?? '?',
        overall: _iq(json['overall']),
        createdAt: _date(json['createdAt']),
      );
  final String id;
  final String comment;
  final String storeName;
  final int? overall;
  final DateTime? createdAt;
}

class SurveySummary {
  const SurveySummary({
    required this.total,
    required this.openCases,
    required this.overdueCases,
    this.avgOverall,
    this.pctHigh,
    this.pctLow,
    this.nps,
    this.npsCount = 0,
    this.trend = const [],
    this.stores = const [],
    this.categories = const [],
    this.topIssues = const [],
    this.topPraise = const [],
    this.recentComments = const [],
  });
  factory SurveySummary.fromJson(Map<String, dynamic> json) => SurveySummary(
        total: _i(json['total']),
        openCases: _i(json['openCases']),
        overdueCases: _i(json['overdueCases']),
        avgOverall: _d(json['avgOverall']),
        pctHigh: _iq(json['pctHigh']),
        pctLow: _iq(json['pctLow']),
        nps: _iq(json['nps']),
        npsCount: _i(json['npsCount']),
        trend: _list(json['trend']).map(SurveyTrendPoint.fromJson).toList(),
        stores: _list(json['stores']).map(SurveyStoreStat.fromJson).toList(),
        categories: _list(json['categories']).map(SurveyCategoryStat.fromJson).toList(),
        topIssues: _list(json['topIssues']).map(SurveyTopOption.fromJson).toList(),
        topPraise: _list(json['topPraise']).map(SurveyTopOption.fromJson).toList(),
        recentComments:
            _list(json['recentComments']).map(SurveyRecentComment.fromJson).toList(),
      );
  final int total;
  final int openCases;
  final int overdueCases;
  final double? avgOverall;
  final int? pctHigh;
  final int? pctLow;
  final int? nps;
  final int npsCount;
  final List<SurveyTrendPoint> trend;
  final List<SurveyStoreStat> stores;
  final List<SurveyCategoryStat> categories;
  final List<SurveyTopOption> topIssues;
  final List<SurveyTopOption> topPraise;
  final List<SurveyRecentComment> recentComments;
}

// ── admin: cases ────────────────────────────────────────────────────────────

class SurveyCaseContact {
  const SurveyCaseContact({this.name, this.phone});
  factory SurveyCaseContact.fromJson(Map<String, dynamic> json) =>
      SurveyCaseContact(name: _s(json['name']), phone: _s(json['phone']));
  final String? name;
  final String? phone;
}

class SurveyCaseView {
  const SurveyCaseView({
    required this.id,
    required this.status,
    required this.overdue,
    required this.storeName,
    this.assigneeName,
    this.note,
    this.resolvedAt,
    this.createdAt,
    this.overall,
    this.comment,
    this.contact,
    this.responseId,
  });
  factory SurveyCaseView.fromJson(Map<String, dynamic> json) {
    final response = (json['response'] as Map<String, dynamic>?) ?? const {};
    return SurveyCaseView(
      id: json['id'] as String,
      status: (json['status'] as String?) ?? 'NEW',
      overdue: json['overdue'] == true,
      assigneeName: _s(json['assigneeName']),
      note: _s(json['note']),
      resolvedAt: _date(json['resolvedAt']),
      createdAt: _date(json['createdAt']),
      storeName: (response['storeName'] as String?) ?? '?',
      overall: _iq(response['overall']),
      comment: _s(response['comment']),
      responseId: _s(response['id']),
      contact: response['contact'] is Map<String, dynamic>
          ? SurveyCaseContact.fromJson(response['contact'] as Map<String, dynamic>)
          : null,
    );
  }
  final String id;
  final String status;
  final bool overdue;
  final String storeName;
  final String? assigneeName;
  final String? note;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final int? overall;
  final String? comment;
  final SurveyCaseContact? contact;
  final String? responseId;
}

// ── admin: rewards ──────────────────────────────────────────────────────────

class SurveyCampaignView {
  const SurveyCampaignView({
    required this.id,
    required this.name,
    required this.mode,
    required this.isEnabled,
    required this.expiryDays,
    required this.probabilityPct,
    required this.issuedCount,
    required this.redeemedCount,
    this.description,
    this.instructions,
    this.startsAt,
    this.endsAt,
    this.dailyCap,
    this.totalCap,
  });
  factory SurveyCampaignView.fromJson(Map<String, dynamic> json) => SurveyCampaignView(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        mode: (json['mode'] as String?) ?? 'NONE',
        isEnabled: json['isEnabled'] == true,
        expiryDays: _i(json['expiryDays']),
        probabilityPct: _i(json['probabilityPct']),
        issuedCount: _i(json['issuedCount']),
        redeemedCount: _i(json['redeemedCount']),
        description: _s(json['description']),
        instructions: _s(json['instructions']),
        startsAt: _date(json['startsAt']),
        endsAt: _date(json['endsAt']),
        dailyCap: _iq(json['dailyCap']),
        totalCap: _iq(json['totalCap']),
      );
  final String id;
  final String name;
  final String mode;
  final bool isEnabled;
  final int expiryDays;
  final int probabilityPct;
  final int issuedCount;
  final int redeemedCount;
  final String? description;
  final String? instructions;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? dailyCap;
  final int? totalCap;
}

class SurveyClaimView {
  const SurveyClaimView({
    required this.id,
    required this.status,
    required this.campaignName,
    required this.mode,
    required this.storeName,
    this.voucherCode,
    this.issuedAt,
    this.expiresAt,
    this.redeemedAt,
  });
  factory SurveyClaimView.fromJson(Map<String, dynamic> json) => SurveyClaimView(
        id: json['id'] as String,
        status: (json['status'] as String?) ?? 'ISSUED',
        campaignName: (json['campaignName'] as String?) ?? '',
        mode: (json['mode'] as String?) ?? 'NONE',
        storeName: (json['storeName'] as String?) ?? '?',
        voucherCode: _s(json['voucherCode']),
        issuedAt: _date(json['issuedAt']),
        expiresAt: _date(json['expiresAt']),
        redeemedAt: _date(json['redeemedAt']),
      );
  final String id;
  final String status;
  final String campaignName;
  final String mode;
  final String storeName;
  final String? voucherCode;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? redeemedAt;
}

class SurveyRedeemResult {
  const SurveyRedeemResult({
    required this.voucherCode,
    required this.campaignName,
    required this.storeName,
    this.issuedAt,
    this.expiresAt,
  });
  factory SurveyRedeemResult.fromJson(Map<String, dynamic> json) => SurveyRedeemResult(
        voucherCode: (json['voucherCode'] as String?) ?? '',
        campaignName: (json['campaignName'] as String?) ?? '',
        storeName: (json['storeName'] as String?) ?? '?',
        issuedAt: _date(json['issuedAt']),
        expiresAt: _date(json['expiresAt']),
      );
  final String voucherCode;
  final String campaignName;
  final String storeName;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
}

// ── admin: responses ────────────────────────────────────────────────────────

class SurveyResponseRow {
  const SurveyResponseRow({
    required this.id,
    required this.storeName,
    required this.contactRequested,
    required this.templateVersion,
    this.createdAt,
    this.overall,
    this.nps,
    this.comment,
    this.caseStatus,
  });
  factory SurveyResponseRow.fromJson(Map<String, dynamic> json) => SurveyResponseRow(
        id: json['id'] as String,
        storeName: (json['storeName'] as String?) ?? '?',
        contactRequested: json['contactRequested'] == true,
        templateVersion: _i(json['templateVersion']),
        createdAt: _date(json['createdAt']),
        overall: _iq(json['overall']),
        nps: _iq(json['nps']),
        comment: _s(json['comment']),
        caseStatus: _s(json['caseStatus']),
      );
  final String id;
  final String storeName;
  final bool contactRequested;
  final int templateVersion;
  final DateTime? createdAt;
  final int? overall;
  final int? nps;
  final String? comment;
  final String? caseStatus;
}
