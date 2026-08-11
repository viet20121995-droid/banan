import 'app_strings.dart';

/// Relative label for a scheduled moment: "Sau 45 phút" / "Sau 3 giờ" /
/// "Ngày mai" / "Sau N ngày".
///
/// N counts CALENDAR days, not 24-hour buckets — 15:00 two days from now is
/// "Sau 2 ngày" even though it is only ~46h away (Duration.inDays would
/// truncate that to 1 and mislabel it "Ngày mai").
String relativeDayLabel(AppStrings s, DateTime when, DateTime now) {
  final diff = when.difference(now);
  if (diff.isNegative) return s.scheduleWas;
  if (diff.inMinutes < 60) return s.inMinutes(diff.inMinutes);
  final days = DateTime(when.year, when.month, when.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days == 0) return s.inHours(diff.inHours);
  if (days == 1) return s.tomorrow;
  return s.inDays(days);
}
