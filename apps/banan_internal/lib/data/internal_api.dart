import 'dart:typed_data';

import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'internal_models.dart';
import 'survey_models.dart';

/// Authed API client for the internal ops endpoints. Uses the shared Dio
/// (Bearer + refresh interceptors from banan_data); the public MS form uses
/// [InternalPublicApi] with a bare Dio instead — no tokens attached.
class InternalApi {
  InternalApi(this._dio);
  final Dio _dio;

  // ── shared plumbing ──
  Future<Result<T, AppFailure>> _run<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic data) parse,
  ) async {
    try {
      final res = await call();
      final status = res.statusCode ?? 0;
      final body = res.data;
      if (status >= 400) return Result.failure(_httpFailure(status, body));
      final data = body is Map<String, dynamic> ? body['data'] : body;
      return Result.success(parse(data));
    } on DioException catch (e) {
      return Result.failure(_dioFailure(e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  AppFailure _httpFailure(int status, dynamic body) {
    var code = 'HTTP_$status';
    String? message;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        code = (err['code'] as String?) ?? code;
        message = err['message'] as String?;
      }
    }
    if (status == 401) return AuthFailure(code: code, message: message);
    if (status == 403) return AuthFailure(code: 'AUTH_FORBIDDEN', message: message);
    return ServerFailure(code: code, message: message);
  }

  AppFailure _dioFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return TimeoutFailure(cause: e);
      case DioExceptionType.connectionError:
        return NetworkFailure(cause: e);
      case DioExceptionType.badResponse:
        return _httpFailure(e.response?.statusCode ?? 0, e.response?.data);
      // ignore: no_default_cases
      default:
        return UnknownFailure(message: e.message, cause: e);
    }
  }

  // ── stores ──
  Future<Result<List<StoreRef>, AppFailure>> stores() => _run(
        () => _dio.get<dynamic>('/stores'),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(StoreRef.fromJson)
            .toList(),
      );

  // ── QC ──
  Future<Result<List<QcListItem>, AppFailure>> qcList({
    String? storeId,
    String? status,
    String? outcome,
    DateTime? from,
    DateTime? to,
  }) =>
      _run(
        () => _dio.get<dynamic>('/internal/qc/inspections', queryParameters: {
          if (storeId != null) 'storeId': storeId,
          if (status != null) 'status': status,
          if (outcome != null) 'outcome': outcome,
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
          'perPage': 100,
        },),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(QcListItem.fromJson)
            .toList(),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcCreate({
    required String storeId,
    required DateTime inspectionDate,
    String? inspectorName,
    String? staffOnShift,
  }) =>
      _run(
        () => _dio.post<dynamic>('/internal/qc/inspections', data: {
          'storeId': storeId,
          'inspectionDate': inspectionDate.toIso8601String(),
          if (inspectorName != null && inspectorName.isNotEmpty)
            'inspectorName': inspectorName,
          if (staffOnShift != null && staffOnShift.isNotEmpty) 'staffOnShift': staffOnShift,
        },),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcDetail(String id) => _run(
        () => _dio.get<dynamic>('/internal/qc/inspections/$id'),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcUpdateHeader(
    String id,
    Map<String, dynamic> patch,
  ) =>
      _run(
        () => _dio.patch<dynamic>('/internal/qc/inspections/$id', data: patch),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcAnswer(
    String id,
    String itemId, {
    required String value,
    String? failDetail,
    String? naReason,
  }) =>
      _run(
        () => _dio.put<dynamic>('/internal/qc/inspections/$id/answers/$itemId', data: {
          'value': value,
          if (failDetail != null) 'failDetail': failDetail,
          if (naReason != null) 'naReason': naReason,
        },),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcRisk(
    String id,
    String itemId, {
    required bool occurred,
    String? detail,
  }) =>
      _run(
        () => _dio.put<dynamic>('/internal/qc/inspections/$id/risks/$itemId', data: {
          'occurred': occurred,
          if (detail != null) 'detail': detail,
        },),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcAttachEvidence(
    String id,
    String itemId,
    UploadedFileRef file,
  ) =>
      _run(
        () => _dio.post<dynamic>(
          '/internal/qc/inspections/$id/answers/$itemId/evidence',
          data: {'name': file.name, 'mimeType': file.mimeType, 'sizeBytes': file.size},
        ),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcRemoveEvidence(
    String id,
    String evidenceId,
  ) =>
      _run(
        () => _dio.delete<dynamic>('/internal/qc/inspections/$id/evidence/$evidenceId'),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcResultView, AppFailure>> qcResult(String id) => _run(
        () => _dio.get<dynamic>('/internal/qc/inspections/$id/result'),
        (data) => QcResultView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcComplete(String id) => _run(
        () => _dio.post<dynamic>('/internal/qc/inspections/$id/complete'),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<QcInspectionDetail, AppFailure>> qcReopen(String id) => _run(
        () => _dio.post<dynamic>('/internal/qc/inspections/$id/reopen'),
        (data) => QcInspectionDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<List<QcCompareRow>, AppFailure>> qcCompare(DateTime from, DateTime to) => _run(
        () => _dio.get<dynamic>('/internal/qc/compare', queryParameters: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },),
        (data) => ((data as Map<String, dynamic>)['stores'] as List)
            .whereType<Map<String, dynamic>>()
            .map(QcCompareRow.fromJson)
            .toList(),
      );

  /// Admin-authenticated PDF download (bytes for a save/print dialog).
  Future<Result<Uint8List, AppFailure>> qcPdf(String id) => _run(
        () => _dio.get<List<int>>(
          '/internal/qc/inspections/$id/report.pdf',
          options: Options(responseType: ResponseType.bytes),
        ),
        (data) => Uint8List.fromList((data as List).cast<int>()),
      );

  // ── private file store (admin) ──
  Future<Result<UploadedFileRef, AppFailure>> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) =>
      _run(
        () async => _dio.post<dynamic>(
          '/internal/files/upload',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              bytes,
              filename: filename,
              contentType: DioMediaType.parse(mimeType),
            ),
          }),
        ),
        (data) => UploadedFileRef.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<UploadedFileRef, AppFailure>> uploadTrainingPdf({
    required Uint8List bytes,
    required String filename,
  }) =>
      _run(
        () async => _dio.post<dynamic>(
          '/internal/files/upload-pdf',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              bytes,
              filename: filename,
              contentType: DioMediaType.parse('application/pdf'),
            ),
          }),
        ),
        (data) => UploadedFileRef.fromJson(data as Map<String, dynamic>),
      );

  /// Bytes of a PRIVATE stored file (evidence / training PDF) — Bearer via
  /// the shared interceptor; the UI renders them with Image.memory.
  Future<Result<Uint8List, AppFailure>> fileBytes(String name) => _run(
        () => _dio.get<List<int>>(
          '/internal/files/$name',
          options: Options(responseType: ResponseType.bytes),
        ),
        (data) => Uint8List.fromList((data as List).cast<int>()),
      );

  // ── MS (admin) ──
  Future<Result<List<MsListItem>, AppFailure>> msList({
    String? storeId,
    String? status,
    String? source,
  }) =>
      _run(
        () => _dio.get<dynamic>('/internal/ms/assignments', queryParameters: {
          if (storeId != null) 'storeId': storeId,
          if (status != null) 'status': status,
          if (source != null) 'source': source,
          'perPage': 100,
        },),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(MsListItem.fromJson)
            .toList(),
      );

  Future<Result<MsAssignmentDetail, AppFailure>> msCreate(Map<String, dynamic> body) => _run(
        () => _dio.post<dynamic>('/internal/ms/assignments', data: body),
        (data) => MsAssignmentDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MsAssignmentDetail, AppFailure>> msDetail(String id) => _run(
        () => _dio.get<dynamic>('/internal/ms/assignments/$id'),
        (data) => MsAssignmentDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MsAssignmentDetail, AppFailure>> msUpdate(
    String id,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.patch<dynamic>('/internal/ms/assignments/$id', data: body),
        (data) => MsAssignmentDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MsAssignmentDetail, AppFailure>> msCopy(String id) => _run(
        () => _dio.post<dynamic>('/internal/ms/assignments/$id/copy'),
        (data) => MsAssignmentDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MsIssuedToken, AppFailure>> msIssueToken(String id, {int? ttlDays}) => _run(
        () => _dio.post<dynamic>('/internal/ms/assignments/$id/token', data: {
          if (ttlDays != null) 'ttlDays': ttlDays,
        },),
        (data) => MsIssuedToken.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MsAssignmentDetail, AppFailure>> msRevoke(String id) => _run(
        () => _dio.post<dynamic>('/internal/ms/assignments/$id/revoke'),
        (data) => MsAssignmentDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MsAssignmentDetail, AppFailure>> msRequestRevision(String id, String note) =>
      _run(
        () => _dio.post<dynamic>(
          '/internal/ms/assignments/$id/request-revision',
          data: {'note': note},
        ),
        (data) => MsAssignmentDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MsResultView, AppFailure>> msResult(String id) => _run(
        () => _dio.get<dynamic>('/internal/ms/assignments/$id/result'),
        (data) => MsResultView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MsAssignmentDetail, AppFailure>> msApprove(String id) => _run(
        () => _dio.post<dynamic>('/internal/ms/assignments/$id/approve'),
        (data) => MsAssignmentDetail.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<Uint8List, AppFailure>> msPdf(String id) => _run(
        () => _dio.get<List<int>>(
          '/internal/ms/assignments/$id/report.pdf',
          options: Options(responseType: ResponseType.bytes),
        ),
        (data) => Uint8List.fromList((data as List).cast<int>()),
      );

  // ── Training (trainee self-service) ──
  Future<Result<MyTraining, AppFailure>> myTraining() => _run(
        () => _dio.get<dynamic>('/internal/training/me'),
        (data) => MyTraining.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<List<MaterialView>, AppFailure>> myMaterials() => _run(
        () => _dio.get<dynamic>('/internal/training/me/materials'),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(MaterialView.fromJson)
            .toList(),
      );

  /// Screen reloads myTraining after this — the raw row isn't re-parsed.
  Future<Result<void, AppFailure>> updateOwnProgress(String id, String status) => _run(
        () => _dio.patch<dynamic>(
          '/internal/training/me/progress/$id',
          data: {'status': status},
        ),
        (_) {},
      );

  // ── Training ──
  Future<Result<List<PersonView>, AppFailure>> people({String? storeId, String? q}) => _run(
        () => _dio.get<dynamic>('/internal/training/people', queryParameters: {
          if (storeId != null) 'storeId': storeId,
          if (q != null && q.isNotEmpty) 'q': q,
        },),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(PersonView.fromJson)
            .toList(),
      );

  Future<Result<PersonView, AppFailure>> createPerson(Map<String, dynamic> body) => _run(
        () => _dio.post<dynamic>('/internal/training/people', data: body),
        (data) => PersonView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<PersonView, AppFailure>> updatePerson(String id, Map<String, dynamic> body) =>
      _run(
        () => _dio.patch<dynamic>('/internal/training/people/$id', data: body),
        (data) => PersonView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<List<MaterialView>, AppFailure>> materials({bool all = false}) => _run(
        () => _dio.get<dynamic>(
          '/internal/training/materials',
          queryParameters: {if (all) 'all': 'true'},
        ),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(MaterialView.fromJson)
            .toList(),
      );

  Future<Result<MaterialView, AppFailure>> createMaterial(Map<String, dynamic> body) => _run(
        () => _dio.post<dynamic>('/internal/training/materials', data: body),
        (data) => MaterialView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<MaterialView, AppFailure>> reissueMaterial(
    String id,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.post<dynamic>('/internal/training/materials/$id/reissue', data: body),
        (data) => MaterialView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<List<PathView>, AppFailure>> paths() => _run(
        () => _dio.get<dynamic>('/internal/training/paths'),
        (data) =>
            (data as List).whereType<Map<String, dynamic>>().map(PathView.fromJson).toList(),
      );

  Future<Result<PathView, AppFailure>> createPath(Map<String, dynamic> body) => _run(
        () => _dio.post<dynamic>('/internal/training/paths', data: body),
        (data) => PathView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<TrainingOverviewRow, AppFailure>> assignPath(Map<String, dynamic> body) => _run(
        () => _dio.post<dynamic>('/internal/training/assignments', data: body),
        (data) => TrainingOverviewRow.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<List<TrainingOverviewRow>, AppFailure>> trainingProgress({
    String? storeId,
    String? personId,
    bool overdueOnly = false,
    String? status,
  }) =>
      _run(
        () => _dio.get<dynamic>('/internal/training/progress', queryParameters: {
          if (storeId != null) 'storeId': storeId,
          if (personId != null) 'personId': personId,
          if (overdueOnly) 'overdue': 'true',
          if (status != null) 'status': status,
        },),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(TrainingOverviewRow.fromJson)
            .toList(),
      );

  Future<Result<ProgressView, AppFailure>> updateProgress(
    String id,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.patch<dynamic>('/internal/training/progress/$id', data: body),
        (data) {
          final map = data as Map<String, dynamic>;
          // The PATCH response nests the material differently — normalise.
          return ProgressView.fromJson({
            ...map,
            'effectiveStatus': map['status'],
            'overdue': false,
            'isRequired': true,
            'material': (map['pathItem'] as Map<String, dynamic>)['material'],
          });
        },
      );

  // ── Schedule ──
  Future<Result<List<WeekListItem>, AppFailure>> weeks() => _run(
        () => _dio.get<dynamic>('/internal/schedule/weeks'),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(WeekListItem.fromJson)
            .toList(),
      );

  Future<Result<ScheduleWeek?, AppFailure>> weekByStart(DateTime weekStart) => _run(
        () => _dio.get<dynamic>('/internal/schedule/week', queryParameters: {
          'weekStart': weekStart.toIso8601String(),
        },),
        (data) => data == null ? null : ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> createWeek(
    DateTime weekStart, {
    String? copyFromScheduleId,
  }) =>
      _run(
        () => _dio.post<dynamic>('/internal/schedule/weeks', data: {
          'weekStart': weekStart.toIso8601String(),
          if (copyFromScheduleId != null) 'copyFromScheduleId': copyFromScheduleId,
        },),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> addShift(
    String scheduleId,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.post<dynamic>('/internal/schedule/weeks/$scheduleId/shifts', data: body),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> updateShift(
    String shiftId,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.patch<dynamic>('/internal/schedule/shifts/$shiftId', data: body),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> removeShift(String shiftId) => _run(
        () => _dio.delete<dynamic>('/internal/schedule/shifts/$shiftId'),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> addAssignment(
    String shiftId,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.post<dynamic>('/internal/schedule/shifts/$shiftId/assignments', data: body),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> updateAssignment(
    String assignmentId,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.patch<dynamic>('/internal/schedule/assignments/$assignmentId', data: body),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> removeAssignment(String assignmentId) => _run(
        () => _dio.delete<dynamic>('/internal/schedule/assignments/$assignmentId'),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> publishWeek(String scheduleId) => _run(
        () => _dio.post<dynamic>('/internal/schedule/weeks/$scheduleId/publish'),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<ScheduleWeek, AppFailure>> unpublishWeek(String scheduleId) => _run(
        () => _dio.post<dynamic>('/internal/schedule/weeks/$scheduleId/unpublish'),
        (data) => ScheduleWeek.fromJson(data as Map<String, dynamic>),
      );

  // ── Survey (admin) ──
  Future<Result<SurveySummary, AppFailure>> surveySummary(Map<String, dynamic> query) => _run(
        () => _dio.get<dynamic>('/internal/survey/reports/summary', queryParameters: query),
        (data) => SurveySummary.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<List<SurveyResponseRow>, AppFailure>> surveyResponses(
    Map<String, dynamic> query,
  ) =>
      _run(
        () => _dio.get<dynamic>('/internal/survey/responses', queryParameters: query),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(SurveyResponseRow.fromJson)
            .toList(),
      );

  /// CSV export bytes (UTF-8 with BOM) for a save dialog.
  Future<Result<Uint8List, AppFailure>> surveyExportCsv(Map<String, dynamic> query) => _run(
        () => _dio.get<List<int>>(
          '/internal/survey/reports/export.csv',
          queryParameters: query,
          options: Options(responseType: ResponseType.bytes),
        ),
        (data) => Uint8List.fromList((data as List).cast<int>()),
      );

  Future<Result<List<SurveyCaseView>, AppFailure>> surveyCases({
    String? status,
    String? storeId,
  }) =>
      _run(
        () => _dio.get<dynamic>('/internal/survey/cases', queryParameters: {
          if (status != null) 'status': status,
          if (storeId != null) 'storeId': storeId,
        },),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(SurveyCaseView.fromJson)
            .toList(),
      );

  Future<Result<SurveyCaseView, AppFailure>> surveyUpdateCase(
    String id,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.patch<dynamic>('/internal/survey/cases/$id', data: body),
        (data) => SurveyCaseView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<List<SurveyTemplateListItem>, AppFailure>> surveyTemplates() => _run(
        () => _dio.get<dynamic>('/internal/survey/templates'),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(SurveyTemplateListItem.fromJson)
            .toList(),
      );

  Future<Result<SurveyTemplateView, AppFailure>> surveyTemplateDetail(String id) => _run(
        () => _dio.get<dynamic>('/internal/survey/templates/$id'),
        (data) => SurveyTemplateView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<SurveyTemplateView, AppFailure>> surveyCreateTemplate({
    String? name,
    String? cloneFromId,
  }) =>
      _run(
        () => _dio.post<dynamic>('/internal/survey/templates', data: {
          if (name != null && name.isNotEmpty) 'name': name,
          if (cloneFromId != null) 'cloneFromId': cloneFromId,
        },),
        (data) => SurveyTemplateView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<SurveyTemplateView, AppFailure>> surveyReplaceQuestions(
    String id,
    List<Map<String, dynamic>> questions,
  ) =>
      _run(
        () => _dio.put<dynamic>(
          '/internal/survey/templates/$id/questions',
          data: {'questions': questions},
        ),
        (data) => SurveyTemplateView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<SurveyTemplateView, AppFailure>> surveyPublishTemplate(String id) => _run(
        () => _dio.post<dynamic>('/internal/survey/templates/$id/publish'),
        (data) => SurveyTemplateView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<SurveyTemplateView, AppFailure>> surveyArchiveTemplate(String id) => _run(
        () => _dio.post<dynamic>('/internal/survey/templates/$id/archive'),
        (data) => SurveyTemplateView.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<void, AppFailure>> surveyDeleteTemplate(String id) => _run(
        () => _dio.delete<dynamic>('/internal/survey/templates/$id'),
        (_) {},
      );

  Future<Result<List<SurveyCampaignView>, AppFailure>> surveyCampaigns() => _run(
        () => _dio.get<dynamic>('/internal/survey/rewards'),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(SurveyCampaignView.fromJson)
            .toList(),
      );

  Future<Result<List<SurveyCampaignView>, AppFailure>> surveyCreateCampaign(
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.post<dynamic>('/internal/survey/rewards', data: body),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(SurveyCampaignView.fromJson)
            .toList(),
      );

  Future<Result<List<SurveyCampaignView>, AppFailure>> surveyUpdateCampaign(
    String id,
    Map<String, dynamic> body,
  ) =>
      _run(
        () => _dio.patch<dynamic>('/internal/survey/rewards/$id', data: body),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(SurveyCampaignView.fromJson)
            .toList(),
      );

  Future<Result<SurveyRedeemResult, AppFailure>> surveyRedeem(String code) => _run(
        () => _dio.post<dynamic>('/internal/survey/rewards/redeem', data: {'code': code}),
        (data) => SurveyRedeemResult.fromJson(data as Map<String, dynamic>),
      );

  Future<Result<List<SurveyClaimView>, AppFailure>> surveyClaims({
    String? campaignId,
    String? status,
  }) =>
      _run(
        () => _dio.get<dynamic>('/internal/survey/rewards/claims', queryParameters: {
          if (campaignId != null) 'campaignId': campaignId,
          if (status != null) 'status': status,
        },),
        (data) => (data as List)
            .whereType<Map<String, dynamic>>()
            .map(SurveyClaimView.fromJson)
            .toList(),
      );
}

/// Token-based public API for the Mystery Shopper form. Plain Dio — no auth
/// interceptor, and the token travels in the POST body, never the URL.
class InternalPublicApi {
  InternalPublicApi(this._dio);
  final Dio _dio;

  /// Branch list for the public generator form — same public endpoint the
  /// customer app uses; no auth involved.
  Future<Result<List<StoreRef>, AppFailure>> stores() async {
    try {
      final res = await _dio.get<dynamic>('/stores');
      final status = res.statusCode ?? 0;
      final body = res.data;
      if (status >= 400) return Result.failure(_failureOf(status, body));
      final data = body is Map<String, dynamic> ? body['data'] : body;
      return Result.success(
        (data as List).whereType<Map<String, dynamic>>().map(StoreRef.fromJson).toList(),
      );
    } on DioException catch (e) {
      return Result.failure(NetworkFailure(cause: e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  /// Employee self-service link generator. The access code travels in the
  /// POST body only; the returned raw link exists exactly once.
  Future<Result<MsCreateResult, AppFailure>> createAssignment({
    required String requesterName,
    required String accessCode,
    required String storeId,
    required String idempotencyKey,
    String? employeeCode,
    int? ttlDays,
    String? note,
  }) async {
    try {
      final res = await _dio.post<dynamic>('/internal/ms/public/create-assignment', data: {
        'requesterName': requesterName,
        'accessCode': accessCode,
        'storeId': storeId,
        'idempotencyKey': idempotencyKey,
        if (employeeCode != null && employeeCode.isNotEmpty) 'employeeCode': employeeCode,
        if (ttlDays != null) 'ttlDays': ttlDays,
        if (note != null && note.isNotEmpty) 'note': note,
      },);
      final status = res.statusCode ?? 0;
      final body = res.data;
      if (status >= 400) return Result.failure(_failureOf(status, body));
      final data = body is Map<String, dynamic> ? body['data'] : body;
      return Result.success(MsCreateResult.fromJson(data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response != null) {
        return Result.failure(_failureOf(e.response!.statusCode ?? 0, e.response!.data));
      }
      return Result.failure(NetworkFailure(cause: e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  AppFailure _failureOf(int status, dynamic body) {
    var code = 'HTTP_$status';
    String? message;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        code = (err['code'] as String?) ?? code;
        message = err['message'] as String?;
      }
    }
    return ServerFailure(code: code, message: message);
  }

  // The public dine-in survey client lives in `banan_features_shared`
  // (`SurveyPublicApi`) — the guest form is served on the CUSTOMER domain.

  Future<Result<MsPublicView, AppFailure>> view(String token) =>
      _post('/internal/ms/public/view', {'token': token});

  Future<Result<MsPublicView, AppFailure>> save(String token, Map<String, dynamic> body) =>
      _post('/internal/ms/public/save', {'token': token, ...body});

  Future<Result<MsPublicView, AppFailure>> submit(String token) =>
      _post('/internal/ms/public/submit', {'token': token});

  Future<Result<MsPublicView, AppFailure>> removeEvidence(String token, String evidenceId) =>
      _post('/internal/ms/public/remove-evidence', {'token': token, 'evidenceId': evidenceId});

  /// Bytes of one of the shopper's OWN evidence photos — POST so the token
  /// stays out of logged URLs; rendered with Image.memory.
  Future<Result<Uint8List, AppFailure>> fileBytes(String token, String name) async {
    try {
      final res = await _dio.post<List<int>>(
        '/internal/ms/public/file',
        data: {'token': token, 'name': name},
        options: Options(responseType: ResponseType.bytes),
      );
      final status = res.statusCode ?? 0;
      if (status >= 400 || res.data == null) {
        return Result.failure(ServerFailure(code: 'HTTP_$status'));
      }
      return Result.success(Uint8List.fromList(res.data!));
    } on DioException catch (e) {
      return Result.failure(NetworkFailure(cause: e));
    }
  }

  Future<Result<MsPublicView, AppFailure>> upload({
    required String token,
    required String kind,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    String? questionId,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/internal/ms/public/upload',
        data: FormData.fromMap({
          'token': token,
          'kind': kind,
          if (questionId != null) 'questionId': questionId,
          'file': MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: DioMediaType.parse(mimeType),
          ),
        }),
      );
      return _handle(res);
    } on DioException catch (e) {
      return Result.failure(NetworkFailure(cause: e));
    }
  }

  Future<Result<MsPublicView, AppFailure>> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<dynamic>(path, data: body);
      return _handle(res);
    } on DioException catch (e) {
      return Result.failure(NetworkFailure(cause: e));
    } catch (e) {
      return Result.failure(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  Result<MsPublicView, AppFailure> _handle(Response<dynamic> res) {
    final status = res.statusCode ?? 0;
    final body = res.data;
    if (status >= 400) {
      var code = 'HTTP_$status';
      String? message;
      List<dynamic>? details;
      if (body is Map<String, dynamic>) {
        final err = body['error'];
        if (err is Map<String, dynamic>) {
          code = (err['code'] as String?) ?? code;
          message = err['message'] as String?;
          details = err['details'] as List<dynamic>?;
        }
      }
      return Result.failure(
        ServerFailure(code: code, message: message, cause: details),
      );
    }
    final data = body is Map<String, dynamic> ? body['data'] : body;
    return Result.success(MsPublicView.fromJson(data as Map<String, dynamic>));
  }
}

final internalApiProvider = Provider<InternalApi>((ref) {
  return InternalApi(ref.watch(dioProvider));
});

final internalPublicApiProvider = Provider<InternalPublicApi>((ref) {
  return InternalPublicApi(createDioClient());
});
