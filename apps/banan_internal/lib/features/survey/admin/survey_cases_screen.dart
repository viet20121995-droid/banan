import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/internal_api.dart';
import '../../../data/survey_models.dart';
import '../../../shared/internal_shell.dart';
import '../../../shared/widgets.dart';

/// Closed-loop follow-up for overall <= 2: NEW → IN_PROGRESS → RESOLVED,
/// OVERDUE derived from the SLA. Guest contact appears ONLY when the guest
/// consented.
class SurveyCasesScreen extends ConsumerStatefulWidget {
  const SurveyCasesScreen({super.key});

  @override
  ConsumerState<SurveyCasesScreen> createState() => _SurveyCasesScreenState();
}

class _SurveyCasesScreenState extends ConsumerState<SurveyCasesScreen> {
  Result<List<SurveyCaseView>, AppFailure>? _cases;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _cases = null);
    final res = await ref.read(internalApiProvider).surveyCases(status: _status);
    if (mounted) setState(() => _cases = res);
  }

  Future<void> _update(SurveyCaseView c, Map<String, dynamic> body) async {
    final res = await ref.read(internalApiProvider).surveyUpdateCase(c.id, body);
    if (!mounted) return;
    res.when(
      success: (_) => _load(),
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _editDetails(SurveyCaseView c) async {
    final assignee = TextEditingController(text: c.assigneeName ?? '');
    final note = TextEditingController(text: c.note ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ghi chú xử lý'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: assignee,
                decoration: const InputDecoration(
                  labelText: 'Người phụ trách',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: BananSpacing.md),
              TextField(
                controller: note,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (saved ?? false) {
      await _update(c, {'assigneeName': assignee.text, 'note': note.text});
    }
    assignee.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InternalShell(
      title: 'Case khảo sát',
      subtitle: 'Phản hồi điểm thấp cần xử lý',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BananSpacing.lg, BananSpacing.lg, BananSpacing.lg, 0,),
            child: Wrap(
              spacing: BananSpacing.sm,
              children: [
                for (final (value, label) in [
                  (null, 'Tất cả'),
                  ('NEW', 'Mới'),
                  ('IN_PROGRESS', 'Đang xử lý'),
                  ('OVERDUE', 'Quá SLA'),
                  ('RESOLVED', 'Đã xử lý'),
                ])
                  FilterChip(
                    label: Text(label),
                    selected: _status == value,
                    onSelected: (_) {
                      setState(() => _status = value);
                      _load();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: FetchBody<List<SurveyCaseView>>(
              state: _cases,
              onRetry: _load,
              builder: (cases) => cases.isEmpty
                  ? const Center(child: Text('Không có case nào.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(BananSpacing.lg),
                      itemCount: cases.length,
                      itemBuilder: (context, i) => _caseCard(cases[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _caseCard(SurveyCaseView c) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: BananSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(BananSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: BananSpacing.sm,
              runSpacing: BananSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(c.storeName, style: theme.textTheme.titleSmall),
                StatusBadge(
                  label: '${c.overall ?? '?'}/5',
                  intent: StatusIntent.danger,
                ),
                StatusBadge(label: _statusLabel(c.status), intent: _statusIntent(c.status)),
                if (c.overdue)
                  const StatusBadge(label: 'Quá SLA', intent: StatusIntent.danger),
                if (c.createdAt != null)
                  Text(vnDateTime.format(c.createdAt!.toLocal()),
                      style: theme.textTheme.labelSmall,),
              ],
            ),
            if (c.comment != null)
              Padding(
                padding: const EdgeInsets.only(top: BananSpacing.sm),
                child: Text('“${c.comment}”', style: theme.textTheme.bodyMedium),
              ),
            Padding(
              padding: const EdgeInsets.only(top: BananSpacing.sm),
              child: Text(
                c.contact != null
                    ? 'Khách đồng ý liên hệ: ${c.contact!.name ?? '—'} · ${c.contact!.phone ?? '—'}'
                    : 'Khách không để lại thông tin liên hệ.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (c.assigneeName != null || c.note != null)
              Padding(
                padding: const EdgeInsets.only(top: BananSpacing.xs),
                child: Text(
                  [
                    if (c.assigneeName != null) 'Phụ trách: ${c.assigneeName}',
                    if (c.note != null) 'Ghi chú: ${c.note}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (c.resolvedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: BananSpacing.xs),
                child: Text('Xử lý xong: ${vnDateTime.format(c.resolvedAt!.toLocal())}',
                    style: theme.textTheme.labelSmall,),
              ),
            const SizedBox(height: BananSpacing.sm),
            Wrap(
              spacing: BananSpacing.sm,
              children: [
                if (c.status == 'NEW')
                  FilledButton.tonal(
                    onPressed: () => _update(c, {'status': 'IN_PROGRESS'}),
                    child: const Text('Bắt đầu xử lý'),
                  ),
                if (c.status != 'RESOLVED')
                  FilledButton(
                    onPressed: () => _update(c, {'status': 'RESOLVED'}),
                    child: const Text('Đã xử lý xong'),
                  ),
                if (c.status == 'RESOLVED')
                  OutlinedButton(
                    onPressed: () => _update(c, {'status': 'IN_PROGRESS'}),
                    child: const Text('Mở lại'),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Ghi chú / phụ trách'),
                  onPressed: () => _editDetails(c),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'NEW' => 'Mới',
        'IN_PROGRESS' => 'Đang xử lý',
        'RESOLVED' => 'Đã xử lý',
        _ => status,
      };

  StatusIntent _statusIntent(String status) => switch (status) {
        'RESOLVED' => StatusIntent.success,
        'IN_PROGRESS' => StatusIntent.progress,
        _ => StatusIntent.warning,
      };
}
