import 'package:flutter/material.dart';

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String _two(int n) => n.toString().padLeft(2, '0');

/// "Hôm nay · T7 30/08" or "T2 01/09/2026" — no intl locale data needed.
String kitchenDayLabel(DateTime day, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final isToday =
      day.year == now.year && day.month == now.month && day.day == now.day;
  final wd = _weekdays[day.weekday - 1];
  return isToday
      ? 'Hôm nay · $wd ${_two(day.day)}/${_two(day.month)}'
      : '$wd ${_two(day.day)}/${_two(day.month)}/${day.year}';
}

/// Day switcher for the kitchen board: previous / next day arrows, the day
/// itself opens a calendar, and a "Hôm nay" shortcut appears whenever the
/// board is not on today.
class KitchenDayBar extends StatelessWidget {
  const KitchenDayBar({
    required this.day,
    required this.onChanged,
    super.key,
    this.today,
  });

  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  /// Injectable "today" so tests can pin the label.
  final DateTime? today;

  bool get _isToday {
    final now = today ?? DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  Future<void> _pick(BuildContext context) async {
    final now = today ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Xem đơn bếp ngày',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Ngày trước',
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_left),
        ),
        OutlinedButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(
            kitchenDayLabel(day, today: today),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: _isToday ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Ngày sau',
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(day.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right),
        ),
        if (!_isToday)
          TextButton(
            onPressed: () => onChanged(today ?? DateTime.now()),
            child: const Text('Hôm nay'),
          ),
      ],
    );
  }
}
