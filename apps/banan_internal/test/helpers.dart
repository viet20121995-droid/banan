import 'dart:async';
import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_internal/data/internal_api.dart';
import 'package:banan_internal/data/internal_models.dart';
import 'package:banan_internal/data/survey_models.dart';
import 'package:dio/dio.dart';

User testUser({Role role = Role.admin}) => User(
      id: 'u1',
      email: 'admin@banan.local',
      fullName: 'Admin',
      role: role,
      membershipTier: MembershipTier.bronze,
      pointsBalance: 0,
    );

AuthSession testSession({Role role = Role.admin}) =>
    AuthSession(accessToken: 'a', refreshToken: 'r', user: testUser(role: role));

/// Auth repository stub: fixed session, live stream, everything else unused.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._session);
  final AuthSession? _session;
  final _controller = StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> watchSession() async* {
    yield _session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();

  void dispose() {
    unawaited(_controller.close());
  }
}

/// InternalApi stub — override just what a test screen calls.
class FakeInternalApi extends InternalApi {
  FakeInternalApi({this.week, this.qcItems = const [], this.qcDetailJson}) : super(Dio());

  final ScheduleWeek? week;
  final List<QcListItem> qcItems;
  final Map<String, dynamic>? qcDetailJson;

  @override
  Future<Result<List<StoreRef>, AppFailure>> stores() async => const Result.success([
        StoreRef(id: 's1', name: 'Banan – Lê Thánh Tôn'),
        StoreRef(id: 's2', name: 'Banan – Sư Vạn Hạnh'),
        StoreRef(id: 's3', name: 'Banan – Ngô Quang Huy'),
        StoreRef(id: 's4', name: 'Banan – Trường Sa'),
      ]);

  @override
  Future<Result<List<QcListItem>, AppFailure>> qcList({
    String? storeId,
    String? status,
    String? outcome,
    DateTime? from,
    DateTime? to,
  }) async =>
      Result.success(qcItems);

  @override
  Future<Result<QcInspectionDetail, AppFailure>> qcDetail(String id) async =>
      Result.success(QcInspectionDetail.fromJson(qcDetailJson!));

  @override
  Future<Result<QcResultView, AppFailure>> qcResult(String id) async => Result.success(
        QcResultView.fromJson(const {
          'outcome': 'PASS',
          'overallPercent': null,
          'overallPass': 0,
          'overallApplicable': 0,
          'riskOccurred': false,
          'sections': <Object>[],
          'failedItems': <Object>[],
          'occurredRisks': <Object>[],
        }),
      );

  @override
  Future<Result<List<WeekListItem>, AppFailure>> weeks() async => const Result.success([]);

  @override
  Future<Result<ScheduleWeek?, AppFailure>> weekByStart(DateTime weekStart) async =>
      Result.success(week);

  @override
  Future<Result<List<PersonView>, AppFailure>> people({String? storeId, String? q}) async =>
      const Result.success([]);

  @override
  Future<Result<MyTraining, AppFailure>> myTraining() async =>
      const Result.success(MyTraining(person: null, assignments: []));

  @override
  Future<Result<List<MaterialView>, AppFailure>> myMaterials() async =>
      const Result.success([]);

  @override
  Future<Result<List<MsListItem>, AppFailure>> msList({
    String? storeId,
    String? status,
    String? source,
  }) async =>
      const Result.success([]);

  // ── survey admin fakes ──
  /// Every summary query lands here — filter tests assert on it.
  final surveySummaryQueries = <Map<String, dynamic>>[];

  /// Every case PATCH lands here.
  final caseUpdates = <(String, Map<String, dynamic>)>[];

  @override
  Future<Result<SurveySummary, AppFailure>> surveySummary(Map<String, dynamic> query) async {
    surveySummaryQueries.add(query);
    return Result.success(SurveySummary.fromJson(surveySummaryJson()));
  }

  @override
  Future<Result<List<SurveyResponseRow>, AppFailure>> surveyResponses(
    Map<String, dynamic> query,
  ) async =>
      const Result.success([]);

  @override
  Future<Result<List<SurveyCaseView>, AppFailure>> surveyCases({
    String? status,
    String? storeId,
  }) async =>
      Result.success([SurveyCaseView.fromJson(surveyCaseJson())]);

  @override
  Future<Result<SurveyCaseView, AppFailure>> surveyUpdateCase(
    String id,
    Map<String, dynamic> body,
  ) async {
    caseUpdates.add((id, body));
    return Result.success(SurveyCaseView.fromJson(surveyCaseJson()));
  }

