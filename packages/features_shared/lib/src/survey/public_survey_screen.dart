import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'survey_draft.dart';
import 'survey_flow.dart';
import 'survey_public_api.dart';
import 'survey_public_models.dart';
import 'survey_storage.dart';

const _draftKey = 'banan_survey_draft';
const _browserKeyKey = 'banan_survey_bk';

/// Where the in-progress draft lives. The default is per-tab sessionStorage
/// (back/refresh keeps the answers); tests inject an in-memory store.
class SurveyDraftStore {
  const SurveyDraftStore();
  String? read() => readSurveySessionValue(_draftKey);
  void write(String value) => writeSurveySessionValue(_draftKey, value);
  void clear() => removeSurveySessionValue(_draftKey);
}

class MemorySurveyDraftStore implements SurveyDraftStore {
  MemorySurveyDraftStore();
  String? value;
  @override
  String? read() => value;
  @override
  void write(String v) => value = v;
  @override
  void clear() => value = null;
}

/// Public guest survey behind the ONE fixed link
/// (`<customer domain>/survey`) — mobile-first, no login, branch picked on
/// the form itself (never inferred from the QR).
class PublicSurveyScreen extends ConsumerStatefulWidget {
  const PublicSurveyScreen({super.key, this.draftStore = const SurveyDraftStore()});
  final SurveyDraftStore draftStore;

  @override
  ConsumerState<PublicSurveyScreen> createState() => _PublicSurveyScreenState();
}

class _PublicSurveyScreenState extends ConsumerState<PublicSurveyScreen> {
  Result<SurveyPublicInfo, AppFailure>? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _info = null);
    final res = await ref.read(surveyPublicApiProvider).surveyInfo();
    if (mounted) setState(() => _info = res);
  }

  /// Stable anonymous per-browser key (reward daily cap). No key when
  /// storage is blocked — feedback still works, just no gift.
  String? _browserKey() {
    final existing = readSurveyLocalValue(_browserKeyKey);
    if (existing != null && existing.length >= 8) return existing;
    final fresh = newSurveyKey();
    writeSurveyLocalValue(_browserKeyKey, fresh);
    return readSurveyLocalValue(_browserKeyKey);
  }

  Future<Result<SurveySubmitResult, AppFailure>> _submit(
    SurveyTemplateView template,
    SurveyDraft draft,
  ) async {
    final byCode = {for (final q in template.questions) q.code: q};
    final answers = <Map<String, dynamic>>[];
    void add(String code, Map<String, dynamic> value) {
      final q = byCode[code];
      if (q != null) answers.add({'questionId': q.id, ...value});
    }

    draft.numbers.forEach((code, v) => add(code, {'numberValue': v}));
    draft.choices.forEach((code, v) => add(code, {'optionValues': v}));
    draft.texts.forEach((code, v) => add(code, {'textValue': v}));

    final wantsContact = draft.numbers['contact_request'] == 1 && draft.contactConsent;
    final res = await ref.read(surveyPublicApiProvider).surveySubmit({
      'templateId': template.id,
      'storeId': draft.storeId,
      'clientRequestId': draft.clientRequestId,
      'locale': draft.locale,
      if (_browserKey() != null) 'browserKey': _browserKey(),
      'answers': answers,
      if (wantsContact)
        'contact': {
          if (draft.contactName.trim().isNotEmpty) 'name': draft.contactName.trim(),
          if (draft.contactPhone.trim().isNotEmpty) 'phone': draft.contactPhone.trim(),
          'consent': true,
        },
    });
    if (res.isSuccess) widget.draftStore.clear();
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(BananSpacing.lg),
              child: _body(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final info = _info;
    if (info == null) return const Center(child: CircularProgressIndicator());
    return info.when(
      failure: (_) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chưa tải được khảo sát — kiểm tra kết nối mạng.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BananSpacing.md),
            OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      ),
      success: (data) {
        final template = data.template;
        if (template == null) {
          return Center(
            child: Text(
              'Khảo sát đang được chuẩn bị — quay lại sau nhé!',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          );
        }
        final saved = widget.draftStore.read();
        return SurveyFlow(
          template: template,
          stores: data.stores,
          reward: data.reward,
          initialDraft: saved != null ? SurveyDraft.fromJsonString(saved) : null,
          onDraftChanged: (d) => widget.draftStore.write(d.toJsonString()),
          onSubmit: (d) => _submit(template, d),
        );
      },
    );
  }
}
