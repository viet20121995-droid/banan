import 'dart:convert';
import 'dart:math';

/// The guest's in-progress answers. Serializable so the public screen can
/// keep it in sessionStorage across back/refresh in the same tab.
class SurveyDraft {
  SurveyDraft({
    this.storeId,
    Map<String, int>? numbers,
    Map<String, List<String>>? choices,
    Map<String, String>? texts,
    this.contactName = '',
    this.contactPhone = '',
    this.contactConsent = false,
    this.step = 0,
    this.locale = 'vi',
    String? clientRequestId,
  })  : numbers = numbers ?? {},
        choices = choices ?? {},
        texts = texts ?? {},
        clientRequestId = clientRequestId ?? newSurveyKey();

  factory SurveyDraft.fromJsonString(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SurveyDraft(
        storeId: json['storeId'] as String?,
        numbers: (json['numbers'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        choices: (json['choices'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as List).cast<String>())),
        texts: (json['texts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        contactName: (json['contactName'] as String?) ?? '',
        contactPhone: (json['contactPhone'] as String?) ?? '',
        contactConsent: json['contactConsent'] == true,
        step: (json['step'] as num?)?.toInt() ?? 0,
        locale: (json['locale'] as String?) == 'en' ? 'en' : 'vi',
        clientRequestId: json['clientRequestId'] as String?,
      );
    } catch (_) {
      return SurveyDraft();
    }
  }

  String? storeId;

  /// By question CODE — codes are stable across template loads, ids are not.
  final Map<String, int> numbers;
  final Map<String, List<String>> choices;
  final Map<String, String> texts;
  String contactName;
  String contactPhone;
  bool contactConsent;
  int step;

  /// 'vi' | 'en' — what the guest actually answered in.
  String locale;
  final String clientRequestId;

  String toJsonString() => jsonEncode({
        'storeId': storeId,
        'numbers': numbers,
        'choices': choices,
        'texts': texts,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'contactConsent': contactConsent,
        'step': step,
        'locale': locale,
        'clientRequestId': clientRequestId,
      });
}

/// Random url-safe key (idempotency + anonymous browser key).
String newSurveyKey() {
  final rng = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
}