  @override
  Future<Result<List<SurveyTemplateListItem>, AppFailure>> surveyTemplates() async =>
      Result.success([
        SurveyTemplateListItem.fromJson(const {
          'id': 'tpl1',
          'name': 'Khảo sát trải nghiệm tại quán',
          'version': 1,
          'status': 'PUBLISHED',
          'isDefault': true,
          'questionCount': 10,
          'responseCount': 3,
        }),
      ]);

  @override
  Future<Result<SurveyTemplateView, AppFailure>> surveyTemplateDetail(String id) async =>
      Result.success(SurveyTemplateView.fromJson(surveyTemplateJson()));

  @override
  Future<Result<List<SurveyCampaignView>, AppFailure>> surveyCampaigns() async =>
      Result.success([SurveyCampaignView.fromJson(surveyCampaignJson())]);

  @override
  Future<Result<List<SurveyClaimView>, AppFailure>> surveyClaims({
    String? campaignId,
    String? status,
  }) async =>
      const Result.success([]);

  @override
  Future<Result<SurveyRedeemResult, AppFailure>> surveyRedeem(String code) async =>
      code == 'BAN-GOOD-CODE'
          ? Result.success(SurveyRedeemResult.fromJson(const {
              'voucherCode': 'BAN-GOOD-CODE',
              'campaignName': 'Bánh mini',
              'storeName': 'Banan – Lê Thánh Tôn',
            }),)
          : const Result.failure(
              ServerFailure(code: 'SURVEY_REWARD_CODE_NOT_FOUND', message: 'Không tìm thấy mã quà này.'),
            );
}

/// Public MS API stub with scripted responses per call.
class FakePublicApi extends InternalPublicApi {
  FakePublicApi(
    this.viewResult, {
    Result<SurveyPublicInfo, AppFailure>? surveyInfoResult,
    Result<SurveySubmitResult, AppFailure>? surveySubmitResult,
  })  : surveyInfoResult = surveyInfoResult ??
            Result.success(SurveyPublicInfo.fromJson(surveyPublicInfoJson())),
        surveySubmitResult = surveySubmitResult ??
            const Result.success(SurveySubmitResult(id: 'resp1')),
        super(Dio());
  final Result<MsPublicView, AppFailure> viewResult;
  final Result<SurveyPublicInfo, AppFailure> surveyInfoResult;
  final Result<SurveySubmitResult, AppFailure> surveySubmitResult;

  /// Every survey submit body lands here — tests assert on the wire shape.
  final surveySubmits = <Map<String, dynamic>>[];

  @override
  Future<Result<SurveyPublicInfo, AppFailure>> surveyInfo() async => surveyInfoResult;

  @override
  Future<Result<SurveySubmitResult, AppFailure>> surveySubmit(
    Map<String, dynamic> body,
  ) async {
    surveySubmits.add(body);
    return surveySubmitResult;
  }

  @override
  Future<Result<List<StoreRef>, AppFailure>> stores() async => const Result.success([
        StoreRef(id: 's1', name: 'Banan – Lê Thánh Tôn'),
        StoreRef(id: 's2', name: 'Banan – Sư Vạn Hạnh'),
      ]);

  @override
  Future<Result<MsPublicView, AppFailure>> view(String token) async => viewResult;

  @override
  Future<Result<MsPublicView, AppFailure>> save(
    String token,
    Map<String, dynamic> body,
  ) async =>
      viewResult;

  @override
  Future<Result<MsPublicView, AppFailure>> submit(String token) async => viewResult;

  @override
  Future<Result<MsPublicView, AppFailure>> upload({
    required String token,
    required String kind,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? questionId,
  }) async =>
      viewResult;
}

Map<String, dynamic> publicViewJson({required String status}) => {
      'code': 'MS-2026-TEST1',
      'storeName': 'Banan – Lê Thánh Tôn',
      'status': status,
      'scenario': 'Mua 1 bánh mousse',
      'productsToBuy': 'Mousse chanh dây',
      'budgetVnd': 300000,
      'template': {
        'sections': [
          {
            'id': 'secA',
            'code': 'A',
            'title': 'Tiếp cận cửa hàng',
            'kind': 'SCORED',
            'weight': 5,
            'questions': [
              {'id': 'q1', 'text': 'Lối vào sạch, dễ tiếp cận.', 'allowNa': false},
              {'id': 'q2', 'text': 'Ấn tượng phù hợp thương hiệu.', 'allowNa': false},
            ],
          },
          {
            'id': 'secC',
            'code': 'CRIT',
            'title': 'Lỗi nghiêm trọng',
            'kind': 'CRITICAL',
            'weight': 0,
            'questions': [
              {'id': 'q3', 'text': 'Thu sai tiền.', 'allowNa': false},
            ],
          },
        ],
      },
      'submission': status == 'SUBMITTED'
          ? {
              'submittedAt': '2026-08-20T03:00:00.000Z',
              'answers': <Object>[],
              'evidence': <Object>[],
            }
          : null,
    };

