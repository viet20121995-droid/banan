import 'dart:async';

import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/private_image.dart';
import '../../shared/widgets.dart';

/// Public Mystery Shopper form — opened from the secret link on a phone.
/// No login; the token authorises everything. Mobile-first single column,
/// autosaves as the shopper types, hard validation before submit.
class MsFormScreen extends ConsumerStatefulWidget {
  const MsFormScreen({required this.token, super.key});
  final String token;

  @override
  ConsumerState<MsFormScreen> createState() => _MsFormScreenState();
}

class _MsFormScreenState extends ConsumerState<MsFormScreen> {
  Result<MsPublicView, AppFailure>? _state;
  final Map<String, GlobalKey> _questionKeys = {};
  final Map<String, TextEditingController> _notes = {};
  Timer? _saveDebounce;
  final Map<String, dynamic> _pendingSave = {};
  bool _busy = false;
  bool _saving = false;

  InternalPublicApi get _api => ref.read(internalPublicApiProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    // No stashed token (fresh tab on /f, or storage blocked after the URL
    // was stripped) — the link itself must be reopened.
    if (widget.token.isEmpty) {
      setState(
        () => _state = const Result.failure(ServerFailure(code: 'INTERNAL_MS_LINK_INVALID')),
      );
      return;
    }
    setState(() => _state = null);
    final res = await _api.view(widget.token);
    if (mounted) setState(() => _state = res);
  }

  MsPublicView? get _view => _state?.valueOrNull;

  bool get _editable =>
      _view != null && ['ASSIGNED', 'OPENED', 'NEEDS_REVISION'].contains(_view!.status);

