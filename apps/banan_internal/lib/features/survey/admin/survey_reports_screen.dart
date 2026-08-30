import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/internal_api.dart';
import '../../../data/internal_models.dart';
import '../../../data/survey_models.dart';
import '../../../shared/save_file.dart';
import '../../../shared/widgets.dart';
import 'survey_shell.dart';

/// Survey dashboard: totals, NPS, trend, per-branch compare, category
/// breakdown, top issues/likes, recent comments + CSV export.
/// Deliberately NO response-rate metric — we have no real visit/receipt
/// denominator yet, and a made-up one would mislead.
class SurveyReportsScreen extends ConsumerStatefulWidget {
  const SurveyReportsScreen({super.key});

  @override
  ConsumerState<SurveyReportsScreen> createState() => _SurveyReportsScreenState();
}

class _SurveyReportsScreenState extends ConsumerState<SurveyReportsScreen> {
  Result<SurveySummary, AppFailure>? _summary;
  List<StoreRef> _stores = const [];
  List<SurveyTemplateListItem> _templates = const [];

  DateTime? _from;
  DateTime? _to;
  String? _storeId;
  String? _templateId;
  int? _overall;
  String? _caseStatus;
  String _bucket = 'day';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _load();
  }

  /// Calendar day, no time/zone — backend anchors it to Asia/Ho_Chi_Minh, so
  /// a "29/08" filter means VN's Aug 29 regardless of server timezone.
  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> get _query => {
        if (_from != null) 'from': _day(_from!),
        if (_to != null) 'to': _day(_to!), // inclusive on the backend
        if (_storeId != null) 'storeId': _storeId,
        if (_templateId != null) 'templateId': _templateId,
        if (_overall != null) 'overall': _overall,
        if (_caseStatus != null) 'caseStatus': _caseStatus,
        'bucket': _bucket,
      };

  Future<void> _loadFilters() async {
    final api = ref.read(internalApiProvider);
    final stores = await api.stores();
    final templates = await api.surveyTemplates();
    if (!mounted) return;
    setState(() {
      stores.when(success: (s) => _stores = s, failure: (_) {});
      templates.when(success: (t) => _templates = t, failure: (_) {});
    });
  }

  Future<void> _load() async {
    setState(() => _summary = null);
    final res = await ref.read(internalApiProvider).surveySummary(_query);
    if (mounted) setState(() => _summary = res);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final res = await ref.read(internalApiProvider).surveyExportCsv(_query);
    if (!mounted) return;
    setState(() => _exporting = false);
    res.when(
      success: (bytes) {
        saveBytesAsFile(bytes, 'banan-survey.csv', 'text/csv;charset=utf-8');
        showSnack(context, 'Đã tải CSV.');
      },
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isFrom ? _from = picked : _to = picked);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return SurveyShell(
      title: 'Khảo sát khách hàng',
      subtitle: 'Báo cáo trải nghiệm tại quán',
      actions: [
        IconButton(
          tooltip: 'Xuất CSV',
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(BananSpacing.lg),
        children: [
          _filters(),
          const SizedBox(height: BananSpacing.lg),
          FetchBody<SurveySummary>(
            state: _summary,
            onRetry: _load,
            builder: _content,
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Wrap(
      spacing: BananSpacing.sm,
      runSpacing: BananSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_from == null ? 'Từ ngày' : vnDate.format(_from!)),
          onPressed: () => _pickDate(true),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_to == null ? 'Đến ngày' : vnDate.format(_to!)),
          onPressed: () => _pickDate(false),
        ),
        // Capped: a long branch name must not outgrow a 390px-wide Wrap.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: DropdownButton<String?>(
            value: _storeId,
            hint: const Text('Chi nhánh'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(child: Text('Tất cả chi nhánh')),
              for (final s in _stores)
                DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              setState(() => _storeId = v);
              _load();
            },
          ),
        ),
        DropdownButton<String?>(
          value: _templateId,
          hint: const Text('Phiên bản'),
          items: [
            const DropdownMenuItem(child: Text('Mọi phiên bản')),
            for (final t in _templates)
              DropdownMenuItem(value: t.id, child: Text('v${t.version} · ${t.status}')),
          ],
          onChanged: (v) {
            setState(() => _templateId = v);
            _load();
          },
        ),
        DropdownButton<int?>(
          value: _overall,
          hint: const Text('Điểm'),
          items: [
            const DropdownMenuItem(child: Text('Mọi điểm')),
            for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i/5')),
          ],
          onChanged: (v) {
            setState(() => _overall = v);
            _load();
          },
        ),
        DropdownButton<String?>(
          value: _caseStatus,
          hint: const Text('Case'),
          items: const [
            DropdownMenuItem(child: Text('Mọi case')),
            DropdownMenuItem(value: 'NEW', child: Text('Case mới')),
            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Đang xử lý')),
            DropdownMenuItem(value: 'RESOLVED', child: Text('Đã xử lý')),
            DropdownMenuItem(value: 'OVERDUE', child: Text('Quá SLA')),
          ],
          onChanged: (v) {
            setState(() => _caseStatus = v);
            _load();
          },
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'day', label: Text('Ngày')),
            ButtonSegment(value: 'week', label: Text('Tuần')),
          ],
          selected: {_bucket},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            setState(() => _bucket = s.first);
            _load();
          },
        ),
      ],
    );
  }

  Widget _content(SurveySummary s) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: BananSpacing.md,
          runSpacing: BananSpacing.md,
          children: [
            _stat('Tổng phản hồi', '${s.total}'),
            _stat('Điểm trung bình', s.avgOverall?.toStringAsFixed(2) ?? '—'),
            _stat('Hài lòng (4–5★)', s.pctHigh != null ? '${s.pctHigh}%' : '—'),
            _stat('Chưa hài lòng (1–2★)', s.pctLow != null ? '${s.pctLow}%' : '—',
                intent: StatusIntent.warning,),
            _stat('NPS', s.nps != null ? '${s.nps}' : '—',
                caption: s.npsCount > 0 ? '${s.npsCount} trả lời' : null,),
            _stat('Case chưa xử lý', '${s.openCases}',
                intent: s.openCases > 0 ? StatusIntent.danger : StatusIntent.success,
                caption: s.overdueCases > 0 ? '${s.overdueCases} quá SLA' : null,),
          ],
        ),
        const SizedBox(height: BananSpacing.xl),
        _section('Xu hướng theo ${_bucket == 'day' ? 'ngày' : 'tuần'}'),
        _trend(s.trend),
        const SizedBox(height: BananSpacing.xl),
        _section('So sánh chi nhánh'),
        for (final st in s.stores)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(st.storeName),
            subtitle: Text('${st.count} phản hồi · ${st.lowCount} điểm thấp'),
            trailing: Text(
              st.avgOverall?.toStringAsFixed(2) ?? '—',
              style: theme.textTheme.titleMedium,
            ),
          ),
        if (s.stores.isEmpty) _empty(),
        const SizedBox(height: BananSpacing.xl),
        _section('Điểm theo hạng mục'),
        for (final c in s.categories)
          Padding(
            padding: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: Row(
              children: [
                SizedBox(width: 180, child: Text(c.label, style: theme.textTheme.bodyMedium)),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (c.avg ?? 0) / 5,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: BananSpacing.sm),
                Text('${c.avg?.toStringAsFixed(2) ?? '—'} (${c.count})',
                    style: theme.textTheme.labelMedium,),
              ],
            ),
          ),
        if (s.categories.isEmpty) _empty(),
        const SizedBox(height: BananSpacing.xl),
        _section('Cần cải thiện nhất'),
        _topChips(s.topIssues, StatusIntent.warning),
        const SizedBox(height: BananSpacing.xl),
        _section('Khách yêu thích nhất'),
        _topChips(s.topPraise, StatusIntent.success),
        const SizedBox(height: BananSpacing.xl),
        _section('Góp ý gần nhất'),
        for (final c in s.recentComments)
          Card(
            margin: const EdgeInsets.only(bottom: BananSpacing.sm),
            child: ListTile(
              title: Text(c.comment),
              subtitle: Text(
                '${c.storeName} · ${c.overall != null ? '${c.overall}/5' : '—'}'
                '${c.createdAt != null ? ' · ${vnDateTime.format(c.createdAt!.toLocal())}' : ''}',
              ),
            ),
          ),
        if (s.recentComments.isEmpty) _empty(),
      ],
    );
  }

  Widget _stat(String label, String value, {StatusIntent? intent, String? caption}) {
    final theme = Theme.of(context);
    return Container(
      width: 180,
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: BananSpacing.xs),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: switch (intent) {
                StatusIntent.danger => theme.colorScheme.error,
                StatusIntent.warning => const Color(0xFFB07B10),
                StatusIntent.success => const Color(0xFF2E7D32),
                _ => null,
              },
            ),
          ),
          if (caption != null) Text(caption, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: BananSpacing.md),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(bottom: BananSpacing.sm),
        child: Text('Chưa có dữ liệu.', style: Theme.of(context).textTheme.bodySmall),
      );

  Widget _trend(List<SurveyTrendPoint> trend) {
    if (trend.isEmpty) return _empty();
    final maxCount = trend.map((t) => t.count).fold(1, (a, b) => a > b ? a : b);
    final shown = trend.length > 30 ? trend.sublist(trend.length - 30) : trend;
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final t in shown)
            Expanded(
              child: Tooltip(
                message:
                    '${t.bucket}\n${t.count} phản hồi · TB ${t.avgOverall?.toStringAsFixed(2) ?? '—'}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: 110.0 * t.count / maxCount + 4,
                        decoration: BoxDecoration(
                          color: BananColors.primary.withValues(alpha: 0.75),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topChips(List<SurveyTopOption> options, StatusIntent intent) {
    if (options.isEmpty) return _empty();
    return Wrap(
      spacing: BananSpacing.sm,
      runSpacing: BananSpacing.sm,
      children: [
        for (final o in options)
          Chip(
            // Capped + ellipsized so one long option label can never outgrow
            // a phone-width Wrap.
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: Text('${o.label} · ${o.count}', overflow: TextOverflow.ellipsis),
            ),
            side: BorderSide(
              color: intent == StatusIntent.warning
                  ? const Color(0xFFB07B10)
                  : const Color(0xFF2E7D32),
            ),
          ),
      ],
    );
  }
}
