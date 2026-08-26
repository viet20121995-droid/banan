import 'dart:async';
import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_internal/data/internal_api.dart';
import 'package:banan_internal/data/internal_models.dart';
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
}

/// Public MS API stub with scripted responses per call.
class FakePublicApi extends InternalPublicApi {
  FakePublicApi(this.viewResult) : super(Dio());
  final Result<MsPublicView, AppFailure> viewResult;

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