  /// Queues a field for the debounced autosave.
  void _queueSave(Map<String, dynamic> patch) {
    _pendingSave.addAll(patch);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _flushSave);
  }

  Future<void> _flushSave() async {
    if (_pendingSave.isEmpty || !_editable) return;
    final patch = Map<String, dynamic>.from(_pendingSave);
    _pendingSave.clear();
    setState(() => _saving = true);
    final res = await _api.save(widget.token, patch);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (v) => setState(() => _state = Result.success(v)),
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _saveAnswer(String questionId, {String? value, String? note}) async {
    _queueSave({
      'answers': [
        ..._collectPendingAnswers(questionId, value: value, note: note),
      ],
    });
  }

  List<Map<String, dynamic>> _collectPendingAnswers(
    String questionId, {
    String? value,
    String? note,
  }) {
    final existingAnswers =
        (_pendingSave['answers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final current = _view?.submission?.answerFor(questionId);
    final merged = {
      'questionId': questionId,
      'value': value ?? current?.value,
      'note': note ?? _notes[questionId]?.text ?? current?.note,
    }..removeWhere((k, v) => v == null);
    return [
      ...existingAnswers.where((a) => a['questionId'] != questionId),
      merged,
    ];
  }

  Future<void> _uploadEvidence({required String kind, String? questionId}) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.firstOrNull;
    if (file?.bytes == null || !mounted) return;
    final ext = (file!.extension ?? 'jpg').toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    setState(() => _busy = true);
    final res = await _api.upload(
      token: widget.token,
      kind: kind,
      questionId: questionId,
      bytes: file.bytes!,
      filename: file.name,
      mimeType: mime,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (v) => setState(() => _state = Result.success(v)),
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _removeEvidence(EvidenceRef ev) async {
    final res = await _api.removeEvidence(widget.token, ev.id);
    if (!mounted) return;
    res.when(
      success: (v) => setState(() => _state = Result.success(v)),
      failure: (f) => showFailure(context, f),
    );
  }

  /// First invalid question (mirrors server rules) for scroll-to-error.
  String? _firstInvalid(MsPublicView v) {
    final s = v.submission;
    for (final section in v.sections) {
      for (final q in section.questions) {
        final a = s?.answerFor(q.id);
        if (section.kind == 'CRITICAL') {
          if (a?.value != 'YES' && a?.value != 'NO') return q.id;
          if (a?.value == 'YES' && (a?.note ?? '').isEmpty) return q.id;
        } else {
          if (a?.value == null) return q.id;
          if (a?.value == 'NOT_AVAILABLE' && (a?.note ?? '').isEmpty) return q.id;
        }
      }
    }
    return null;
  }

  Future<void> _submit() async {
    await _flushSave();
    if (!mounted) return;
    final v = _view;
    if (v == null) return;
    final invalid = _firstInvalid(v);
    final receipts = (v.submission?.evidence ?? []).where((e) => e.kind == 'RECEIPT');
    final products = (v.submission?.evidence ?? []).where((e) => e.kind == 'PRODUCT');
    if (invalid != null || receipts.isEmpty || products.isEmpty) {
      var message = 'Còn câu chưa trả lời hoặc thiếu ghi chú — đã cuộn tới câu cần bổ sung.';
      if (invalid == null && receipts.isEmpty) message = 'Bạn cần tải ảnh HÓA ĐƠN trước khi gửi.';
      if (invalid == null && receipts.isNotEmpty && products.isEmpty) {
        message = 'Bạn cần tải ảnh SẢN PHẨM trước khi gửi.';
      }
      showSnack(context, message);
      final key = invalid != null ? _questionKeys[invalid] : null;
      if (key?.currentContext != null) {
        await Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
        );
      }
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Gửi bài kiểm tra?',
      message: 'Sau khi gửi, bạn không sửa được nữa (trừ khi Banan yêu cầu bổ sung). '
          'Kiểm tra lại ảnh hóa đơn và các câu trả lời trước khi gửi.',
      confirmLabel: 'Gửi bài',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final res = await _api.submit(widget.token);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (view) => setState(() => _state = Result.success(view)),
      failure: (f) => showFailure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      appBar: AppBar(
        title: const Text('Banan · Phiếu kiểm tra trải nghiệm'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: BananSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final s = _state;
    if (s == null) return const Center(child: CircularProgressIndicator());
    return s.when(
      success: _form,
      failure: _linkProblem,
    );
  }

  Widget _linkProblem(AppFailure f) {
    final (icon, title, message) = switch (f.code) {
      'INTERNAL_MS_LINK_EXPIRED' => (
          Icons.timer_off_outlined,
          'Link đã hết hạn',
          'Liên hệ người gửi để nhận link mới.',
        ),
      'INTERNAL_MS_LINK_REVOKED' => (
          Icons.block,
          'Link đã bị thu hồi',
          'Nhiệm vụ này không còn hiệu lực.',
        ),
      'INTERNAL_MS_LINK_INVALID' => (
          Icons.link_off,
          'Link không hợp lệ',
          'Kiểm tra lại đường dẫn được gửi cho bạn.',
        ),
      _ => (Icons.wifi_off, 'Không tải được', f.message ?? 'Thử lại sau.'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BananSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).hintColor),
            const SizedBox(height: BananSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: BananSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: BananSpacing.lg),
            OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _form(MsPublicView v) {
    if (v.status == 'SUBMITTED' || v.status == 'APPROVED') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: BananColors.success),
              const SizedBox(height: BananSpacing.md),
              Text('Đã nộp bài — cảm ơn bạn!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: BananSpacing.sm),
              Text(
                'Bài kiểm tra ${v.code} tại ${v.storeName} đã được ghi nhận'
                '${v.submission?.submittedAt != null ? ' lúc ${vnDateTime.format(v.submission!.submittedAt!.toLocal())}' : ''}. '
                'Nếu cần bổ sung, Banan sẽ liên hệ và link này sẽ mở lại.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final sub = v.submission;
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(BananSpacing.lg),
              children: [
                if (v.status == 'NEEDS_REVISION')
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: BananSpacing.md),
                    padding: const EdgeInsets.all(BananSpacing.md),
                    decoration: BoxDecoration(
                      color: BananColors.warning.withValues(alpha: 0.1),
                      borderRadius: BananRadii.rmd,
                      border: Border.all(color: BananColors.warning),
                    ),
                    child: Text(
                      'Banan cần bạn bổ sung:\n${v.revisionNote ?? 'Xem lại các mục và gửi lại.'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                _briefCard(v),
                const SizedBox(height: BananSpacing.lg),
                _factsCard(v, sub),
                const SizedBox(height: BananSpacing.lg),
                _evidenceCard(v, sub),
                const SizedBox(height: BananSpacing.lg),
                for (final section in v.sections) ...[
                  _sectionCard(v, section, sub),
                  const SizedBox(height: BananSpacing.lg),
                ],
                _commentCard(sub),
                const SizedBox(height: BananSpacing.lg),
                PrimaryButton(
                  label: 'Gửi bài kiểm tra',
                  icon: Icons.send,
                  loading: _busy,
                  onPressed: _editable ? _submit : null,
                ),
                const SizedBox(height: BananSpacing.huge),
              ],
            ),
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BananSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BananRadii.rmd,
          border: Border.all(color: Colors.black12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _briefCard(MsPublicView v) => _card(
        children: [
          Text('Nhiệm vụ ${v.code} · ${v.storeName}',
              style: Theme.of(context).textTheme.titleMedium,),
          const SizedBox(height: BananSpacing.sm),
          if (v.scenario != null) Text('Tình huống: ${v.scenario}'),
          if (v.productsToBuy != null) Text('Cần mua: ${v.productsToBuy}'),
          if (v.budgetVnd != null) Text('Ngân sách: ${vnd.format(v.budgetVnd)}'),
          if (v.deadline != null)
            Text('Hạn nộp: ${vnDateTime.format(v.deadline!.toLocal())}'),
          if (v.brief != null) ...[
            const SizedBox(height: BananSpacing.sm),
            Text(v.brief!),
          ],
          const SizedBox(height: BananSpacing.sm),
          Text(
            'Trả lời từng câu bên dưới. Bài tự lưu khi bạn nhập — có thể đóng và mở lại link.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );

  Widget _factsCard(MsPublicView v, MsSubmissionView? sub) {
    final times = [
      ('enteredAt', 'Giờ bước vào', sub?.enteredAt),
      ('greetedAt', 'Giờ được chào', sub?.greetedAt),
      ('orderStartAt', 'Giờ bắt đầu đặt', sub?.orderStartAt),
      ('paidAt', 'Giờ thanh toán', sub?.paidAt),
      ('receivedAt', 'Giờ nhận món', sub?.receivedAt),
    ];
    return _card(
      children: [
        Text('Thông tin thực tế', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: BananSpacing.sm),
        Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.sm,
          children: [
            for (final (field, label, value) in times)
              OutlinedButton(
                onPressed: _editable
                    ? () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked == null) return;
                        final now = DateTime.now();
                        final at = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          picked.hour,
                          picked.minute,
                        );
                        _queueSave({field: at.toUtc().toIso8601String()});
                        unawaited(_flushSave());
                      }
                    : null,
                child: Text('$label: ${value == null ? '—' : vnTime.format(value.toLocal())}'),
              ),
          ],
        ),
        const SizedBox(height: BananSpacing.sm),
        TextFormField(
          initialValue: sub?.productsBought ?? '',
          enabled: _editable,
          decoration: const InputDecoration(labelText: 'Sản phẩm đã mua'),
          onChanged: (v) => _queueSave({'productsBought': v}),
        ),
        TextFormField(
          initialValue: sub?.amountPaidVnd?.toString() ?? '',
          enabled: _editable,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Giá thực trả (₫)'),
          onChanged: (v) {
            final n = int.tryParse(v.replaceAll(RegExp(r'\D'), ''));
            if (n != null) _queueSave({'amountPaidVnd': n});
          },
        ),
        TextFormField(
          initialValue: sub?.staffName ?? '',
          enabled: _editable,
          decoration: const InputDecoration(
            labelText: 'Tên nhân viên (CHỈ khi thấy bảng tên — không cần đoán)',
          ),
          onChanged: (v) => _queueSave({'staffName': v}),
        ),
      ],
    );
  }

  Widget _evidenceCard(MsPublicView v, MsSubmissionView? sub) {
    final groups = [
      ('RECEIPT', 'Ảnh hóa đơn (bắt buộc)', true),
      ('PRODUCT', 'Ảnh sản phẩm (bắt buộc)', true),
      ('PACKAGING', 'Ảnh bao bì (nếu mang đi)', false),
    ];
    return _card(
      children: [
        Text('Ảnh bằng chứng', style: Theme.of(context).textTheme.titleMedium),
        for (final (kind, label, required) in groups) ...[
          const SizedBox(height: BananSpacing.sm),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: required &&
                        (sub?.evidence.where((e) => e.kind == kind).isEmpty ?? true)
                    ? BananColors.danger
                    : null,
              ),),
          const SizedBox(height: BananSpacing.xs),
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              for (final ev in (sub?.evidence ?? []).where((e) => e.kind == kind))
                Stack(
                  children: [
                    PublicEvidenceImage(token: widget.token, name: ev.url, size: 88),
                    if (_editable)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _removeEvidence(ev),
                          child: const ColoredBox(
                            color: Colors.black54,
                            child: Icon(Icons.close, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              if (_editable)
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Tải ảnh'),
                  onPressed: () => _uploadEvidence(kind: kind),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sectionCard(MsPublicView v, MsSectionView section, MsSubmissionView? sub) {
    final isCritical = section.kind == 'CRITICAL';
    return _card(
      children: [
        Text(
          isCritical
              ? '⚠ ${section.title}'
              : '${section.code}. ${section.title}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isCritical ? BananColors.danger : BananColors.primary,
              ),
        ),
        if (isCritical)
          Padding(
            padding: const EdgeInsets.only(top: BananSpacing.xs),
            child: Text(
              'Chỉ chọn "Có" khi thực sự xảy ra — cần mô tả rõ và kèm ảnh nếu có thể.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BananColors.danger),
            ),
          ),
        const SizedBox(height: BananSpacing.sm),
        for (final q in section.questions) _questionRow(section, q, sub),
      ],
    );
  }

  Widget _questionRow(MsSectionView section, MsQuestionView q, MsSubmissionView? sub) {
    final key = _questionKeys.putIfAbsent(q.id, GlobalKey.new);
    final a = sub?.answerFor(q.id);
    final isCritical = section.kind == 'CRITICAL';
    final noteController = _notes.putIfAbsent(q.id, () {
      final c = TextEditingController(text: a?.note ?? '');
      c.addListener(() => _saveAnswer(q.id, note: c.text));
      return c;
    });
    final needsNote = (isCritical && a?.value == 'YES') ||
        (!isCritical && a?.value == 'NOT_AVAILABLE');
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: BananSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.text),
          const SizedBox(height: BananSpacing.xs),
          SegmentedButton<String>(
            segments: isCritical
                ? const [
                    ButtonSegment(value: 'NO', label: Text('Không')),
                    ButtonSegment(value: 'YES', label: Text('CÓ — vi phạm')),
                  ]
                : [
                    const ButtonSegment(value: 'YES', label: Text('Đạt')),
                    const ButtonSegment(value: 'NO', label: Text('Không đạt')),
                    if (q.allowNa)
                      const ButtonSegment(value: 'NOT_AVAILABLE', label: Text('N/A')),
                  ],
            selected: {if (a?.value != null) a!.value!},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: _editable
                ? (sel) {
                    if (sel.isEmpty) return;
                    _saveAnswer(q.id, value: sel.first);
                    unawaited(_flushSave());
                  }
                : null,
          ),
          if (needsNote || (a?.note ?? '').isNotEmpty || a?.value == 'NO')
            Padding(
              padding: const EdgeInsets.only(top: BananSpacing.xs),
              child: TextField(
                controller: noteController,
                enabled: _editable,
                maxLines: 2,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: needsNote
                      ? (isCritical ? 'Mô tả vi phạm (bắt buộc)' : 'Lý do N/A (bắt buộc)')
                      : 'Ghi chú',
                  errorText:
                      needsNote && noteController.text.trim().isEmpty ? 'Bắt buộc nhập' : null,
                ),
              ),
            ),
          if (_editable && (a?.value == 'NO' || (isCritical && a?.value == 'YES')))
            Padding(
              padding: const EdgeInsets.only(top: BananSpacing.xs),
              child: TextButton.icon(
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('Thêm ảnh cho câu này'),
                onPressed: () => _uploadEvidence(kind: 'ANSWER', questionId: q.id),
              ),
            ),
          if (a != null && a.evidence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: BananSpacing.xs),
              child: Wrap(
                spacing: BananSpacing.xs,
                children: [
                  for (final ev in a.evidence)
                    Stack(
                      children: [
                        PublicEvidenceImage(token: widget.token, name: ev.url, size: 64),
                        if (_editable)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => _removeEvidence(ev),
                              child: const ColoredBox(
                                color: Colors.black54,
                                child: Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _commentCard(MsSubmissionView? sub) => _card(
        children: [
          Text('Đánh giá tổng quan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: BananSpacing.sm),
          TextFormField(
            initialValue: sub?.overallComment ?? '',
            enabled: _editable,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Điều làm tốt nhất / điều cần cải thiện nhất, nhận xét tự do',
            ),
            onChanged: (v) => _queueSave({'overallComment': v}),
          ),
        ],
      );
}
