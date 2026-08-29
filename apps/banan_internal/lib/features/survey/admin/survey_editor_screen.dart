import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:banan_features_shared/banan_features_shared.dart' show SurveyFlow;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/internal_api.dart';
import '../../../data/survey_models.dart';
import '../../../shared/internal_shell.dart';
import '../../../shared/widgets.dart';

/// Survey template editor: versioned templates (DRAFT → PUBLISHED →
/// ARCHIVED), published versions immutable (clone to edit), mobile preview
/// through the REAL guest flow widget before publishing.
class SurveyEditorScreen extends ConsumerStatefulWidget {
  const SurveyEditorScreen({super.key});

  @override
  ConsumerState<SurveyEditorScreen> createState() => _SurveyEditorScreenState();
}

class _SurveyEditorScreenState extends ConsumerState<SurveyEditorScreen> {
  Result<List<SurveyTemplateListItem>, AppFailure>? _templates;
  SurveyTemplateView? _selected;
  List<SurveyQuestionView> _draftQuestions = [];
  bool _dirty = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? selectId}) async {
    setState(() => _templates = null);
    final res = await ref.read(internalApiProvider).surveyTemplates();
    if (!mounted) return;
    setState(() => _templates = res);
    final id = selectId ?? _selected?.id;
    res.when(
      success: (list) {
        if (id != null && list.any((t) => t.id == id)) {
          _select(id);
        } else if (_selected == null && list.isNotEmpty) {
          _select(list.first.id);
        }
      },
      failure: (_) {},
    );
  }

  Future<void> _select(String id) async {
    final res = await ref.read(internalApiProvider).surveyTemplateDetail(id);
    if (!mounted) return;
    res.when(
      success: (t) => setState(() {
        _selected = t;
        _draftQuestions = List.of(t.questions);
        _dirty = false;
      }),
      failure: (f) => showFailure(context, f),
    );
  }

  bool get _editable => _selected?.status == 'DRAFT';

  Future<void> _run(
    Future<Result<dynamic, AppFailure>> Function(InternalApi api) op, {
    String? doneMessage,
    String? selectId,
  }) async {
    setState(() => _busy = true);
    final res = await op(ref.read(internalApiProvider));
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (_) {
        if (doneMessage != null) showSnack(context, doneMessage);
        _load(selectId: selectId);
      },
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _save() async {
    final t = _selected;
    if (t == null) return;
    await _run(
      (api) =>
          api.surveyReplaceQuestions(t.id, _draftQuestions.map((q) => q.toJson()).toList()),
      doneMessage: 'Đã lưu câu hỏi.',
      selectId: t.id,
    );
  }

  Future<void> _publish() async {
    final t = _selected;
    if (t == null) return;
    if (_dirty) {
      showSnack(context, 'Lưu câu hỏi trước khi publish.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Publish bản v${t.version}?',
      message: 'Bản này trở thành khảo sát đang chạy và KHÔNG thể sửa nữa '
          '(muốn sửa phải nhân bản thành bản nháp mới). Bản đang chạy hiện tại '
          'sẽ được lưu trữ.',
      confirmLabel: 'Publish',
    );
    if (!ok) return;
    await _run((api) => api.surveyPublishTemplate(t.id),
        doneMessage: 'Đã publish.', selectId: t.id,);
  }

  void _preview() {
    final t = _selected;
    if (t == null) return;
    final previewTemplate = SurveyTemplateView(
      id: t.id,
      name: t.name,
      version: t.version,
      questions: _draftQuestions,
    );
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 390,
          height: 700,
          child: Padding(
            padding: const EdgeInsets.all(BananSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Xem thử trên điện thoại',
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: SurveyFlow(
                    template: previewTemplate,
                    stores: const [
                      SurveyStoreRef(id: 'p1', name: 'Banan – Chi nhánh mẫu', address: 'Địa chỉ mẫu'),
                    ],
                    preview: true,
                    onSubmit: (_) async =>
                        const Result.failure(ServerFailure(code: 'PREVIEW')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InternalShell(
      title: 'Trình soạn khảo sát',
      subtitle: 'Phiên bản, câu hỏi và điều kiện hiển thị',
      body: FetchBody<List<SurveyTemplateListItem>>(
        state: _templates,
        onRetry: _load,
        builder: (templates) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          final list = _templateList(templates);
          final detail = _detailPane();
          if (!wide) {
            return ListView(
              padding: const EdgeInsets.all(BananSpacing.lg),
              children: [list, const SizedBox(height: BananSpacing.lg), detail],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  child: list,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(BananSpacing.lg),
                  child: detail,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _templateList(List<SurveyTemplateListItem> templates) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Bản nháp mới từ bản đang chọn'),
          onPressed: _busy || _selected == null
              ? null
              : () => _run(
                    (api) => api.surveyCreateTemplate(cloneFromId: _selected!.id),
                    doneMessage: 'Đã tạo bản nháp.',
                  ),
        ),
        const SizedBox(height: BananSpacing.md),
        for (final t in templates)
          Card(
            margin: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: ListTile(
              selected: _selected?.id == t.id,
              title: Text('v${t.version} · ${t.name}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,),
              subtitle: Wrap(
                spacing: BananSpacing.xs,
                runSpacing: BananSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    label: _statusLabel(t.status),
                    intent: switch (t.status) {
                      'PUBLISHED' => StatusIntent.success,
                      'DRAFT' => StatusIntent.progress,
                      _ => StatusIntent.neutral,
                    },
                    dense: true,
                  ),
                  if (t.isDefault)
                    const StatusBadge(label: 'Đang chạy', intent: StatusIntent.info, dense: true),
                  Text('${t.questionCount} câu · ${t.responseCount} phản hồi',
                      style: theme.textTheme.labelSmall,),
                ],
              ),
              onTap: () => _select(t.id),
            ),
          ),
      ],
    );
  }

  String _statusLabel(String status) => switch (status) {
        'DRAFT' => 'Nháp',
        'PUBLISHED' => 'Đã publish',
        'ARCHIVED' => 'Lưu trữ',
        _ => status,
      };

  Widget _detailPane() {
    final t = _selected;
    if (t == null) return const Text('Chọn một phiên bản.');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('v${t.version} · ${t.name}', style: theme.textTheme.titleMedium),
            OutlinedButton.icon(
              icon: const Icon(Icons.smartphone, size: 18),
              label: const Text('Xem thử'),
              onPressed: _preview,
            ),
            if (_editable) ...[
              FilledButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Lưu câu hỏi'),
                onPressed: _busy || !_dirty ? null : _save,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.publish_outlined, size: 18),
                label: const Text('Publish'),
                onPressed: _busy ? null : _publish,
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Xóa bản nháp?',
                          message: 'Chỉ bản nháp chưa có phản hồi mới xóa được.',
                          confirmLabel: 'Xóa',
                          danger: true,
                        );
                        if (!ok) return;
                        setState(() => _selected = null);
                        await _run((api) => api.surveyDeleteTemplate(t.id),
                            doneMessage: 'Đã xóa bản nháp.',);
                      },
                child: const Text('Xóa nháp'),
              ),
            ] else ...[
              const StatusBadge(
                label: 'Bản đã publish là bất biến — nhân bản để sửa',
                intent: StatusIntent.info,
              ),
              if (!t.isDefault && t.status == 'PUBLISHED')
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run((api) => api.surveyArchiveTemplate(t.id),
                          doneMessage: 'Đã lưu trữ.', selectId: t.id,),
                  child: const Text('Lưu trữ'),
                ),
            ],
          ],
        ),
        const SizedBox(height: BananSpacing.lg),
        for (var i = 0; i < _draftQuestions.length; i++) _questionTile(i),
        if (_editable)
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm câu hỏi'),
            onPressed: () => _editQuestion(null),
          ),
      ],
    );
  }

  Widget _questionTile(int index) {
    final q = _draftQuestions[index];
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: BananSpacing.sm),
      child: ListTile(
        title: Text(q.textVi, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            q.code,
            _typeLabel(q.type),
            if (q.required) 'bắt buộc',
            if (q.showIfQuestionCode != null)
              'hiện khi ${q.showIfQuestionCode} ${q.showIfOp} ${q.showIfValue}',
            if (q.options.isNotEmpty) '${q.options.length} lựa chọn',
          ].join(' · '),
          style: theme.textTheme.labelSmall,
        ),
        trailing: !_editable
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Lên',
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: index == 0 ? null : () => _move(index, -1),
                  ),
                  IconButton(
                    tooltip: 'Xuống',
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed:
                        index == _draftQuestions.length - 1 ? null : () => _move(index, 1),
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => setState(() {
                      _draftQuestions.removeAt(index);
                      _dirty = true;
                    }),
                  ),
                ],
              ),
        onTap: _editable ? () => _editQuestion(index) : null,
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'EMOJI_SCALE' => 'Cảm xúc 1–5',
        'RATING' => 'Sao 1–5',
        'NPS' => 'NPS 0–10',
        'SINGLE_CHOICE' => 'Chọn một',
        'MULTI_CHOICE' => 'Chọn nhiều',
        'TEXT' => 'Tự luận',
        'YES_NO' => 'Có / Không',
        _ => type,
      };

  void _move(int index, int delta) {
    setState(() {
      final q = _draftQuestions.removeAt(index);
      _draftQuestions.insert(index + delta, q);
      _dirty = true;
    });
  }

  Future<void> _editQuestion(int? index) async {
    final existing = index != null ? _draftQuestions[index] : null;
    final result = await showDialog<SurveyQuestionView>(
      context: context,
      builder: (context) => _QuestionDialog(question: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _draftQuestions[index] = result;
      } else {
        _draftQuestions.add(result);
      }
      _dirty = true;
    });
  }
}

