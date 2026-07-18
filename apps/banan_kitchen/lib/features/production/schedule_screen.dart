import 'package:banan_data/banan_data.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'mo_list_screen.dart' show mfgStateColor, mfgStateLabels;
import 'production_providers.dart';

/// Planning board (MPS): unfinished MOs laid out as day columns — a backlog of
/// unscheduled orders plus the coming week. Tapping a card (manager only) sets
/// its day and assignee. This is the "Kanban schedule" surface; a pixel-timeline
/// Gantt is deferred — day columns cover a bakery's planning grain.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(scheduleProvider);
    final canPlan = ref.watch(canProduceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sản xuất')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(scheduleProvider),
        child: schedule.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Lỗi: $e')),
          data: (items) => _Board(items: items, canPlan: canPlan),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.items, required this.canPlan});
  final List<MfgScheduleItem> items;
  final bool canPlan;

  @override
  Widget build(BuildContext context) {
    final today = ScheduleScreen._day(DateTime.now());
    // Always show the coming week, plus any day something is already scheduled
    // for (past overdue or further out).
    final days = <DateTime>{
      for (var i = 0; i < 7; i++) today.add(Duration(days: i)),
      for (final it in items)
        if (it.scheduledDate != null) ScheduleScreen._day(it.scheduledDate!),
    }.toList()
      ..sort();

    final backlog = items.where((it) => it.scheduledDate == null).toList();
    final byDay = <DateTime, List<MfgScheduleItem>>{};
    for (final it in items) {
      if (it.scheduledDate == null) continue;
      byDay.putIfAbsent(ScheduleScreen._day(it.scheduledDate!), () => []).add(it);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(BananSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Column(
            title: 'Chưa lên lịch',
            subtitle: '${backlog.length} lệnh',
            highlight: backlog.isNotEmpty,
            items: backlog,
            canPlan: canPlan,
          ),
          for (final day in days)
            _Column(
              title: _dayLabel(today, day),
              subtitle: DateFormat('dd/MM').format(day),
              overdue: day.isBefore(today),
              items: byDay[day] ?? const [],
              canPlan: canPlan,
            ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime today, DateTime day) {
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Ngày mai';
    const wd = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return wd[day.weekday - 1];
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.canPlan,
    this.highlight = false,
    this.overdue = false,
  });
  final String title;
  final String subtitle;
  final List<MfgScheduleItem> items;
  final bool canPlan;
  final bool highlight;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Padding(
        padding: const EdgeInsets.only(right: BananSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: overdue ? BananColors.danger : null,
                    ),),
                const SizedBox(width: 6),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: BananSpacing.sm),
            if (items.isEmpty)
              Text('—', style: TextStyle(color: theme.colorScheme.outline))
            else
              for (final it in items) _Card(item: it, canPlan: canPlan),
          ],
        ),
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.item, required this.canPlan});
  final MfgScheduleItem item;
  final bool canPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = mfgStateColor(item.state);
    return Container(
      margin: const EdgeInsets.only(bottom: BananSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BananRadii.rmd,
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerTheme.color ?? Colors.black12),
      ),
      child: InkWell(
        borderRadius: BananRadii.rmd,
        onTap: canPlan ? () => _plan(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.all(BananSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.code, style: theme.textTheme.titleSmall),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.14),
                      borderRadius: BananRadii.rPill,
                    ),
                    child: Text(mfgStateLabels[item.state] ?? item.state,
                        style: TextStyle(
                            color: c, fontSize: 11, fontWeight: FontWeight.w600,),),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${item.productNameVi} · ${item.qtyToProduce.toStringAsFixed(0)}${item.uomCode}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 14, color: theme.colorScheme.outline,),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.responsibleName ?? 'Chưa phân công',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: item.responsibleName == null
                            ? theme.colorScheme.outline
                            : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _plan(BuildContext context, WidgetRef ref) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _PlanDialog(item: item),
    );
    if (changed ?? false) ref.invalidate(scheduleProvider);
  }
}

/// Set an MO's scheduled day + assignee. Both clearable.
class _PlanDialog extends ConsumerStatefulWidget {
  const _PlanDialog({required this.item});
  final MfgScheduleItem item;
  @override
  ConsumerState<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends ConsumerState<_PlanDialog> {
  late DateTime? _date = widget.item.scheduledDate;
  late String? _responsibleId = widget.item.responsibleId;
  bool _busy = false;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await ref.read(manufacturingApiProvider).planOrder(
          widget.item.id,
          scheduledDate: _date,
          responsibleId: _responsibleId,
        );
    if (!mounted) return;
    res.when(
      success: (_) => Navigator.pop(context, true),
      failure: (f) => setState(() {
        _busy = false;
        _error = f.message ?? f.code;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(staffProvider);
    return AlertDialog(
      title: Text('Lên lịch · ${widget.item.code}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ngày sản xuất ──
            const Text('Ngày sản xuất'),
            const SizedBox(height: BananSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_date == null
                        ? 'Chọn ngày'
                        : DateFormat('dd/MM/yyyy').format(_date!),),
                  ),
                ),
                if (_date != null)
                  IconButton(
                    tooltip: 'Bỏ lịch',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _date = null),
                  ),
              ],
            ),
            const SizedBox(height: BananSpacing.md),
            // ── người phụ trách ──
            const Text('Người phụ trách'),
            const SizedBox(height: BananSpacing.xs),
            staff.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Không tải được nhân sự: $e'),
              data: (people) => DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue:
                    people.any((p) => p.id == _responsibleId) ? _responsibleId : null,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(
                    child: Text('Chưa phân công'),
                  ),
                  for (final p in people)
                    DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(p.fullName, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _responsibleId = v),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: BananSpacing.sm),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    );
  }
}
