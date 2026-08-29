/// Plain view models for the internal ops API. Hand-written `fromJson`
/// mirroring the backend view shapes 1:1; statuses stay raw wire strings
/// (internal-only app — the UI switches on them directly).
library;

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;
String? _s(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _i(dynamic v) => v is num ? v.toInt() : 0;
double? _d(dynamic v) => v is num ? v.toDouble() : null;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

class StoreRef {
  const StoreRef({required this.id, required this.name});
  factory StoreRef.fromJson(Map<String, dynamic> json) =>
      StoreRef(id: json['id'] as String, name: (json['name'] as String?) ?? '?');
  final String id;
  final String name;
}

class EvidenceRef {
  const EvidenceRef({required this.id, required this.url, this.kind});
  factory EvidenceRef.fromJson(Map<String, dynamic> json) => EvidenceRef(
        id: json['id'] as String,
        url: json['url'] as String,
        kind: _s(json['kind']),
      );
  final String id;
  final String url;
  final String? kind;
}

// ── QC ──────────────────────────────────────────────────────────────────────

class QcItemView {
  const QcItemView({
    required this.id,
    required this.no,
    required this.text,
    this.sourceRef,
    this.value,
    this.failDetail,
    this.naReason,
    this.occurred,
    this.detail,
    this.evidence = const [],
  });

  factory QcItemView.fromJson(Map<String, dynamic> json) => QcItemView(
        id: json['id'] as String,
        no: _i(json['no']),
        text: (json['text'] as String?) ?? '',
        sourceRef: _s(json['sourceRef']),
        value: _s(json['value']),
        failDetail: _s(json['failDetail']),
        naReason: _s(json['naReason']),
        occurred: json['occurred'] as bool?,
        detail: _s(json['detail']),
        evidence: _list(json['evidence']).map(EvidenceRef.fromJson).toList(),
      );

  final String id;
  final int no;
  final String text;
  final String? sourceRef;
  final String? value; // PASS | FAIL | NOT_AVAILABLE (normal items)
  final String? failDetail;
  final String? naReason;
  final bool? occurred; // risk items
  final String? detail;
  final List<EvidenceRef> evidence;
}

class QcSectionView {
  const QcSectionView({
    required this.id,
    required this.title,
    required this.isRisk,
    required this.items,
  });

  factory QcSectionView.fromJson(Map<String, dynamic> json) => QcSectionView(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        isRisk: (json['isRisk'] as bool?) ?? false,
        items: _list(json['items']).map(QcItemView.fromJson).toList(),
      );

  final String id;
  final String title;
  final bool isRisk;
  final List<QcItemView> items;
}

class QcInspectionDetail {
  const QcInspectionDetail({
    required this.id,
    required this.code,
    required this.store,
    required this.status,
    required this.revision,
    required this.inspectionDate,
    required this.inspectorName,
    required this.sections,
    this.outcome,
    this.overallPercent,
    this.startedAt,
    this.endedAt,
    this.staffOnShift,
    this.generalNotes,
    this.completedAt,
  });

  factory QcInspectionDetail.fromJson(Map<String, dynamic> json) => QcInspectionDetail(
        id: json['id'] as String,
        code: (json['code'] as String?) ?? '',
        store: StoreRef.fromJson(json['store'] as Map<String, dynamic>),
        status: (json['status'] as String?) ?? 'DRAFT',
        revision: _i(json['revision']),
        outcome: _s(json['outcome']),
        overallPercent: _d(json['overallPercent']),
        inspectionDate: _date(json['inspectionDate']) ?? DateTime.now(),
        startedAt: _date(json['startedAt']),
        endedAt: _date(json['endedAt']),
        inspectorName: (json['inspectorName'] as String?) ?? '',
        staffOnShift: _s(json['staffOnShift']),
        generalNotes: _s(json['generalNotes']),
        completedAt: _date(json['completedAt']),
        sections: _list(json['sections']).map(QcSectionView.fromJson).toList(),
      );

  final String id;
  final String code;
  final StoreRef store;
  final String status;
  final int revision;
  final String? outcome;
  final double? overallPercent;
  final DateTime inspectionDate;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String inspectorName;
  final String? staffOnShift;
  final String? generalNotes;
  final DateTime? completedAt;
  final List<QcSectionView> sections;
}

class QcListItem {
  const QcListItem({
    required this.id,
    required this.code,
    required this.store,
    required this.inspectionDate,
    required this.status,
    required this.revision,
    required this.riskCount,
    required this.inspectorName,
    this.outcome,
    this.overallPercent,
  });

  factory QcListItem.fromJson(Map<String, dynamic> json) => QcListItem(
        id: json['id'] as String,
        code: (json['code'] as String?) ?? '',
        store: StoreRef.fromJson(json['store'] as Map<String, dynamic>),
        inspectionDate: _date(json['inspectionDate']) ?? DateTime.now(),
        status: (json['status'] as String?) ?? 'DRAFT',
        outcome: _s(json['outcome']),
        overallPercent: _d(json['overallPercent']),
        revision: _i(json['revision']),
        riskCount: _i(json['riskCount']),
        inspectorName: (json['inspectorName'] as String?) ?? '',
      );

  final String id;
  final String code;
  final StoreRef store;
  final DateTime inspectionDate;
  final String status;
  final String? outcome;
  final double? overallPercent;
  final int revision;
  final int riskCount;
  final String inspectorName;
}

class QcSectionScore {
  const QcSectionScore({
    required this.title,
    required this.passCount,
    required this.applicable,
    required this.naCount,
    required this.belowThreshold,
    this.percent,
  });

  factory QcSectionScore.fromJson(Map<String, dynamic> json) => QcSectionScore(
        title: (json['title'] as String?) ?? '',
        passCount: _i(json['passCount']),
        applicable: _i(json['applicable']),
        naCount: _i(json['naCount']),
        percent: _d(json['percent']),
        belowThreshold: (json['belowThreshold'] as bool?) ?? false,
      );

  final String title;
  final int passCount;
  final int applicable;
  final int naCount;
  final double? percent;
  final bool belowThreshold;
}

class QcResultView {
  const QcResultView({
    required this.outcome,
    required this.overallPass,
    required this.overallApplicable,
    required this.riskOccurred,
    required this.sections,
    required this.failedItems,
    required this.occurredRisks,
    this.overallPercent,
  });

  factory QcResultView.fromJson(Map<String, dynamic> json) => QcResultView(
        outcome: (json['outcome'] as String?) ?? 'PASS',
        overallPercent: _d(json['overallPercent']),
        overallPass: _i(json['overallPass']),
        overallApplicable: _i(json['overallApplicable']),
        riskOccurred: (json['riskOccurred'] as bool?) ?? false,
        sections: _list(json['sections']).map(QcSectionScore.fromJson).toList(),
        failedItems: _list(json['failedItems'])
            .map((f) => '[${f['section']}] ${f['text']}')
            .toList(),
        occurredRisks:
            (json['occurredRisks'] as List?)?.whereType<String>().toList() ?? const [],
      );

  final String outcome;
  final double? overallPercent;
  final int overallPass;
  final int overallApplicable;
  final bool riskOccurred;
  final List<QcSectionScore> sections;
  final List<String> failedItems;
  final List<String> occurredRisks;
}

class QcCompareRow {
  const QcCompareRow({
    required this.store,
    required this.inspections,
    required this.pass,
    required this.fail,
    required this.criticalFail,
    this.avgPercent,
  });

  factory QcCompareRow.fromJson(Map<String, dynamic> json) => QcCompareRow(
        store: StoreRef.fromJson(json['store'] as Map<String, dynamic>),
        inspections: _i(json['inspections']),
        avgPercent: _d(json['avgPercent']),
        pass: _i(json['pass']),
        fail: _i(json['fail']),
        criticalFail: _i(json['criticalFail']),
      );

  final StoreRef store;
  final int inspections;
  final double? avgPercent;
  final int pass;
  final int fail;
  final int criticalFail;
}

// ── Mystery Shopper ─────────────────────────────────────────────────────────

class MsQuestionView {
  const MsQuestionView({required this.id, required this.text, required this.allowNa});
  factory MsQuestionView.fromJson(Map<String, dynamic> json) => MsQuestionView(
        id: json['id'] as String,
        text: (json['text'] as String?) ?? '',
        allowNa: (json['allowNa'] as bool?) ?? false,
      );
  final String id;
  final String text;
  final bool allowNa;
}

class MsSectionView {
  const MsSectionView({
    required this.id,
    required this.code,
    required this.title,
    required this.kind,
    required this.weight,
    required this.questions,
  });

  factory MsSectionView.fromJson(Map<String, dynamic> json) => MsSectionView(
        id: json['id'] as String,
        code: (json['code'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? 'SCORED',
        weight: _i(json['weight']),
        questions: _list(json['questions']).map(MsQuestionView.fromJson).toList(),
      );

  final String id;
  final String code;
  final String title;
  final String kind; // SCORED | CRITICAL
  final int weight;
  final List<MsQuestionView> questions;
}

class MsAnswerView {
  const MsAnswerView({
    required this.questionId,
    this.value,
    this.note,
    this.evidence = const [],
  });

  factory MsAnswerView.fromJson(Map<String, dynamic> json) => MsAnswerView(
        questionId: json['questionId'] as String,
        value: _s(json['value']),
        note: _s(json['note']),
        evidence: _list(json['evidence']).map(EvidenceRef.fromJson).toList(),
      );

  final String questionId;
  final String? value; // YES | NO | NOT_AVAILABLE
  final String? note;
  final List<EvidenceRef> evidence;
}

class MsSubmissionView {
  const MsSubmissionView({
    required this.answers,
    required this.evidence,
    this.submittedAt,
    this.enteredAt,
    this.greetedAt,
    this.orderStartAt,
    this.paidAt,
    this.receivedAt,
    this.productsBought,
    this.amountPaidVnd,
    this.staffName,
    this.overallComment,
    this.criticalFail = false,
    this.totalScore,
  });

  factory MsSubmissionView.fromJson(Map<String, dynamic> json) => MsSubmissionView(
        submittedAt: _date(json['submittedAt']),
        enteredAt: _date(json['enteredAt']),
        greetedAt: _date(json['greetedAt']),
        orderStartAt: _date(json['orderStartAt']),
        paidAt: _date(json['paidAt']),
        receivedAt: _date(json['receivedAt']),
        productsBought: _s(json['productsBought']),
        amountPaidVnd: json['amountPaidVnd'] == null ? null : _i(json['amountPaidVnd']),
        staffName: _s(json['staffName']),
        overallComment: _s(json['overallComment']),
        criticalFail: (json['criticalFail'] as bool?) ?? false,
        totalScore: _d(json['totalScore']),
        answers: _list(json['answers']).map(MsAnswerView.fromJson).toList(),
        evidence: _list(json['evidence']).map(EvidenceRef.fromJson).toList(),
      );

  final DateTime? submittedAt;
  final DateTime? enteredAt;
  final DateTime? greetedAt;
  final DateTime? orderStartAt;
  final DateTime? paidAt;
  final DateTime? receivedAt;
  final String? productsBought;
  final int? amountPaidVnd;
  final String? staffName;
  final String? overallComment;
  final bool criticalFail;
  final double? totalScore;
  final List<MsAnswerView> answers;

  /// Submission-level evidence (receipt/product/packaging shots).
  final List<EvidenceRef> evidence;

  MsAnswerView? answerFor(String questionId) {
    for (final a in answers) {
      if (a.questionId == questionId) return a;
    }
    return null;
  }
}

class MsTokenMeta {
  const MsTokenMeta({required this.id, required this.createdAt, required this.expiresAt, this.revokedAt});
  factory MsTokenMeta.fromJson(Map<String, dynamic> json) => MsTokenMeta(
        id: json['id'] as String,
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        expiresAt: _date(json['expiresAt']) ?? DateTime.now(),
        revokedAt: _date(json['revokedAt']),
      );
  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
}

class MsAssignmentDetail {
  const MsAssignmentDetail({
    required this.id,
    required this.code,
    required this.store,
    required this.status,
    required this.approvedRevision,
    required this.sections,
    this.windowStart,
    this.windowEnd,
    this.scenario,
    this.productsToBuy,
    this.budgetVnd,
    this.brief,
    this.deadline,
    this.internalNotes,
    this.revisionNote,
    this.firstOpenedAt,
    this.submission,
    this.tokens = const [],
  });

  factory MsAssignmentDetail.fromJson(Map<String, dynamic> json) => MsAssignmentDetail(
        id: json['id'] as String,
        code: (json['code'] as String?) ?? '',
        store: StoreRef.fromJson(json['store'] as Map<String, dynamic>),
        status: (json['status'] as String?) ?? 'DRAFT',
        windowStart: _date(json['windowStart']),
        windowEnd: _date(json['windowEnd']),
        scenario: _s(json['scenario']),
        productsToBuy: _s(json['productsToBuy']),
        budgetVnd: json['budgetVnd'] == null ? null : _i(json['budgetVnd']),
        brief: _s(json['brief']),
        deadline: _date(json['deadline']),
        internalNotes: _s(json['internalNotes']),
        revisionNote: _s(json['revisionNote']),
        firstOpenedAt: _date(json['firstOpenedAt']),
        approvedRevision: _i(json['approvedRevision']),
        submission: json['submission'] is Map<String, dynamic>
            ? MsSubmissionView.fromJson(json['submission'] as Map<String, dynamic>)
            : null,
        sections: _list((json['template'] as Map<String, dynamic>?)?['sections'])
            .map(MsSectionView.fromJson)
            .toList(),
        tokens: _list(json['tokens']).map(MsTokenMeta.fromJson).toList(),
      );

  final String id;
  final String code;
  final StoreRef store;
  final String status;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final String? scenario;
  final String? productsToBuy;
  final int? budgetVnd;
  final String? brief;
  final DateTime? deadline;
  final String? internalNotes;
  final String? revisionNote;
  final DateTime? firstOpenedAt;
  final int approvedRevision;
  final MsSubmissionView? submission;
  final List<MsSectionView> sections;
  final List<MsTokenMeta> tokens;
}

class MsListItem {
  const MsListItem({
    required this.id,
    required this.code,
    required this.store,
    required this.status,
    required this.approvedRevision,
    required this.criticalFail,
    required this.source,
    this.requesterName,
    this.requesterEmployeeCode,
    this.tokenExpiresAt,
    this.totalScore,
    this.deadline,
    this.createdAt,
  });

  factory MsListItem.fromJson(Map<String, dynamic> json) => MsListItem(
        id: json['id'] as String,
        code: (json['code'] as String?) ?? '',
        store: StoreRef.fromJson(json['store'] as Map<String, dynamic>),
        status: (json['status'] as String?) ?? 'DRAFT',
        totalScore: _d(json['totalScore']),
        criticalFail: (json['criticalFail'] as bool?) ?? false,
        approvedRevision: _i(json['approvedRevision']),
        // Older payloads carry no source — those rows are admin-created.
        source: (json['source'] as String?) ?? 'ADMIN',
        requesterName: _s(json['requesterName']),
        requesterEmployeeCode: _s(json['requesterEmployeeCode']),
        tokenExpiresAt: _date(json['tokenExpiresAt']),
        deadline: _date(json['deadline']),
        createdAt: _date(json['createdAt']),
      );

  final String id;
  final String code;
  final StoreRef store;
  final String status;
  final double? totalScore;
  final bool criticalFail;
  final int approvedRevision;
  final String source;
  final String? requesterName;
  final String? requesterEmployeeCode;
  final DateTime? tokenExpiresAt;
  final DateTime? deadline;
  final DateTime? createdAt;
}

/// One-shot result of the public MS link generator — the only place the
/// raw link ever exists client-side.
class MsCreateResult {
  const MsCreateResult({
    required this.code,
    required this.storeName,
    required this.url,
    required this.expiresAt,
  });

  factory MsCreateResult.fromJson(Map<String, dynamic> json) => MsCreateResult(
        code: (json['code'] as String?) ?? '',
        storeName: (json['storeName'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        expiresAt: _date(json['expiresAt']) ?? DateTime.now(),
      );

  final String code;
  final String storeName;
  final String url;
  final DateTime expiresAt;
}

class MsPublicView {
  const MsPublicView({
    required this.code,
    required this.storeName,
    required this.status,
    required this.sections,
    this.scenario,
    this.productsToBuy,
    this.budgetVnd,
    this.brief,
    this.deadline,
    this.revisionNote,
    this.submission,
  });

  factory MsPublicView.fromJson(Map<String, dynamic> json) => MsPublicView(
        code: (json['code'] as String?) ?? '',
        storeName: (json['storeName'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'OPENED',
        scenario: _s(json['scenario']),
        productsToBuy: _s(json['productsToBuy']),
        budgetVnd: json['budgetVnd'] == null ? null : _i(json['budgetVnd']),
        brief: _s(json['brief']),
        deadline: _date(json['deadline']),
        revisionNote: _s(json['revisionNote']),
        submission: json['submission'] is Map<String, dynamic>
            ? MsSubmissionView.fromJson(json['submission'] as Map<String, dynamic>)
            : null,
        sections: _list((json['template'] as Map<String, dynamic>?)?['sections'])
            .map(MsSectionView.fromJson)
            .toList(),
      );

  final String code;
  final String storeName;
  final String status;
  final String? scenario;
  final String? productsToBuy;
  final int? budgetVnd;
  final String? brief;
  final DateTime? deadline;
  final String? revisionNote;
  final MsSubmissionView? submission;
  final List<MsSectionView> sections;
}

class MsIssuedToken {
  const MsIssuedToken({required this.url, required this.token, required this.expiresAt});
  factory MsIssuedToken.fromJson(Map<String, dynamic> json) => MsIssuedToken(
        url: json['url'] as String,
        token: json['token'] as String,
        expiresAt: _date(json['expiresAt']) ?? DateTime.now(),
      );
  final String url;
  final String token;
  final DateTime expiresAt;
}

class MsSectionScore {
  const MsSectionScore({required this.code, required this.title, required this.weight, this.score});
  factory MsSectionScore.fromJson(Map<String, dynamic> json) => MsSectionScore(
        code: (json['code'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        weight: _i(json['weight']),
        score: _d(json['score']),
      );
  final String code;
  final String title;
  final int weight;
  final double? score;
}

class MsResultView {
  const MsResultView({
    required this.outcome,
    required this.criticalFail,
    required this.sections,
    required this.issues,
    required this.criticals,
    this.totalScore,
  });

  factory MsResultView.fromJson(Map<String, dynamic> json) => MsResultView(
        outcome: (json['outcome'] as String?) ?? 'PASS',
        totalScore: _d(json['totalScore']),
        criticalFail: (json['criticalFail'] as bool?) ?? false,
        sections: _list(json['sections']).map(MsSectionScore.fromJson).toList(),
        issues: (json['issues'] as List?)?.whereType<String>().toList() ?? const [],
        criticals: (json['criticals'] as List?)?.whereType<String>().toList() ?? const [],
      );

  final String outcome;
  final double? totalScore;
  final bool criticalFail;
  final List<MsSectionScore> sections;
  final List<String> issues;
  final List<String> criticals;
}

// ── Training ────────────────────────────────────────────────────────────────

class PersonView {
  const PersonView({
    required this.id,
    required this.fullName,
    required this.position,
    required this.isActive,
    this.store,
    this.startDate,
    this.notes,
  });

  factory PersonView.fromJson(Map<String, dynamic> json) => PersonView(
        id: json['id'] as String,
        fullName: (json['fullName'] as String?) ?? '',
        position: (json['position'] as String?) ?? '',
        isActive: (json['isActive'] as bool?) ?? true,
        store: json['store'] is Map<String, dynamic>
            ? StoreRef.fromJson(json['store'] as Map<String, dynamic>)
            : null,
        startDate: _date(json['startDate']),
        notes: _s(json['notes']),
      );

  final String id;
  final String fullName;
  final String position;
  final bool isActive;
  final StoreRef? store;
  final DateTime? startDate;
  final String? notes;
}

class MaterialView {
  const MaterialView({
    required this.id,
    required this.title,
    required this.category,
    required this.kind,
    required this.version,
    required this.isActive,
    required this.isRequired,
    this.description,
    this.url,
    this.estimatedMinutes,
  });

  factory MaterialView.fromJson(Map<String, dynamic> json) => MaterialView(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        category: (json['category'] as String?) ?? 'QUY_DINH',
        kind: (json['kind'] as String?) ?? 'LINK',
        version: _i(json['version']),
        isActive: (json['isActive'] as bool?) ?? true,
        isRequired: (json['isRequired'] as bool?) ?? false,
        description: _s(json['description']),
        url: _s(json['url']),
        estimatedMinutes: json['estimatedMinutes'] == null ? null : _i(json['estimatedMinutes']),
      );

  final String id;
  final String title;
  final String category;
  final String kind;
  final int version;
  final bool isActive;
  final bool isRequired;
  final String? description;
  final String? url;
  final int? estimatedMinutes;
}

class PathItemView {
  const PathItemView({required this.material, required this.isRequired, this.dueDays});
  factory PathItemView.fromJson(Map<String, dynamic> json) => PathItemView(
        material: MaterialView.fromJson(json['material'] as Map<String, dynamic>),
        isRequired: (json['isRequired'] as bool?) ?? true,
        dueDays: json['dueDays'] == null ? null : _i(json['dueDays']),
      );
  final MaterialView material;
  final bool isRequired;
  final int? dueDays;
}

class PathView {
  const PathView({
    required this.id,
    required this.name,
    required this.isActive,
    required this.items,
    required this.assignmentCount,
    this.position,
  });

  factory PathView.fromJson(Map<String, dynamic> json) => PathView(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        position: _s(json['position']),
        isActive: (json['isActive'] as bool?) ?? true,
        items: _list(json['items']).map(PathItemView.fromJson).toList(),
        assignmentCount: _i((json['_count'] as Map<String, dynamic>?)?['assignments']),
      );

  final String id;
  final String name;
  final String? position;
  final bool isActive;
  final List<PathItemView> items;
  final int assignmentCount;
}

class ProgressView {
  const ProgressView({
    required this.id,
    required this.status,
    required this.effectiveStatus,
    required this.overdue,
    required this.isRequired,
    required this.material,
    required this.attempts,
    this.completedAt,
    this.dueAt,
    this.quizScore,
    this.notes,
  });

  factory ProgressView.fromJson(Map<String, dynamic> json) => ProgressView(
        id: json['id'] as String,
        status: (json['status'] as String?) ?? 'NOT_STARTED',
        effectiveStatus: (json['effectiveStatus'] as String?) ?? 'NOT_STARTED',
        overdue: (json['overdue'] as bool?) ?? false,
        isRequired: (json['isRequired'] as bool?) ?? true,
        material: MaterialView.fromJson(json['material'] as Map<String, dynamic>),
        completedAt: _date(json['completedAt']),
        dueAt: _date(json['dueAt']),
        quizScore: json['quizScore'] == null ? null : _i(json['quizScore']),
        attempts: _i(json['attempts']),
        notes: _s(json['notes']),
      );

  final String id;
  final String status;
  final String effectiveStatus;
  final bool overdue;
  final bool isRequired;
  final MaterialView material;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final int? quizScore;
  final int attempts;
  final String? notes;
}

class TrainingOverviewRow {
  const TrainingOverviewRow({
    required this.id,
    required this.path,
    required this.startDate,
    required this.percentDone,
    required this.overdueCount,
    required this.progress,
    this.person,
  });

  factory TrainingOverviewRow.fromJson(Map<String, dynamic> json) => TrainingOverviewRow(
        id: json['id'] as String,
        person: json['person'] is Map<String, dynamic>
            ? PersonView.fromJson(json['person'] as Map<String, dynamic>)
            : null,
        path: StoreRef.fromJson(json['path'] as Map<String, dynamic>),
        startDate: _date(json['startDate']) ?? DateTime.now(),
        percentDone: _i(json['percentDone']),
        overdueCount: _i(json['overdueCount']),
        progress: _list(json['progress']).map(ProgressView.fromJson).toList(),
      );

  final String id;
  final PersonView? person;

  /// `{id, name}` — reuses [StoreRef] as a generic id+name pair.
  final StoreRef path;
  final DateTime startDate;
  final int percentDone;
  final int overdueCount;
  final List<ProgressView> progress;
}

/// Trainee "my training" payload: the caller's linked person (null when the
/// admin has not linked one yet) + their own assignments.
class MyTraining {
  const MyTraining({required this.person, required this.assignments});

  factory MyTraining.fromJson(Map<String, dynamic> json) => MyTraining(
        person: json['person'] is Map<String, dynamic>
            ? PersonView.fromJson(json['person'] as Map<String, dynamic>)
            : null,
        assignments: _list(json['assignments']).map(TrainingOverviewRow.fromJson).toList(),
      );

  final PersonView? person;
  final List<TrainingOverviewRow> assignments;
}

// ── Schedule ────────────────────────────────────────────────────────────────

class WeekListItem {
  const WeekListItem({
    required this.id,
    required this.weekStart,
    required this.status,
    required this.revision,
  });

  factory WeekListItem.fromJson(Map<String, dynamic> json) => WeekListItem(
        id: json['id'] as String,
        weekStart: _date(json['weekStart']) ?? DateTime.now(),
        status: (json['status'] as String?) ?? 'DRAFT',
        revision: _i(json['revision']),
      );

  final String id;
  final DateTime weekStart;
  final String status;
  final int revision;
}

class ShiftAssignView {
  const ShiftAssignView({
    required this.id,
    required this.dayOfWeek,
    this.personId,
    this.personName,
    this.personActive,
    this.freeName,
    this.note,
  });

  factory ShiftAssignView.fromJson(Map<String, dynamic> json) => ShiftAssignView(
        id: json['id'] as String,
        dayOfWeek: _i(json['dayOfWeek']),
        personId: _s(json['personId']),
        personName: _s(json['personName']),
        personActive: json['personActive'] as bool?,
        freeName: _s(json['freeName']),
        note: _s(json['note']),
      );

  final String id;
  final int dayOfWeek;
  final String? personId;
  final String? personName;
  final bool? personActive;
  final String? freeName;
  final String? note;

  String get displayName => personName ?? freeName ?? '?';
}

class ShiftView {
  const ShiftView({
    required this.id,
    required this.store,
    required this.label,
    required this.startTime,
    required this.endTime,
    required this.assignments,
  });

  factory ShiftView.fromJson(Map<String, dynamic> json) => ShiftView(
        id: json['id'] as String,
        store: StoreRef.fromJson(json['store'] as Map<String, dynamic>),
        label: (json['label'] as String?) ?? '',
        startTime: (json['startTime'] as String?) ?? '',
        endTime: (json['endTime'] as String?) ?? '',
        assignments: _list(json['assignments']).map(ShiftAssignView.fromJson).toList(),
      );

  final String id;
  final StoreRef store;
  final String label;
  final String startTime;
  final String endTime;
  final List<ShiftAssignView> assignments;

  List<ShiftAssignView> forDay(int day) =>
      assignments.where((a) => a.dayOfWeek == day).toList();
}

class ScheduleWarningView {
  const ScheduleWarningView({required this.kind, required this.message, this.dayOfWeek});
  factory ScheduleWarningView.fromJson(Map<String, dynamic> json) => ScheduleWarningView(
        kind: (json['kind'] as String?) ?? '',
        message: (json['message'] as String?) ?? '',
        dayOfWeek: json['dayOfWeek'] == null ? null : _i(json['dayOfWeek']),
      );
  final String kind;
  final String message;
  final int? dayOfWeek;
}

class ScheduleWeek {
  const ScheduleWeek({
    required this.id,
    required this.weekStart,
    required this.status,
    required this.revision,
    required this.shifts,
    required this.warnings,
    this.publishedAt,
  });

  factory ScheduleWeek.fromJson(Map<String, dynamic> json) => ScheduleWeek(
        id: json['id'] as String,
        weekStart: _date(json['weekStart']) ?? DateTime.now(),
        status: (json['status'] as String?) ?? 'DRAFT',
        revision: _i(json['revision']),
        publishedAt: _date(json['publishedAt']),
        shifts: _list(json['shifts']).map(ShiftView.fromJson).toList(),
        warnings: _list(json['warnings']).map(ScheduleWarningView.fromJson).toList(),
      );

  final String id;
  final DateTime weekStart;
  final String status;
  final int revision;
  final DateTime? publishedAt;
  final List<ShiftView> shifts;
  final List<ScheduleWarningView> warnings;
}

class UploadedFileRef {
  const UploadedFileRef({required this.name, required this.size, required this.mimeType});
  factory UploadedFileRef.fromJson(Map<String, dynamic> json) => UploadedFileRef(
        name: json['name'] as String,
        size: _i(json['size']),
        mimeType: (json['mimeType'] as String?) ?? '',
      );

  /// PRIVATE store file name (hex + extension) — not a URL; bytes stream
  /// through the authorised endpoints only.
  final String name;
  final int size;
  final String mimeType;
}
