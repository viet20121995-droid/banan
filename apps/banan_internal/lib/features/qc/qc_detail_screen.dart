import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/internal_shell.dart';
import '../../shared/private_image.dart';
import '../../shared/save_file.dart';
import '../../shared/widgets.dart';

/// One QC inspection: header, per-section marking form, RISK block, live
/// result panel, complete / reopen / PDF. A COMPLETED inspection is
/// read-only until "Mở lại".
class QcDetailScreen extends ConsumerStatefulWidget {
  const QcDetailScreen({required this.inspectionId, super.key});
  final String inspectionId;

  @override
  ConsumerState<QcDetailScreen> createState() => _QcDetailScreenState();
}

class _QcDetailScreenState extends ConsumerState<QcDetailScreen> {
  Result<QcInspectionDetail, AppFailure>? _state;
  QcResultView? _result;
  final Map<String, GlobalKey> _itemKeys = {};
  bool _busy = false;

  InternalApi get _api => ref.read(internalApiProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = null);
    final res = await _api.qcDetail(widget.inspectionId);
    if (!mounted) return;
    setState(() => _state = res);
    if (res.isSuccess) await _refreshResult();
  }

  Future<void> _refreshResult() async {
    final res = await _api.qcResult(widget.inspectionId);
    if (mounted) setState(() => _result = res.valueOrNull);
  }

  void _apply(Result<QcInspectionDetail, AppFailure> res) {
    res.when(
      success: (d) => setState(() => _state = Result.success(d)),
      failure: (f) => showFailure(context, f),
    );
    _refreshResult();
  }

  // ── mutations ──
  Future<void> _answer(QcItemView item, String value, {String? failDetail, String? naReason}) async {
    _apply(
      await _api.qcAnswer(
        widget.inspectionId,
        item.id,
        value: value,
        failDetail: failDetail ?? item.failDetail,
        naReason: naReason ?? item.naReason,
      ),
    );
  }

  Future<void> _risk(QcItemView item, {required bool occurred, String? detail}) async {
    _apply(
      await _api.qcRisk(
        widget.inspectionId,
        item.id,
        occurred: occurred,
        detail: detail ?? item.detail,
      ),
    );
  }

  Future<void> _addPhoto(QcItemView item) async {
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
    final up = await _api.uploadImage(bytes: file.bytes!, filename: file.name, mimeType: mime);
    if (!mounted) return;
    await up.when(
      success: (f) async => _apply(await _api.qcAttachEvidence(widget.inspectionId, item.id, f)),
      failure: (f) async => showFailure(context, f),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _removePhoto(EvidenceRef ev) async {
    _apply(await _api.qcRemoveEvidence(widget.inspectionId, ev.id));
  }

  /// Client-side mirror of the server's completion rules — finds the first
  /// invalid item so we can scroll straight to it.
  String? _firstInvalidItemId(QcInspectionDetail d) {
    for (final s in d.sections) {
      for (final it in s.items) {
        if (s.isRisk) {
          if (it.occurred == null) return it.id;
          if ((it.occurred ?? false) &&
              ((it.detail ?? '').isEmpty || it.evidence.isEmpty)) {
            return it.id;
          }
        } else {
          if (it.value == null) return it.id;
          if (it.value == 'FAIL' &&
              ((it.failDetail ?? '').isEmpty || it.evidence.isEmpty)) {
            return it.id;
          }
          if (it.value == 'NOT_AVAILABLE' && (it.naReason ?? '').isEmpty) return it.id;
        }
      }
    }
    return null;
  }

  Future<void> _complete(QcInspectionDetail d) async {
    final invalid = _firstInvalidItemId(d);
    if (invalid != null) {
      showSnack(context, 'Còn mục chưa hợp lệ — đã cuộn tới mục cần bổ sung.');
      final key = _itemKeys[invalid];
      if (key?.currentContext != null) {
        await Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
        );
      }
      return;
    }
    final riskOccurred = d.sections
        .where((s) => s.isRisk)
        .expand((s) => s.items)
        .any((it) => it.occurred ?? false);
    final ok = await confirmDialog(
      context,
      title: riskOccurred ? '⚠ CÓ RISK — CRITICAL FAIL' : 'Hoàn tất kiểm tra?',
      message: riskOccurred
          ? 'Có ít nhất một RISK xảy ra: toàn bộ checklist sẽ bị CRITICAL FAIL và '
              'email cảnh báo được gửi ngay cho vận hành. Tiếp tục hoàn tất?'
          : 'Kết quả sẽ được chốt (bản ${d.revision + 1}) và gửi email báo cáo '
              'cho vận hành. Sau khi hoàn tất, muốn sửa phải dùng "Mở lại".',
      confirmLabel: 'Hoàn tất & gửi',
      danger: riskOccurred,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final res = await _api.qcComplete(widget.inspectionId);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (detail) {
        setState(() => _state = Result.success(detail));
        showSnack(context, 'Đã hoàn tất — báo cáo đang được gửi email.');
        _refreshResult();
      },
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _reopen() async {
    final ok = await confirmDialog(
      context,
      title: 'Mở lại phiên kiểm tra?',
      message: 'Kết quả hiện tại được giữ nguyên cho tới khi bạn hoàn tất lại. '
          'Bản hoàn tất mới sẽ tạo revision mới và gửi email "Kết quả QC đã cập nhật".',
      confirmLabel: 'Mở lại',
    );
    if (!ok || !mounted) return;
    _apply(await _api.qcReopen(widget.inspectionId));
  }

  Future<void> _downloadPdf(QcInspectionDetail d) async {
    setState(() => _busy = true);
    final res = await _api.qcPdf(widget.inspectionId);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (bytes) {
        // Mirrors the server: only a COMPLETED inspection downloads as the
        // approved r-N report; anything else is a watermarked draft.
        final name = d.status == 'COMPLETED'
            ? '${d.code}-r${d.revision}.pdf'
            : '${d.code}-nhap.pdf';
        saveBytesAsFile(bytes, name, 'application/pdf');
        showSnack(
          context,
          d.status == 'COMPLETED' ? 'Đã tải PDF.' : 'Đã tải bản nháp (có watermark).',
        );
      },
      failure: (f) => showFailure(context, f),
    );
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    final detail = _state?.valueOrNull;
    return InternalShell(
      title: 'Phiên kiểm tra QC',
      subtitle: detail == null
          ? null
          : '${detail.store.name} · ${vnDate.format(detail.inspectionDate.toLocal())}',
      actions: [
        if (detail != null)
          IconButton(
            tooltip: 'Tải PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _busy ? null : () => _downloadPdf(detail),
          ),
      ],
      body: FetchBody<QcInspectionDetail>(
        state: _state,
        onRetry: _load,
        builder: (d) {
          final locked = d.status == 'COMPLETED';
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(BananSpacing.lg),
                children: [
                  _header(d, locked),
                  const SizedBox(height: BananSpacing.lg),
                  if (_result != null) _resultPanel(d, _result!),
                  const SizedBox(height: BananSpacing.lg),
                  for (final section in d.sections) ...[
                    _sectionBlock(d, section, locked),
                    const SizedBox(height: BananSpacing.lg),
                  ],
                  if (!locked)
                    PrimaryButton(
                      label: 'Hoàn tất & gửi báo cáo',
                      icon: Icons.task_alt,
                      loading: _busy,
                      onPressed: () => _complete(d),
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('Mở lại để chỉnh sửa (tạo bản mới)'),
                      onPressed: _reopen,
                    ),
                  const SizedBox(height: BananSpacing.huge),
                ],
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
        },
      ),
    );
  }

  Widget _header(QcInspectionDetail d, bool locked) {
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(d.code, style: Theme.of(context).textTheme.titleMedium),
              StatusBadge(label: qcStatusLabel(d.status), intent: qcStatusIntent(d.status), dense: true),
              if (d.revision > 0) Text('bản ${d.revision}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: BananSpacing.md),
          Wrap(
            spacing: BananSpacing.xl,
            runSpacing: BananSpacing.sm,
            children: [
              _headerField(
                'Thời gian bắt đầu',
                d.startedAt == null ? '—' : vnTime.format(d.startedAt!.toLocal()),
                locked ? null : () => _pickTime(d, isStart: true),
              ),
              _headerField(
                'Thời gian kết thúc',
                d.endedAt == null ? '—' : vnTime.format(d.endedAt!.toLocal()),
                locked ? null : () => _pickTime(d, isStart: false),
              ),
              _headerField('Người kiểm tra', d.inspectorName,
                  locked ? null : () => _editText(d, 'inspectorName', 'Người kiểm tra', d.inspectorName),),
              _headerField('Nhân viên trong ca', d.staffOnShift ?? '—',
                  locked ? null : () => _editText(d, 'staffOnShift', 'Nhân viên trong ca', d.staffOnShift),),
              _headerField('Ghi chú chung', d.generalNotes ?? '—',
                  locked ? null : () => _editText(d, 'generalNotes', 'Ghi chú chung', d.generalNotes),),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerField(String label, String value, VoidCallback? onEdit) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BananRadii.rsm,
      child: Padding(
        padding: const EdgeInsets.all(BananSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
                if (onEdit != null) const Icon(Icons.edit_outlined, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(QcInspectionDetail d, {required bool isStart}) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked == null || !mounted) return;
    final local = d.inspectionDate.toLocal();
    final at = DateTime(local.year, local.month, local.day, picked.hour, picked.minute);
    _apply(
      await _api.qcUpdateHeader(widget.inspectionId, {
        if (isStart) 'startedAt': at.toUtc().toIso8601String(),
        if (!isStart) 'endedAt': at.toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> _editText(
    QcInspectionDetail d,
    String field,
    String label,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(controller: controller, maxLines: 3, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _apply(await _api.qcUpdateHeader(widget.inspectionId, {field: controller.text.trim()}));
  }

  Widget _resultPanel(QcInspectionDetail d, QcResultView r) {
    final color = switch (r.outcome) {
      'PASS' => BananColors.success,
      'FAIL' => BananColors.warning,
      _ => BananColors.danger,
    };
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BananRadii.rmd,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: BananSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(label: qcOutcomeLabel(r.outcome), intent: qcOutcomeIntent(r.outcome)),
              Text(
                r.overallPercent == null
                    ? 'Chưa có câu trả lời'
                    : 'Tổng: ${r.overallPass}/${r.overallApplicable} · ${r.overallPercent}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (d.status != 'COMPLETED')
                Text('(xem trước — chưa chốt)', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (r.riskOccurred) ...[
            const SizedBox(height: BananSpacing.sm),
            const Text(
              '⚠ CÓ RISK XẢY RA — toàn bộ checklist bị CRITICAL FAIL.',
              style: TextStyle(color: BananColors.danger, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: BananSpacing.md),
          Wrap(
            spacing: BananSpacing.md,
            runSpacing: BananSpacing.xs,
            children: [
              for (final s in r.sections)
                Text(
                  '${s.title}: ${s.percent == null ? 'N/A' : '${s.passCount}/${s.applicable} · ${s.percent}%'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: s.belowThreshold ? BananColors.danger : null,
                        fontWeight: s.belowThreshold ? FontWeight.w700 : null,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionBlock(QcInspectionDetail d, QcSectionView section, bool locked) {
    return Container(
      padding: const EdgeInsets.all(BananSpacing.lg),
      decoration: BoxDecoration(
        color: section.isRisk
            ? BananColors.danger.withValues(alpha: 0.04)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BananRadii.rmd,
        border: Border.all(
          color: section.isRisk
              ? BananColors.danger.withValues(alpha: 0.5)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.isRisk ? '⚠ ${section.title} — lỗi nghiêm trọng' : section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: section.isRisk ? BananColors.danger : BananColors.primary,
                ),
          ),
          if (section.isRisk)
            Padding(
              padding: const EdgeInsets.only(top: BananSpacing.xs),
              child: Text(
                'Bị 1 trong ${section.items.length} lỗi RISK sẽ fail toàn bộ checklist.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BananColors.danger),
              ),
            ),
          const SizedBox(height: BananSpacing.md),
          for (final item in section.items) ...[
            _itemRow(d, section, item, locked),
            if (item != section.items.last) const Divider(height: BananSpacing.xl),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(QcInspectionDetail d, QcSectionView section, QcItemView item, bool locked) {
    final key = _itemKeys.putIfAbsent(item.id, GlobalKey.new);
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${item.no}. ${item.text}'),
        const SizedBox(height: BananSpacing.sm),
        if (section.isRisk)
          _riskControls(item, locked)
        else
          _answerControls(item, locked),
        if (item.evidence.isNotEmpty) ...[
          const SizedBox(height: BananSpacing.sm),
          Wrap(
            spacing: BananSpacing.sm,
            runSpacing: BananSpacing.sm,
            children: [
              for (final ev in item.evidence)
                Stack(
                  children: [
                    PrivateImage(name: ev.url),
                    if (!locked)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _removePhoto(ev),
                          child: const ColoredBox(
                            color: Colors.black54,
                            child: Icon(Icons.close, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _answerControls(QcItemView item, bool locked) {
    final needsDetail = item.value == 'FAIL';
    final needsReason = item.value == 'NOT_AVAILABLE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: BananSpacing.sm,
          runSpacing: BananSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PASS', label: Text('Đạt')),
                ButtonSegment(value: 'FAIL', label: Text('Không đạt')),
                ButtonSegment(value: 'NOT_AVAILABLE', label: Text('N/A')),
              ],
              selected: {if (item.value != null) item.value!},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: locked
                  ? null
                  : (sel) {
                      if (sel.isEmpty) return;
                      final value = sel.first;
                      if (value == 'NOT_AVAILABLE') {
                        _promptText(
                          'Lý do N/A (bắt buộc)',
                          item.naReason,
                          (reason) => _answer(item, value, naReason: reason),
                          requireText: true,
                        );
                      } else {
                        _answer(item, value);
                      }
                    },
            ),
            if (!locked && item.value == 'FAIL')
              OutlinedButton.icon(
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(item.evidence.isEmpty ? 'Thêm ảnh (bắt buộc)' : 'Thêm ảnh'),
                onPressed: () => _addPhoto(item),
              ),
            if (!locked && item.value != 'FAIL' && item.value != null)
              TextButton.icon(
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Ảnh'),
                onPressed: () => _addPhoto(item),
              ),
          ],
        ),
        if (needsDetail)
          Padding(
            padding: const EdgeInsets.only(top: BananSpacing.sm),
            child: _inlineText(
              label: 'Chi tiết lỗi (bắt buộc)',
              value: item.failDetail,
              enabled: !locked,
              onSubmit: (text) => _answer(item, 'FAIL', failDetail: text),
              error: (item.failDetail ?? '').isEmpty,
            ),
          ),
        if (needsReason)
          Padding(
            padding: const EdgeInsets.only(top: BananSpacing.sm),
            child: _inlineText(
              label: 'Lý do N/A (bắt buộc)',
              value: item.naReason,
              enabled: !locked,
              onSubmit: (text) => _answer(item, 'NOT_AVAILABLE', naReason: text),
              error: (item.naReason ?? '').isEmpty,
            ),
          ),
      ],
    );
  }

  Widget _riskControls(QcItemView item, bool locked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: BananSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Không')),
                ButtonSegment(value: true, label: Text('CÓ — xảy ra')),
              ],
              selected: {if (item.occurred != null) item.occurred!},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    item.occurred ?? false ? BananColors.danger.withValues(alpha: 0.15) : null,
              ),
              onSelectionChanged: locked
                  ? null
                  : (sel) {
                      if (sel.isEmpty) return;
                      final occurred = sel.first;
                      if (occurred) {
                        _promptText(
                          'Chi tiết RISK (bắt buộc)',
                          item.detail,
                          (detail) => _risk(item, occurred: true, detail: detail),
                          requireText: true,
                        );
                      } else {
                        _risk(item, occurred: false);
                      }
                    },
            ),
            if (!locked && (item.occurred ?? false))
              OutlinedButton.icon(
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(item.evidence.isEmpty ? 'Ảnh bằng chứng (bắt buộc)' : 'Thêm ảnh'),
                onPressed: () => _addPhoto(item),
              ),
          ],
        ),
        if (item.occurred ?? false)
          Padding(
            padding: const EdgeInsets.only(top: BananSpacing.sm),
            child: _inlineText(
              label: 'Chi tiết RISK (bắt buộc)',
              value: item.detail,
              enabled: !locked,
              onSubmit: (text) => _risk(item, occurred: true, detail: text),
              error: (item.detail ?? '').isEmpty,
            ),
          ),
      ],
    );
  }

  Widget _inlineText({
    required String label,
    required String? value,
    required bool enabled,
    required ValueChanged<String> onSubmit,
    bool error = false,
  }) {
    return InkWell(
      onTap: enabled ? () => _promptText(label, value, onSubmit, requireText: true) : null,
      borderRadius: BananRadii.rsm,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BananSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BananRadii.rsm,
          border: Border.all(color: error ? BananColors.danger : Theme.of(context).dividerColor),
        ),
        child: Text(
          (value ?? '').isEmpty ? label : value!,
          style: (value ?? '').isEmpty
              ? TextStyle(color: error ? BananColors.danger : Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }

  Future<void> _promptText(
    String label,
    String? current,
    ValueChanged<String> onSubmit, {
    bool requireText = false,
  }) async {
    final controller = TextEditingController(text: current ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nhập nội dung…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              if (requireText && controller.text.trim().isEmpty) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok ?? false) onSubmit(controller.text.trim());
  }
}
