// The print template is built by adjacent-string concatenation — the
// whitespace lint doesn't apply to inline HTML (same as print_ticket).
// ignore_for_file: missing_whitespace_between_adjacent_strings
import 'dart:ui' as ui;

import 'package:banan_core/banan_core.dart';
import 'package:banan_design_system/banan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/internal_api.dart';
import '../../data/internal_models.dart';
import '../../shared/internal_shell.dart';
import '../../shared/save_file.dart';
import '../../shared/widgets.dart';

const _dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];

DateTime _mondayOf(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return date.subtract(Duration(days: (date.weekday + 6) % 7));
}

/// Weekly work schedule — all 4 branches on one screen, one column per day,
/// shift rows per branch, multiple people per cell. Reads like the Excel
/// sheet the team uses today.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _week = _mondayOf(DateTime.now());
  Result<ScheduleWeek?, AppFailure>? _state;
  List<PersonView> _people = const [];
  final _gridKey = GlobalKey();
  bool _busy = false;

  InternalApi get _api => ref.read(internalApiProvider);

  @override
  void initState() {
    super.initState();
    _load();
    _loadPeople();
  }

  Future<void> _load() async {
    setState(() => _state = null);
    final res = await _api.weekByStart(_week);
    if (mounted) setState(() => _state = res);
  }

  Future<void> _loadPeople() async {
    final res = await _api.people();
    if (mounted) setState(() => _people = res.valueOrNull ?? const []);
  }

  void _apply(Result<ScheduleWeek, AppFailure> res) {
    res.when(
      success: (w) => setState(() => _state = Result.success(w)),
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _createWeek() async {
    final weeks = (await _api.weeks()).valueOrNull ?? [];
    if (!mounted) return;
    String? copyFrom;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Tạo lịch tuần ${vnDate.format(_week)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lịch nháp sẽ có sẵn Ca 1/2/3 cho cả 4 chi nhánh (sửa được).'),
              const SizedBox(height: BananSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: copyFrom,
                decoration: const InputDecoration(labelText: 'Sao chép từ tuần (tuỳ chọn)'),
                items: [
                  const DropdownMenuItem<String?>(child: Text('Không sao chép')),
                  for (final w in weeks)
                    DropdownMenuItem<String?>(
                      value: w.id,
                      child: Text('Tuần ${vnDate.format(w.weekStart.toLocal())}'),
                    ),
                ],
                onChanged: (v) => setLocal(() => copyFrom = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tạo lịch'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final res = await _api.createWeek(_week, copyFromScheduleId: copyFrom);
    if (!mounted) return;
    res.when(
      success: (w) => setState(() => _state = Result.success(w)),
      failure: (f) => showFailure(context, f),
    );
  }

  Future<void> _publish(ScheduleWeek w) async {
    final warnings = w.warnings.where((x) => x.kind != 'EMPTY_SHIFT').length;
    final ok = await confirmDialog(
      context,
      title: 'Publish lịch tuần?',
      message: 'Lịch sẽ được chốt thành bản ${w.revision + 1} và lưu snapshot. '
          '${warnings > 0 ? 'Lưu ý: đang có $warnings cảnh báo (trùng giờ/nhân sự ngưng làm).' : ''}',
      confirmLabel: 'Publish',
    );
    if (!ok || !mounted) return;
    _apply(await _api.publishWeek(w.id));
  }

  Future<void> _unpublish(ScheduleWeek w) async {
    final ok = await confirmDialog(
      context,
      title: 'Gỡ publish?',
      message: 'Lịch quay về trạng thái nháp. Các snapshot đã publish vẫn được giữ để truy vết.',
      confirmLabel: 'Gỡ publish',
      danger: true,
    );
    if (!ok || !mounted) return;
    _apply(await _api.unpublishWeek(w.id));
  }

  Future<void> _exportPng(ScheduleWeek w) async {
    setState(() => _busy = true);
    try {
      final boundary =
          _gridKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      saveBytesAsFile(
        bytes.buffer.asUint8List(),
        'lich-tuan-${vnDate.format(w.weekStart.toLocal()).replaceAll('/', '-')}.png',
        'image/png',
      );
      if (mounted) showSnack(context, 'Đã xuất ảnh PNG.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _print(ScheduleWeek w) {
    final b = StringBuffer()
      ..write('<html><head><meta charset="utf-8"><title>Lịch tuần</title><style>'
          'body{font-family:system-ui,Arial;padding:16px}'
          'h1{font-size:18px}h2{font-size:14px;margin:16px 0 4px;color:#1E6A35}'
          'table{border-collapse:collapse;width:100%;margin-bottom:8px}'
          'td,th{border:1px solid #bbb;padding:4px 6px;font-size:11px;vertical-align:top}'
          'th{background:#f0f0e8}.shift{white-space:nowrap;font-weight:600}'
          '.note{color:#666;font-size:10px}'
          '@media print{button{display:none}}</style></head><body>')
      ..write('<h1>Banan · Lịch làm tuần ${vnDate.format(w.weekStart.toLocal())}'
          ' (bản ${w.revision})</h1>');
    final stores = _storesOf(w);
    for (final store in stores) {
      b.write('<h2>${store.name}</h2><table><tr><th>Ca</th>');
      for (final d in _dayNames) {
        b.write('<th>$d</th>');
      }
      b.write('</tr>');
      for (final shift in w.shifts.where((s) => s.store.id == store.id)) {
        b.write('<tr><td class="shift">${shift.label}<br>${shift.startTime}–${shift.endTime}</td>');
        for (var day = 0; day < 7; day++) {
          final cell = shift
              .forDay(day)
              .map(
                (a) =>
                    '${a.displayName}${a.note != null ? '<div class="note">${a.note}</div>' : ''}',
              )
              .join('<br>');
          b.write('<td>$cell</td>');
        }
        b.write('</tr>');
      }
      b.write('</table>');
    }
    b.write('<script>setTimeout(function(){window.print();},300);</script></body></html>');
    printHtml(b.toString(), 'Lịch tuần');
  }

  List<StoreRef> _storesOf(ScheduleWeek w) {
    final seen = <String, StoreRef>{};
    for (final s in w.shifts) {
      seen[s.store.id] = s.store;
    }
    return seen.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final week = _state?.valueOrNull;
    return InternalShell(
      title: 'Lịch làm hàng tuần',
      subtitle: 'Tuần ${vnDate.format(_week)} – ${vnDate.format(_week.add(const Duration(days: 6)))}'
          '${week == null ? '' : ' · ${week.status == 'PUBLISHED' ? 'ĐÃ PUBLISH (bản ${week.revision})' : week.status == 'ARCHIVED' ? 'Lưu trữ' : 'Nháp'}'}',
      actions: [
        IconButton(
          tooltip: 'Tuần trước',
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() => _week = _week.subtract(const Duration(days: 7)));
            _load();
          },
        ),
        IconButton(
          tooltip: 'Tuần sau',
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() => _week = _week.add(const Duration(days: 7)));
            _load();
          },
        ),
        if (week != null) ...[
          IconButton(
            tooltip: 'Xuất PNG',
            icon: const Icon(Icons.image_outlined),
            onPressed: _busy ? null : () => _exportPng(week),
          ),
          IconButton(
            tooltip: 'In lịch / PDF',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => _print(week),
          ),
        ],
      ],
      body: FetchBody<ScheduleWeek?>(
        state: _state,
        onRetry: _load,
        builder: (w) {
          if (w == null) {
            return EmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Tuần này chưa có lịch',
              message: 'Tạo lịch nháp (có thể sao chép tuần trước) rồi điền tên theo ca.',
              action: PrimaryButton(
                label: 'Tạo lịch tuần này',
                icon: Icons.add,
                onPressed: _createWeek,
              ),
            );
          }
          final editable = w.status != 'ARCHIVED';
          return ListView(
            padding: const EdgeInsets.all(BananSpacing.lg),
            children: [
              Wrap(
                spacing: BananSpacing.md,
                runSpacing: BananSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    label: w.status == 'PUBLISHED'
                        ? 'Đã publish · bản ${w.revision}'
                        : w.status == 'ARCHIVED'
                            ? 'Lưu trữ'
                            : 'Nháp',
                    intent: w.status == 'PUBLISHED'
                        ? StatusIntent.success
                        : w.status == 'ARCHIVED'
                            ? StatusIntent.neutral
                            : StatusIntent.progress,
                  ),
                  if (w.publishedAt != null)
                    Text('Publish lúc ${vnDateTime.format(w.publishedAt!.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,),
                  if (editable)
                    PrimaryButton(
                      label: w.status == 'PUBLISHED' ? 'Publish bản mới' : 'Publish lịch',
                      icon: Icons.campaign_outlined,
                      onPressed: () => _publish(w),
                    ),
                  if (w.status == 'PUBLISHED')
                    OutlinedButton.icon(
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Gỡ publish'),
                      onPressed: () => _unpublish(w),
                    ),
                ],
              ),
              if (w.warnings.isNotEmpty) ...[
                const SizedBox(height: BananSpacing.md),
                _warningsPanel(w),
              ],
              const SizedBox(height: BananSpacing.md),
              RepaintBoundary(
                key: _gridKey,
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor == Colors.transparent
                      ? const Color(0xFFFAFAF7)
                      : Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      for (final store in _storesOf(w)) ...[
                        _storeGrid(w, store, editable),
                        const SizedBox(height: BananSpacing.lg),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _warningsPanel(ScheduleWeek w) {
    final important = w.warnings.where((x) => x.kind != 'EMPTY_SHIFT').toList();
    final empties = w.warnings.length - important.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BananSpacing.md),
      decoration: BoxDecoration(
        color: BananColors.warning.withValues(alpha: 0.08),
        borderRadius: BananRadii.rmd,
        border: Border.all(color: BananColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cảnh báo (không chặn — dữ liệu bạn nhập được giữ nguyên):',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),),
          for (final x in important.take(8)) Text('• ${x.message}'),
          if (important.length > 8) Text('… và ${important.length - 8} cảnh báo khác'),
          if (empties > 0)
            Text('• $empties ô ca chưa có người.', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _storeGrid(ScheduleWeek w, StoreRef store, bool editable) {
    final shifts = w.shifts.where((s) => s.store.id == store.id).toList();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BananRadii.rmd,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BananSpacing.md,
              BananSpacing.md,
              BananSpacing.md,
              BananSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    store.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: BananColors.primary),
                  ),
                ),
                if (editable)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm ca'),
                    onPressed: () => _shiftDialog(w, store),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Fixed column widths (120 + 7×140) — the grid scrolls sideways
            // on narrow screens instead of squeezing, like the Excel sheet.
            child: Column(
              children: [
                Row(
                  children: [
                    _headCell('Ca', width: 120),
                    for (var d = 0; d < 7; d++)
                      _headCell(
                        '${_dayNames[d]} ${vnDate.format(w.weekStart.toLocal().add(Duration(days: d))).substring(0, 5)}',
                      ),
                  ],
                ),
                for (final shift in shifts)
                  // IntrinsicHeight bounds the stretch — the tallest cell of
                  // the row sets the row height (Excel-like equal cells).
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _shiftCell(w, shift, editable),
                        for (var d = 0; d < 7; d++) _dayCell(w, shift, d, editable),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: BananSpacing.sm),
        ],
      ),
    );
  }

  Widget _headCell(String text, {double width = 140}) => Container(
        width: width,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: BananColors.primary.withValues(alpha: 0.08),
          border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );

  Widget _shiftCell(ScheduleWeek w, ShiftView shift, bool editable) => InkWell(
        onTap: editable ? () => _shiftDialog(w, shift.store, shift: shift) : null,
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shift.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              Text('${shift.startTime}–${shift.endTime}', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _dayCell(ScheduleWeek w, ShiftView shift, int day, bool editable) {
    final people = shift.forDay(day);
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: editable ? () => _cellDialog(w, shift, day) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in people)
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text.rich(
                    TextSpan(
                      text: a.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: a.personActive == false ? BananColors.danger : null,
                      ),
                      children: [
                        if (a.note != null)
                          TextSpan(
                            text: ' (${a.note})',
                            style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                          ),
                      ],
                    ),
                  ),
                ),
              if (people.isEmpty && editable)
                Icon(Icons.add, size: 14, color: Theme.of(context).hintColor),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shiftDialog(ScheduleWeek w, StoreRef store, {ShiftView? shift}) async {
    final label = TextEditingController(text: shift?.label ?? 'Ca ');
    final start = TextEditingController(text: shift?.startTime ?? '09:00');
    final end = TextEditingController(text: shift?.endTime ?? '14:00');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shift == null ? 'Thêm ca — ${store.name}' : 'Sửa ca — ${store.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Tên ca')),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: start,
                    decoration: const InputDecoration(labelText: 'Bắt đầu (HH:mm)'),
                  ),
                ),
                const SizedBox(width: BananSpacing.md),
                Expanded(
                  child: TextField(
                    controller: end,
                    decoration: const InputDecoration(labelText: 'Kết thúc (HH:mm)'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (shift != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: BananColors.danger),
              onPressed: () => Navigator.of(context).pop('delete'),
              child: const Text('Xoá ca'),
            ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(context).pop('save'), child: const Text('Lưu')),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (result == 'delete' && shift != null) {
      final ok = await confirmDialog(
        context,
        title: 'Xoá ca "${shift.label}"?',
        message: 'Mọi phân công trong ca này của tuần sẽ bị xoá.',
        confirmLabel: 'Xoá',
        danger: true,
      );
      if (!ok || !mounted) return;
      _apply(await _api.removeShift(shift.id));
      return;
    }
    if (!hhmm.hasMatch(start.text.trim()) || !hhmm.hasMatch(end.text.trim())) {
      showSnack(context, 'Giờ phải theo dạng HH:mm, ví dụ 09:00.');
      return;
    }
    final body = {
      'label': label.text.trim(),
      'startTime': start.text.trim(),
      'endTime': end.text.trim(),
    };
    _apply(
      shift == null
          ? await _api.addShift(w.id, {'storeId': store.id, ...body})
          : await _api.updateShift(shift.id, body),
    );
  }

  Future<void> _cellDialog(ScheduleWeek w, ShiftView shift, int day) async {
    final existing = shift.forDay(day);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${shift.store.name} · ${shift.label} · ${_dayNames[day]}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (existing.isEmpty)
                const Text('Chưa có ai trong ca này.')
              else
                for (final a in existing)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.displayName),
                    subtitle: a.note == null ? null : Text(a.note!),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Ghi chú',
                          icon: const Icon(Icons.edit_note, size: 20),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _noteDialog(a);
                          },
                        ),
                        IconButton(
                          tooltip: 'Xoá khỏi ca',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            _apply(await _api.removeAssignment(a.id));
                          },
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
          FilledButton.icon(
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Thêm người'),
            onPressed: () async {
              Navigator.of(context).pop();
              await _addPersonDialog(shift, day);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _noteDialog(ShiftAssignView a) async {
    final note = TextEditingController(text: a.note ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ghi chú cho ${a.displayName}'),
        content: TextField(
          controller: note,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'VD: đến 16h'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _apply(await _api.updateAssignment(a.id, {'note': note.text.trim()}));
  }

  Future<void> _addPersonDialog(ShiftView shift, int day) async {
    String? personId;
    final freeName = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Thêm người — ${shift.label} · ${_dayNames[day]}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: personId,
                  decoration: const InputDecoration(labelText: 'Chọn nhân sự có hồ sơ'),
                  items: [
                    const DropdownMenuItem<String?>(child: Text('— Nhập tên tự do —')),
                    for (final p in _people)
                      DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(
                          '${p.fullName}${p.isActive ? '' : ' (ngưng làm)'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => personId = v),
                ),
                if (personId == null)
                  TextField(
                    controller: freeName,
                    decoration: const InputDecoration(labelText: 'Tên (tự do)'),
                  ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Ghi chú (VD: đến 16h)'),
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
              onPressed: () {
                if (personId == null && freeName.text.trim().isEmpty) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    _apply(
      await _api.addAssignment(shift.id, {
        'dayOfWeek': day,
        if (personId != null) 'personId': personId,
        if (personId == null) 'freeName': freeName.text.trim(),
        if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
      }),
    );
  }
}