Map<String, dynamic> scheduleWeekJson() => {
      'id': 'w1',
      'weekStart': '2026-08-17T00:00:00.000Z',
      'status': 'DRAFT',
      'revision': 0,
      'publishedAt': null,
      'warnings': <Object>[],
      'shifts': [
        for (final (i, name) in const [
          (1, 'Banan – Lê Thánh Tôn'),
          (2, 'Banan – Sư Vạn Hạnh'),
          (3, 'Banan – Ngô Quang Huy'),
          (4, 'Banan – Trường Sa'),
        ].indexed)
          {
            'id': 'sh$i',
            'store': {'id': 's${name.$1}', 'name': name.$2},
            'label': 'Ca 1',
            'startTime': '09:00',
            'endTime': '14:00',
            'sortOrder': 0,
            'assignments': [
              {
                'id': 'a$i',
                'dayOfWeek': 0,
                'personId': null,
                'personName': null,
                'personActive': null,
                'freeName': 'Phương',
                'note': i == 0 ? 'đến 16h' : null,
              },
            ],
          },
      ],
    };

Map<String, dynamic> qcDetailJson() => {
      'id': 'insp1',
      'code': 'QC-20260820-ABC123',
      'store': {'id': 's1', 'name': 'Banan – Lê Thánh Tôn'},
      'status': 'IN_PROGRESS',
      'revision': 0,
      'outcome': null,
      'overallPercent': null,
      'inspectionDate': '2026-08-20T00:00:00.000Z',
      'inspectorName': 'admin@banan.local',
      'sections': [
        {
          'id': 'sec1',
          'title': 'RECEIVING & STORING',
          'isRisk': false,
          'items': [
            {
              'id': 'i1',
              'no': 1,
              'text': 'Ngoại quan đạt yêu cầu.',
              'value': null,
              'evidence': <Object>[],
            },
          ],
        },
        {
          'id': 'risk',
          'title': 'RISK',
          'isRisk': true,
          'items': [
            {
              'id': 'r1',
              'no': 1,
              'text': 'Có lưu trữ sản phẩm hết hạn.',
              'occurred': null,
              'evidence': <Object>[],
            },
          ],
        },
      ],
    };

// ── survey fixtures ─────────────────────────────────────────────────────────

/// Default-template shape, ids `q-<code>` — mirrors the backend seed.
Map<String, dynamic> surveyTemplateJson() => {
      'id': 'tpl1',
      'name': 'Khảo sát trải nghiệm tại quán',
      'version': 1,
      'status': 'PUBLISHED',
      'isDefault': true,
      'questions': [
        {
          'id': 'q-overall',
          'code': 'overall',
          'type': 'EMOJI_SCALE',
          'textVi': 'Trải nghiệm tại Banan hôm nay thế nào?',
          'textEn': 'How was your experience at Banan today?',
          'required': true,
        },
        {
          'id': 'q-food',
          'code': 'food_drink',
          'type': 'RATING',
          'textVi': 'Bánh / đồ uống',
          'textEn': 'Food & drinks',
          'required': false,
        },
        {
          'id': 'q-attitude',
          'code': 'service_attitude',
          'type': 'RATING',
          'textVi': 'Thái độ phục vụ',
          'textEn': 'Service attitude',
          'required': false,
        },
        {
          'id': 'q-improve',
          'code': 'improve',
          'type': 'MULTI_CHOICE',
          'textVi': 'Banan cần cải thiện điều gì?',
          'textEn': 'What should Banan improve?',
          'required': false,
          'showIfQuestionCode': 'overall',
          'showIfOp': 'LTE',
          'showIfValue': 3,
          'options': [
            {'value': 'speed', 'labelVi': 'Tốc độ phục vụ', 'labelEn': 'Service speed'},
            {'value': 'hygiene', 'labelVi': 'Vệ sinh', 'labelEn': 'Hygiene'},
          ],
        },
        {
          'id': 'q-praise',
          'code': 'praise',
          'type': 'MULTI_CHOICE',
          'textVi': 'Điều gì làm bạn thích nhất?',
          'textEn': 'What did you like most?',
          'required': false,
          'showIfQuestionCode': 'overall',
          'showIfOp': 'GTE',
          'showIfValue': 4,
          'options': [
            {'value': 'taste', 'labelVi': 'Hương vị bánh & đồ uống', 'labelEn': 'Taste'},
            {'value': 'staff', 'labelVi': 'Nhân viên thân thiện', 'labelEn': 'Friendly staff'},
          ],
        },
        {
          'id': 'q-nps',
          'code': 'nps',
          'type': 'NPS',
          'textVi': 'Bạn có sẵn lòng giới thiệu Banan cho bạn bè?',
          'textEn': 'How likely are you to recommend Banan?',
          'required': false,
        },
        {
          'id': 'q-comment',
          'code': 'comment',
          'type': 'TEXT',
          'textVi': 'Góp ý thêm cho Banan',
          'textEn': 'Anything else?',
          'required': false,
          'maxLength': 1000,
        },
        {
          'id': 'q-contact',
          'code': 'contact_request',
          'type': 'YES_NO',
          'textVi': 'Bạn có muốn Banan liên hệ để xử lý vấn đề không?',
          'textEn': 'Would you like Banan to contact you?',
          'required': false,
          'showIfQuestionCode': 'overall',
          'showIfOp': 'LTE',
          'showIfValue': 2,
        },
      ],
    };

