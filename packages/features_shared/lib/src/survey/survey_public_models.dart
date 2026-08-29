/// View models for the PUBLIC dine-in survey (guest form) plus the template
/// shapes the internal editor shares with it. Hand-written `fromJson`
/// mirroring the backend view shapes 1:1. Admin-only models (reports, cases,
/// rewards) stay in the internal app — nothing here needs a session.
library;

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;
String? _s(dynamic v) => v is String && v.isNotEmpty ? v : null;
int _i(dynamic v) => v is num ? v.toInt() : 0;
int? _iq(dynamic v) => v is num ? v.toInt() : null;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

// ── template ────────────────────────────────────────────────────────────────

class SurveyOptionView {
  const SurveyOptionView({
    required this.value,
    required this.labelVi,
    required this.labelEn,
  });
  factory SurveyOptionView.fromJson(Map<String, dynamic> json) => SurveyOptionView(
        value: json['value'] as String,
        labelVi: (json['labelVi'] as String?) ?? '',
        labelEn: (json['labelEn'] as String?) ?? '',
      );
  final String value;
  final String labelVi;
  final String labelEn;

  String label(String locale) => locale == 'en' ? labelEn : labelVi;

  Map<String, dynamic> toJson() => {'value': value, 'labelVi': labelVi, 'labelEn': labelEn};
}

class SurveyQuestionView {
  const SurveyQuestionView({
    required this.id,
    required this.code,
    required this.type,
    required this.textVi,
    required this.textEn,
    required this.required,
    this.maxLength,
    this.showIfQuestionCode,
    this.showIfOp,
    this.showIfValue,
    this.options = const [],
  });
  factory SurveyQuestionView.fromJson(Map<String, dynamic> json) => SurveyQuestionView(
        id: json['id'] as String,
        code: json['code'] as String,
        type: json['type'] as String,
        textVi: (json['textVi'] as String?) ?? '',
        textEn: (json['textEn'] as String?) ?? '',
        required: json['required'] == true,
        maxLength: _iq(json['maxLength']),
        showIfQuestionCode: _s(json['showIfQuestionCode']),
        showIfOp: _s(json['showIfOp']),
        showIfValue: _iq(json['showIfValue']),
        options: _list(json['options']).map(SurveyOptionView.fromJson).toList(),
      );
  final String id;
  final String code;
  final String type;
  final String textVi;
  final String textEn;
  final bool required;
  final int? maxLength;
  final String? showIfQuestionCode;
  final String? showIfOp;
  final int? showIfValue;
  final List<SurveyOptionView> options;

  String text(String locale) => locale == 'en' ? textEn : textVi;

  /// Mirror of the server rule — the form only shows what the server accepts.
  bool visibleFor(Map<String, int> numericByCode) {
    if (showIfQuestionCode == null || showIfOp == null || showIfValue == null) {
      return true;
    }
    final answered = numericByCode[showIfQuestionCode];
    if (answered == null) return false;
    return switch (showIfOp) {
      'LTE' => answered <= showIfValue!,
      'GTE' => answered >= showIfValue!,
      'EQ' => answered == showIfValue!,
      _ => false,
    };
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'type': type,
        'textVi': textVi,
        'textEn': textEn,
        'required': required,
        if (maxLength != null) 'maxLength': maxLength,
        if (showIfQuestionCode != null) 'showIfQuestionCode': showIfQuestionCode,
        if (showIfOp != null) 'showIfOp': showIfOp,
        if (showIfValue != null) 'showIfValue': showIfValue,
        if (options.isNotEmpty) 'options': options.map((o) => o.toJson()).toList(),
      };
}

class SurveyTemplateView {
  const SurveyTemplateView({
    required this.id,
    required this.name,
    required this.version,
    this.status,
    this.isDefault = false,
    this.questions = const [],
  });
  factory SurveyTemplateView.fromJson(Map<String, dynamic> json) => SurveyTemplateView(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        version: _i(json['version']),
        status: _s(json['status']),
        isDefault: json['isDefault'] == true,
        questions: _list(json['questions']).map(SurveyQuestionView.fromJson).toList(),
      );
  final String id;
  final String name;
  final int version;
  final String? status;
  final bool isDefault;
  final List<SurveyQuestionView> questions;
}

// ── public payload ──────────────────────────────────────────────────────────

class SurveyRewardTeaser {
  const SurveyRewardTeaser({required this.name, this.description});
  factory SurveyRewardTeaser.fromJson(Map<String, dynamic> json) => SurveyRewardTeaser(
        name: (json['name'] as String?) ?? '',
        description: _s(json['description']),
      );
  final String name;
  final String? description;
}

class SurveyPublicInfo {
  const SurveyPublicInfo({this.template, this.stores = const [], this.reward});
  factory SurveyPublicInfo.fromJson(Map<String, dynamic> json) => SurveyPublicInfo(
        template: json['template'] is Map<String, dynamic>
            ? SurveyTemplateView.fromJson(json['template'] as Map<String, dynamic>)
            : null,
        stores: _list(json['stores']).map(SurveyStoreRef.fromJson).toList(),
        reward: json['reward'] is Map<String, dynamic>
            ? SurveyRewardTeaser.fromJson(json['reward'] as Map<String, dynamic>)
            : null,
      );
  final SurveyTemplateView? template;
  final List<SurveyStoreRef> stores;
  final SurveyRewardTeaser? reward;
}

class SurveyStoreRef {
  const SurveyStoreRef({required this.id, required this.name, this.address});
  factory SurveyStoreRef.fromJson(Map<String, dynamic> json) => SurveyStoreRef(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '?',
        address: _s(json['address']),
      );
  final String id;
  final String name;
  final String? address;
}

class SurveySubmitResult {
  const SurveySubmitResult({required this.id, this.reward});
  factory SurveySubmitResult.fromJson(Map<String, dynamic> json) => SurveySubmitResult(
        id: json['id'] as String,
        reward: json['reward'] is Map<String, dynamic>
            ? SurveyRewardWin.fromJson(json['reward'] as Map<String, dynamic>)
            : null,
      );
  final String id;
  final SurveyRewardWin? reward;
}

class SurveyRewardWin {
  const SurveyRewardWin({
    required this.mode,
    required this.name,
    this.description,
    this.instructions,
    this.voucherCode,
    this.expiresAt,
  });
  factory SurveyRewardWin.fromJson(Map<String, dynamic> json) => SurveyRewardWin(
        mode: (json['mode'] as String?) ?? 'MESSAGE_ONLY',
        name: (json['name'] as String?) ?? '',
        description: _s(json['description']),
        instructions: _s(json['instructions']),
        voucherCode: _s(json['voucherCode']),
        expiresAt: _date(json['expiresAt']),
      );
  final String mode;
  final String name;
  final String? description;
  final String? instructions;
  final String? voucherCode;
  final DateTime? expiresAt;
}
