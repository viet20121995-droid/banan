import 'package:flutter/material.dart';

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _two(int n) => n.toString().padLeft(2, '0');

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Hôm nay · T7 30/08" or "T2 01/09/2026" — no intl locale data needed.
String kitchenDayLabel(DateTime day, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final wd = _weekdays[day.weekday - 1];
  return _sameDay(day, now)
      ? 'Hôm nay · $wd ${_two(day.day)}/${_two(day.month)}'
      : '$wd ${_two(day.day)}/${_two(day.month)}/${day.year}';
}

/// One day → [kitchenDayLabel]; a range → "T5 03/09 → CN 07/09/2026".
String kitchenRangeLabel(DateTime from, DateTime to, {DateTime? today}) {
  if (_sameDay(from, to)) return kitchenDayLabel(from, today: today);
  final a = '${_weekdays[from.weekday - 1]} ${_two(from.day)}/${_two(from.month)}';
  final b =
      '${_weekdays[to.weekday - 1]} ${_two(to.day)}/${_two(to.month)}/${to.year}';
  return '$a → $b';
}

/// Range switcher for the kitchen board: arrows step the whole window by
/// its own length, the label opens a from → to calendar, "Hôm nay" resets
/// to a single day. The board keys orders on the day they must be READY,
/// so "next week" here means "what has to come out of the oven next week".
class KitchenDayBar extends StatelessWidget {
  const KitchenDayBar({
    required this.from,
    required this.to,
    required this.onChanged,
    super.key,
    this.today,
  });

  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onChanged;

  /// Injectable "today" so tests can pin the label.
  final DateTime? today;

  bool get _isToday {
    final now = today ?? DateTime.now();
    return _sameDay(from, now) && _sameDay(to, now);
  }

  int get _spanDays => to.difference(from).inDays + 1;

  Future<void> _pick(BuildContext context) async {
    final now = today ?? DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: from, end: to),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Xem đơn bếp từ ngày → đến ngày',
      saveText: 'Xem',
    );
    if (picked != null) onChanged(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final span = Duration(days: _spanDays);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: _spanDays == 1 ? 'Ngày trước' : '$_spanDays ngày trước',
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(from.subtract(span), to.subtract(span)),
          icon: const Icon(Icons.chevron_left),
        ),
        OutlinedButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(
            kitchenRangeLabel(from, to, today: today),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: _isToday ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: _spanDays == 1 ? 'Ngày sau' : '$_spanDays ngày sau',
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(from.add(span), to.add(span)),
          icon: const Icon(Icons.chevron_right),
        ),
        if (!_isToday)
          TextButton(
            onPressed: () {
              final now = today ?? DateTime.now();
              final d = DateTime(now.year, now.month, now.day);
              onChanged(d, d);
            },
            child: const Text('Hôm nay'),
          ),
      ],
    );
  }
}