/// Question editor: type, VI/EN texts, required, conditional display and the
/// VI/EN options (one per line: `value | nhãn VI | label EN`).
class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({this.question});
  final SurveyQuestionView? question;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final TextEditingController _code =
      TextEditingController(text: widget.question?.code ?? '');
  late final TextEditingController _textVi =
      TextEditingController(text: widget.question?.textVi ?? '');
  late final TextEditingController _textEn =
      TextEditingController(text: widget.question?.textEn ?? '');
  late final TextEditingController _showIfCode =
      TextEditingController(text: widget.question?.showIfQuestionCode ?? '');
  late final TextEditingController _showIfValue =
      TextEditingController(text: widget.question?.showIfValue?.toString() ?? '');
  late final TextEditingController _options = TextEditingController(
    text: widget.question?.options
            .map((o) => '${o.value} | ${o.labelVi} | ${o.labelEn}')
            .join('\n') ??
        '',
  );
  late String _type = widget.question?.type ?? 'RATING';
  late bool _required = widget.question?.required ?? false;
  late String? _showIfOp = widget.question?.showIfOp;
  String? _error;

  bool get _isChoice => _type == 'SINGLE_CHOICE' || _type == 'MULTI_CHOICE';

  @override
  void dispose() {
    _code.dispose();
    _textVi.dispose();
    _textEn.dispose();
    _showIfCode.dispose();
    _showIfValue.dispose();
    _options.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _code.text.trim();
    if (!RegExp(r'^[\w-]{1,50}$').hasMatch(code)) {
      setState(() => _error = 'Mã câu hỏi: chữ/số/gạch, tối đa 50 ký tự.');
      return;
    }
    if (_textVi.text.trim().isEmpty || _textEn.text.trim().isEmpty) {
      setState(() => _error = 'Cần nội dung cả tiếng Việt và tiếng Anh.');
      return;
    }
    final options = <SurveyOptionView>[];
    if (_isChoice) {
      for (final line in _options.text.split('\n')) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|').map((p) => p.trim()).toList();
        if (parts.length < 2 || parts[0].isEmpty) {
          setState(() => _error = 'Lựa chọn sai định dạng: "$line" '
              '(cần: ma | nhãn VI | label EN)',);
          return;
        }
        options.add(SurveyOptionView(
          value: parts[0],
          labelVi: parts[1],
          labelEn: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : parts[1],
        ),);
      }
      if (options.isEmpty) {
        setState(() => _error = 'Câu hỏi lựa chọn cần ít nhất một lựa chọn.');
        return;
      }
    }
    final hasCondition = _showIfCode.text.trim().isNotEmpty;
    if (hasCondition && (_showIfOp == null || int.tryParse(_showIfValue.text) == null)) {
      setState(() => _error = 'Điều kiện hiển thị cần đủ phép so sánh và giá trị.');
      return;
    }
    Navigator.of(context).pop(SurveyQuestionView(
      id: widget.question?.id ?? 'new-$code',
      code: code,
      type: _type,
      textVi: _textVi.text.trim(),
      textEn: _textEn.text.trim(),
      required: _required,
      maxLength: _type == 'TEXT' ? (widget.question?.maxLength ?? 1000) : null,
      showIfQuestionCode: hasCondition ? _showIfCode.text.trim() : null,
      showIfOp: hasCondition ? _showIfOp : null,
      showIfValue: hasCondition ? int.parse(_showIfValue.text) : null,
      options: options,
    ),);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.question == null ? 'Thêm câu hỏi' : 'Sửa câu hỏi'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Mã câu hỏi (ổn định, vd: overall)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Loại',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'EMOJI_SCALE', child: Text('Cảm xúc 1–5')),
                  DropdownMenuItem(value: 'RATING', child: Text('Sao 1–5')),
                  DropdownMenuItem(value: 'NPS', child: Text('NPS 0–10')),
                  DropdownMenuItem(value: 'SINGLE_CHOICE', child: Text('Chọn một')),
                  DropdownMenuItem(value: 'MULTI_CHOICE', child: Text('Chọn nhiều')),
                  DropdownMenuItem(value: 'TEXT', child: Text('Tự luận')),
                  DropdownMenuItem(value: 'YES_NO', child: Text('Có / Không')),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: BananSpacing.md),
              TextField(
                controller: _textVi,
                decoration: const InputDecoration(
                  labelText: 'Câu hỏi (tiếng Việt)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              TextField(
                controller: _textEn,
                decoration: const InputDecoration(
                  labelText: 'Question (English)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              SwitchListTile(
                value: _required,
                contentPadding: EdgeInsets.zero,
                title: const Text('Bắt buộc trả lời'),
                onChanged: (v) => setState(() => _required = v),
              ),
              if (_isChoice) ...[
                const SizedBox(height: BananSpacing.md),
                TextField(
                  controller: _options,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Lựa chọn — mỗi dòng: ma | nhãn VI | label EN',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: BananSpacing.md),
              Text('Điều kiện hiển thị (bỏ trống = luôn hiện)',
                  style: Theme.of(context).textTheme.labelMedium,),
              const SizedBox(height: BananSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _showIfCode,
                      decoration: const InputDecoration(
                        labelText: 'Mã câu hỏi',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  DropdownButton<String?>(
                    value: _showIfOp,
                    hint: const Text('Phép'),
                    items: const [
                      DropdownMenuItem(value: 'LTE', child: Text('≤')),
                      DropdownMenuItem(value: 'GTE', child: Text('≥')),
                      DropdownMenuItem(value: 'EQ', child: Text('=')),
                    ],
                    onChanged: (v) => setState(() => _showIfOp = v),
                  ),
                  const SizedBox(width: BananSpacing.sm),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _showIfValue,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá trị',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: BananSpacing.md),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Xong')),
      ],
    );
  }
}
