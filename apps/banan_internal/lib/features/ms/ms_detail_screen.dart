import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/internal_shell.dart';
import '../../shared/private_image.dart';
import '../../shared/save_file.dart';
import '../../shared/widgets.dart';

/// One MS assignment: brief editor, secret-link management, submission
/// review, request-revision / approve, PDF download.
class MsDetailScreen extends ConsumerStatefulWidget {
  const MsDetailScreen({required this.assignmentId, super.key});
  final String assignmentId;

  @override
  ConsumerState<MsDetailScreen> createState() => _MsDetailScreenState();
}

class _MsDetailScreenState extends ConsumerState<MsDetailScreen> {
  Result<MsAssignmentDetail, AppFailure>? _state;
  MsResultView? _result;
  bool _busy = false;

  InternalApi get _api => ref.read(internalApiProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = null);
    final res = await _api.msDetail(widget.assignmentId);
    if (!mounted) return;
    setState(() => _state = res);
    final d = res.valueOrNull;
    if (d != null && d.submission != null) {
      final r = await _api.msResult(widget.assignmentId);
      if (mounted) setState(() => _result = r.valueOrNull);
    }
  }

  void _apply(Result<MsAssignmentDetail, AppFailure> res) {
    res.when(
      success: (d) => setState(() => _state = Result.success(d)),
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _issueToken(MsAssignmentDetail d) async {
    final ok = await confirmDialog(
      context,
      title: d.tokens.any((t) => t.revokedAt == null) ? 'Tạo link mới?' : 'Tạo link bí mật?',
      message: 'Link cũ (nếu có) sẽ bị vô hiệu. Link mới hiển thị MỘT Lần duy nhất — '
          'sao chép và gửi riêng cho người thực hiện.',
      confirmLabel: 'Tạo link',
    );
    if (!ok || !mounted) return;
    final res = await _api.msIssueToken(widget.assignmentId);
    if (!mounted) return;
    await res.when(
      success: (issued) async {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Link bí mật (hiển thị 1 lần)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(issued.url),
                const SizedBox(height: BananSpacing.sm),
                Text(
                  'Hết hạn: ${vnDateTime.format(issued.expiresAt.toLocal())}. '
                  'Không gửi link này qua kênh công khai.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Sao chép'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: issued.url));
                  if (context.mounted) showSnack(context, 'Đã sao chép link.');
                },
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Xong'),
              ),
            ],
          ),
        );
        await _load();
      },
      failure: (f) async => showFailure(context, f),
    );
  }

  Future<void> _revoke() async {
    final ok = await confirmDialog(
      context,
      title: 'Thu hồi nhiệm vụ?',
      message: 'Link bí mật sẽ vô hiệu ngay và nhiệm vụ chuyển sang "Đã thu hồi". Không thể hoàn tác.',
      confirmLabel: 'Thu hồi',
      danger: true,
    );
    if (!ok || !mounted) return;
    _apply(await _api.msRevoke(widget.assignmentId));
  }

  Future<void> _requestRevision() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu bổ sung'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ghi rõ cần bổ sung gì (người thực hiện sẽ thấy nội dung này)…',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _apply(await _api.msRequestRevision(widget.assignmentId, controller.text.trim()));
  }

  Future<void> _approve(MsAssignmentDetail d) async {
    final critical = _result?.criticalFail ?? false;
    final ok = await confirmDialog(
      context,
      title: critical ? '⚠ Duyệt kết quả CRITICAL FAIL?' : 'Duyệt kết quả?',
      message: 'Sau khi duyệt, điểm được chốt (bản ${d.approvedRevision + 1}) và báo cáo '
          'được gửi email ngay cho vận hành + CEO. ${critical ? 'Kết quả là CRITICAL FAIL.' : ''}',
      confirmLabel: 'Duyệt & gửi',
      danger: critical,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final res = await _api.msApprove(widget.assignmentId);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (detail) {
        setState(() => _state = Result.success(detail));
        showSnack(context, 'Đã duyệt — báo cáo đang được gửi email.');
      },
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _downloadPdf(MsAssignmentDetail d) async {
    setState(() => _busy = true);
    final res = await _api.msPdf(widget.assignmentId);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (bytes) {
        // Mirrors the server: only an APPROVED assignment downloads as the
        // approved r-N report; anything else is a watermarked draft.
        final name = d.status == 'APPROVED'
            ? '${d.code}-r${d.approvedRevision}.pdf'
            : '${d.code}-nhap.pdf';
        saveBytesAsFile(bytes, name, 'application/pdf');
        showSnack(
          context,
          d.status == 'APPROVED' ? 'Đã tải PDF.' : 'Đã tải bản nháp (có watermark).',
        );
      },
      failure: (f) => showFailure(context, f),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _state?.valueOrNull;
    return InternalShell(
      title: 'Nhiệm vụ Mystery Shopper',
      subtitle: detail == null ? null : '${detail.code} · ${detail.store.name}',
      actions: [
        if (detail != null && detail.submission != null)
          IconButton(
            tooltip: 'Tải PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _busy ? null : () => _downloadPdf(detail),
          ),
      ],
      body: FetchBody<MsAssignmentDetail>(
        state: _state,
        onRetry: _load,
        builder: (d) => Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(BananSpacing.lg),
              children: [
                _statusHeader(d),
                const SizedBox(height: BananSpacing.lg),
                _briefBlock(d),
                const SizedBox(height: BananSpacing.lg),
                _tokenBlock(d),
                if (d.submission != null) ...[
                  const SizedBox(height: BananSpacing.lg),
                  if (_result != null) _resultBlock(d, _result!),
                  const SizedBox(height: BananSpacing.lg),
                  _submissionBlock(d),
                ],
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
        ),
      ),
    );
  }

  Widget _card({required Widget child, Color? borderColor}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(BananSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BananRadii.rmd,
          border: Border.all(color: borderColor ?? Theme.of(context).dividerColor),
        ),
        child: child,
      );

  Widget _statusHeader(MsAssignmentDetail d) {
    return _card(
      child: Wrap(
        spacing: BananSpacing.md,
        runSpacing: BananSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusBadge(label: msStatusLabel(d.status), intent: msStatusIntent(d.status)),
          if (d.firstOpenedAt != null)
            Text('Mở link lần đầu: ${vnDateTime.format(d.firstOpenedAt!.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,),
          if (d.approvedRevision > 0)
            Text('Đã duyệt bản ${d.approvedRevision}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: BananSpacing.md),
          if (d.status == 'SUBMITTED') ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Yêu cầu bổ sung'),
              onPressed: _requestRevision,
            ),
            PrimaryButton(
              label: 'Duyệt & gửi báo cáo',
              icon: Icons.task_alt,
              onPressed: () => _approve(d),
            ),
          ],
          if (!['APPROVED', 'REVOKED'].contains(d.status))
            TextButton.icon(
              icon: const Icon(Icons.block, size: 18),
              label: const Text('Thu hồi'),
              style: TextButton.styleFrom(foregroundColor: BananColors.danger),
              onPressed: _revoke,
            ),
        ],
      ),
    );
  }

  Widget _briefBlock(MsAssignmentDetail d) {
    final editable = ['DRAFT', 'ASSIGNED', 'OPENED', 'NEEDS_REVISION'].contains(d.status);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Nội dung nhiệm vụ', style: Theme.of(context).textTheme.titleMedium),
              ),
              if (editable)
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Sửa'),
                  onPressed: () => _editBrief(d),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Nhân bản'),
                onPressed: () async {
                  final res = await _api.msCopy(widget.assignmentId);
                  if (!mounted) return;
                  res.when(
                    success: (copy) => showSnack(context, 'Đã tạo bản nháp ${copy.code}.'),
                    failure: (f) => showFailure(context, f),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          _kv('Khoảng thực hiện', [
            if (d.windowStart != null) vnDateTime.format(d.windowStart!.toLocal()),
            if (d.windowEnd != null) vnDateTime.format(d.windowEnd!.toLocal()),
          ].join(' – '),),
          _kv('Tình huống', d.scenario ?? '—'),
          _kv('Sản phẩm cần mua', d.productsToBuy ?? '—'),
          _kv('Ngân sách', d.budgetVnd == null ? '—' : vnd.format(d.budgetVnd)),
          _kv('Hạn nộp', d.deadline == null ? '—' : vnDateTime.format(d.deadline!.toLocal())),
          _kv('Brief', d.brief ?? '—'),
          const Divider(height: BananSpacing.xl),
          Text('Ghi chú nội bộ (chỉ admin thấy)', style: Theme.of(context).textTheme.bodySmall),
          Text(d.internalNotes ?? '—'),
          if (d.revisionNote != null) ...[
            const SizedBox(height: BananSpacing.sm),
            Text('Đang chờ bổ sung: ${d.revisionNote}',
                style: const TextStyle(color: BananColors.warning, fontWeight: FontWeight.w600),),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(child: Text(value.isEmpty ? '—' : value)),
          ],
        ),
      );

  Future<void> _editBrief(MsAssignmentDetail d) async {
    final scenario = TextEditingController(text: d.scenario ?? '');
    final products = TextEditingController(text: d.productsToBuy ?? '');
    final budget = TextEditingController(text: d.budgetVnd?.toString() ?? '');
    final brief = TextEditingController(text: d.brief ?? '');
    final notes = TextEditingController(text: d.internalNotes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa nhiệm vụ'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: scenario, decoration: const InputDecoration(labelText: 'Tình huống cần kiểm tra')),
                TextField(controller: products, decoration: const InputDecoration(labelText: 'Sản phẩm/món cần mua')),
                TextField(
                  controller: budget,
                  decoration: const InputDecoration(labelText: 'Ngân sách (₫)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(controller: brief, maxLines: 3, decoration: const InputDecoration(labelText: 'Brief riêng')),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Ghi chú nội bộ')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _apply(
      await _api.msUpdate(widget.assignmentId, {
        'scenario': scenario.text.trim(),
        'productsToBuy': products.text.trim(),
        if (int.tryParse(budget.text.trim()) != null) 'budgetVnd': int.parse(budget.text.trim()),
        'brief': brief.text.trim(),
        'internalNotes': notes.text.trim(),
      }),
    );
  }

  Widget _tokenBlock(MsAssignmentDetail d) {
    final active = d.tokens.where((t) => t.revokedAt == null).toList();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Link bí mật', style: Theme.of(context).textTheme.titleMedium)),
              if (!['APPROVED', 'REVOKED'].contains(d.status))
                OutlinedButton.icon(
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(active.isEmpty ? 'Tạo link' : 'Tạo link mới'),
                  onPressed: () => _issueToken(d),
                ),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          if (d.tokens.isEmpty)
            Text('Chưa tạo link. Người thực hiện cần link bí mật để mở form trên điện thoại.',
                style: Theme.of(context).textTheme.bodySmall,)
          else
            for (final t in d.tokens.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'Tạo ${vnDateTime.format(t.createdAt.toLocal())} · hết hạn ${vnDateTime.format(t.expiresAt.toLocal())}'
                  '${t.revokedAt != null ? ' · ĐÃ THU HỒI' : t.expiresAt.isBefore(DateTime.now()) ? ' · HẾT HẠN' : ' · đang hiệu lực'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          Text(
            'Vì bảo mật, link chỉ hiển thị một lần lúc tạo — hệ thống không lưu link gốc.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _resultBlock(MsAssignmentDetail d, MsResultView r) {
    final color = r.criticalFail ? BananColors.danger : BananColors.success;
    return Container(
      width: double.infinity,
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
              Text(
                r.criticalFail ? 'CRITICAL FAIL' : '${r.totalScore ?? '—'}/100 điểm',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
              ),
              if (d.status != 'APPROVED')
                Text('(xem trước — chưa duyệt)', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: BananSpacing.sm),
          Wrap(
            spacing: BananSpacing.md,
            runSpacing: BananSpacing.xs,
            children: [
              for (final s in r.sections)
                Text('${s.code}. ${s.title}: ${s.score == null ? 'N/A' : '${s.score}/${s.weight}'}',
                    style: Theme.of(context).textTheme.bodySmall,),
            ],
          ),
          if (r.criticals.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.sm),
            for (final c in r.criticals)
              Text('⚠ $c', style: const TextStyle(color: BananColors.danger)),
          ],
          if (r.issues.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.sm),
            Text('Vấn đề ghi nhận:', style: Theme.of(context).textTheme.bodySmall),
            for (final i in r.issues) Text('• $i', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _submissionBlock(MsAssignmentDetail d) {
    final s = d.submission!;
    final timeline = [
      ('Bước vào', s.enteredAt),
      ('Được chào', s.greetedAt),
      ('Bắt đầu đặt', s.orderStartAt),
      ('Thanh toán', s.paidAt),
      ('Nhận món', s.receivedAt),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bài nộp của Mystery Shopper', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: BananSpacing.sm),
          _kv('Nộp lúc', s.submittedAt == null ? 'Chưa nộp' : vnDateTime.format(s.submittedAt!.toLocal())),
          _kv('Timeline',
              timeline.map((t) => '${t.$1}: ${t.$2 == null ? '—' : vnTime.format(t.$2!.toLocal())}').join(' · '),),
          _kv('Sản phẩm mua', s.productsBought ?? '—'),
          _kv('Giá thực trả', s.amountPaidVnd == null ? '—' : vnd.format(s.amountPaidVnd)),
          _kv('Nhân viên (bảng tên)', s.staffName ?? '—'),
          _kv('Nhận xét', s.overallComment ?? '—'),
          if (s.evidence.isNotEmpty) ...[
            const SizedBox(height: BananSpacing.sm),
            Wrap(
              spacing: BananSpacing.sm,
              runSpacing: BananSpacing.sm,
              children: [
                for (final ev in s.evidence)
                  Column(
                    children: [
                      PrivateImage(name: ev.url, size: 96),
                      Text(ev.kind ?? '', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ],
          const Divider(height: BananSpacing.xl),
          for (final section in d.sections) ...[
            Text(
              section.kind == 'CRITICAL'
                  ? '⚠ ${section.title}'
                  : '${section.code}. ${section.title} (${section.weight}đ)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: section.kind == 'CRITICAL' ? BananColors.danger : BananColors.primary,
                  ),
            ),
            const SizedBox(height: BananSpacing.xs),
            for (final q in section.questions) _answerRow(s, section, q),
            const SizedBox(height: BananSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _answerRow(MsSubmissionView s, MsSectionView section, MsQuestionView q) {
    final a = s.answerFor(q.id);
    final isCritical = section.kind == 'CRITICAL';
    final label = isCritical
        ? (a?.value == 'YES' ? 'CÓ VI PHẠM' : a?.value == 'NO' ? 'Không' : '—')
        : switch (a?.value) {
            'YES' => 'Đạt',
            'NO' => 'Không đạt',
            'NOT_AVAILABLE' => 'N/A',
            _ => '—',
          };
    final bad = (isCritical && a?.value == 'YES') || (!isCritical && a?.value == 'NO');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(q.text, style: Theme.of(context).textTheme.bodyMedium)),
              const SizedBox(width: BananSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: bad ? BananColors.danger : null,
                ),
              ),
            ],
          ),
          if ((a?.note ?? '').isNotEmpty)
            Text('   ${a!.note}', style: Theme.of(context).textTheme.bodySmall),
          if (a != null && a.evidence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: BananSpacing.xs,
                children: [
                  for (final ev in a.evidence) PrivateImage(name: ev.url, size: 56),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
