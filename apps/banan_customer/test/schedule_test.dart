import 'package:banan_customer/features/checkout/fulfillment_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The schedule helpers pick the time the order is submitted with. Get them
/// wrong and the backend rejects the order at the last step, after the customer
/// has already filled everything in.

void main() {
  group('earliestScheduleSlot', () {
    test('rounds up to the next 15-minute boundary', () {
      final slot = earliestScheduleSlot(Duration.zero);
      expect(slot.minute % 15, 0);
      expect(slot.isBefore(DateTime.now()), isFalse);
    });

    test('honours the lead time', () {
      final slot = earliestScheduleSlot(const Duration(hours: 48));
      final earliest = DateTime.now().add(const Duration(hours: 48));
      expect(
        slot.isBefore(earliest.subtract(const Duration(minutes: 1))),
        isFalse,
        reason: 'a 48h cake must not be schedulable sooner than 48h out',
      );
    });

    test('skips to the first allowed weekday and opens at 08:00', () {
      // Only Sundays (0). Whatever today is, the slot must land on a Sunday.
      final slot = earliestScheduleSlot(Duration.zero, allowedDays: {0});
      expect(slot.weekday % 7, 0);
      // Same-day Sunday can keep the current time; a future Sunday opens at 08.
      final today = DateTime.now();
      final sameDay = slot.year == today.year &&
          slot.month == today.month &&
          slot.day == today.day;
      if (!sameDay) expect(slot.hour, 8);
    });

    test('lead time and allowed days compose', () {
      final slot =
          earliestScheduleSlot(const Duration(hours: 48), allowedDays: {6});
      expect(slot.weekday % 7, 6, reason: 'must be a Saturday');
      expect(
        slot.isAfter(DateTime.now().add(const Duration(hours: 47))),
        isTrue,
        reason: 'and still respect the 48h lead',
      );
    });

    test('an empty or full allowed-days set means no restriction', () {
      final now = DateTime.now();
      for (final days in [<int>{}, {0, 1, 2, 3, 4, 5, 6}]) {
        final slot = earliestScheduleSlot(Duration.zero, allowedDays: days);
        expect(
          slot.difference(now).inHours < 24,
          isTrue,
          reason: 'must not be pushed to another day',
        );
      }
    });
  });

  group('prepLeadNote', () {
    test('says nothing when nothing needs notice', () {
      expect(prepLeadNote(leadHours: 0, names: []), isNull);
    });

    test('renders whole days as days and the rest as hours', () {
      expect(prepLeadNote(leadHours: 48, names: ['Cake']), contains('2 ngày'));
      expect(prepLeadNote(leadHours: 5, names: ['Cake']), contains('5 giờ'));
      expect(prepLeadNote(leadHours: 36, names: ['Cake']), contains('36 giờ'));
    });

    test('names the cakes, and summarises past two', () {
      expect(prepLeadNote(leadHours: 24, names: ['A', 'B']), contains('A, B'));
      final many = prepLeadNote(leadHours: 24, names: ['A', 'B', 'C', 'D']);
      expect(many, contains('A, B'));
      expect(many, contains('2 món khác'));
    });
  });

  group('dayConstraintNote', () {
    test('says nothing when every day works', () {
      expect(dayConstraintNote(allowedDays: [], names: []), isNull);
      expect(
        dayConstraintNote(allowedDays: [0, 1, 2, 3, 4, 5, 6], names: ['A']),
        isNull,
      );
    });

    test('lists the allowed days in Vietnamese weekday order', () {
      final note = dayConstraintNote(allowedDays: [6, 0], names: ['Cake']);
      expect(note, contains('CN'));
      expect(note, contains('T7'));
      expect(note, contains('Cake'));
    });
  });
}