Map<String, dynamic> surveyPublicInfoJson() => {
      'template': surveyTemplateJson(),
      'stores': [
        {'id': 's1', 'name': 'Banan – Lê Thánh Tôn', 'address': '15 Lê Thánh Tôn, Q1'},
        {'id': 's2', 'name': 'Banan – Sư Vạn Hạnh', 'address': '830 Sư Vạn Hạnh, Q10'},
      ],
      'reward': null,
    };

Map<String, dynamic> surveySummaryJson() => {
      'total': 12,
      'avgOverall': 4.25,
      'pctHigh': 75,
      'pctLow': 8,
      'nps': 42,
      'npsCount': 10,
      'openCases': 2,
      'overdueCases': 1,
      'trend': [
        {'bucket': '2026-08-28', 'count': 5, 'avgOverall': 4.2},
        {'bucket': '2026-08-29', 'count': 7, 'avgOverall': 4.3},
      ],
      'stores': [
        {
          'storeId': 's1',
          'storeName': 'Banan – Lê Thánh Tôn',
          'count': 8,
          'avgOverall': 4.5,
          'lowCount': 0,
        },
        {
          'storeId': 's2',
          'storeName': 'Banan – Sư Vạn Hạnh',
          'count': 4,
          'avgOverall': 3.75,
          'lowCount': 2,
        },
      ],
      'categories': [
        {'code': 'food_drink', 'label': 'Bánh / đồ uống', 'avg': 4.6, 'count': 10},
        {'code': 'service_speed', 'label': 'Tốc độ phục vụ', 'avg': 3.9, 'count': 9},
      ],
      'topIssues': [
        {'value': 'speed', 'label': 'Tốc độ phục vụ', 'count': 3},
      ],
      'topPraise': [
        {'value': 'taste', 'label': 'Hương vị bánh & đồ uống', 'count': 6},
      ],
      'recentComments': [
        {
          'id': 'r1',
          'comment': 'Bánh ngon lắm!',
          'storeName': 'Banan – Lê Thánh Tôn',
          'overall': 5,
          'createdAt': '2026-08-29T03:00:00.000Z',
        },
      ],
    };

Map<String, dynamic> surveyCaseJson() => {
      'id': 'case1',
      'status': 'NEW',
      'overdue': false,
      'assigneeName': null,
      'note': null,
      'resolvedAt': null,
      'createdAt': '2026-08-29T03:00:00.000Z',
      'response': {
        'id': 'resp1',
        'storeName': 'Banan – Sư Vạn Hạnh',
        'overall': 1,
        'nps': 2,
        'comment': 'Phục vụ chậm quá',
        'createdAt': '2026-08-29T03:00:00.000Z',
        'contact': {'name': 'Chị Mai', 'phone': '0900000001'},
      },
    };

Map<String, dynamic> surveyCampaignJson() => {
      'id': 'camp1',
      'name': 'Bánh mini cảm ơn',
      'mode': 'VOUCHER_CODE',
      'isEnabled': false,
      'expiryDays': 7,
      'probabilityPct': 100,
      'issuedCount': 4,
      'redeemedCount': 1,
      'description': 'Một bánh mini miễn phí',
      'dailyCap': 10,
      'totalCap': 100,
    };
