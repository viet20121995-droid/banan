import 'package:banan_core/banan_core.dart';
import 'package:banan_features_shared/banan_features_shared.dart';

/// Public survey API stub — records every submit body so tests assert on the
/// exact wire shape (question ids, idempotency key, contact consent).
class FakeSurveyPublicApi implements SurveyPublicApi {
  FakeSurveyPublicApi({
    Result<SurveyPublicInfo, AppFailure>? surveyInfoResult,
    Result<SurveySubmitResult, AppFailure>? surveySubmitResult,
  })  : surveyInfoResult = surveyInfoResult ??
            Result.success(SurveyPublicInfo.fromJson(surveyPublicInfoJson())),
        surveySubmitResult =
            surveySubmitResult ?? const Result.success(SurveySubmitResult(id: 'resp1'));

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
}

/// The real seed question shape (codes + conditional rules), two branches.
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
