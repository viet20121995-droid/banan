import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = viStrings;
  // Tue 11/08/2026 16:00 — mirrors the reported bug: picking 15:00 on 13/08
  // showed "Ngày mai" because Duration.inDays truncated ~47h to 1.
  final now = DateTime(2026, 8, 11, 16);

  test('two calendar days out but <48h is "Sau 2 ngày", NOT "Ngày mai"', () {
    expect(
      relativeDayLabel(s, DateTime(2026, 8, 13, 15), now),
      s.inDays(2),
    );
  });

  test('tomorrow stays "Ngày mai" whether under or over 24h away', () {
    expect(relativeDayLabel(s, DateTime(2026, 8, 12, 9), now), s.tomorrow);
    expect(relativeDayLabel(s, DateTime(2026, 8, 12, 20), now), s.tomorrow);
  });

  test('same day: minutes under an hour, hours after that', () {
    expect(
      relativeDayLabel(s, DateTime(2026, 8, 11, 16, 45), now),
      s.inMinutes(45),
    );
    expect(relativeDayLabel(s, DateTime(2026, 8, 11, 20), now), s.inHours(4));
  });

  test('far future counts calendar days', () {
    expect(relativeDayLabel(s, DateTime(2026, 8, 18, 8), now), s.inDays(7));
  });

  test('past moment reads as already-scheduled', () {
    expect(relativeDayLabel(s, DateTime(2026, 8, 11, 12), now), s.scheduleWas);
  });
}
