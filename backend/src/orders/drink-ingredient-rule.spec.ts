import { isDrinkIngredientOrderDay, nextMorningDelivery, vnWeekday } from './drink-ingredient-rule';

describe('drink ingredient order rule', () => {
  it('reads the weekday on the Vietnam calendar, not UTC', () => {
    // 20:00 UTC Saturday 05/09 is already 03:00 Sunday 06/09 in Vietnam.
    expect(vnWeekday(new Date('2026-09-05T20:00:00Z'))).toBe(0);
    expect(vnWeekday(new Date('2026-09-03T03:00:00Z'))).toBe(4); // Thursday
  });

  it('accepts Sunday and Thursday, refuses the other days', () => {
    expect(isDrinkIngredientOrderDay(new Date('2026-09-06T05:00:00Z'))).toBe(true); // Sun
    expect(isDrinkIngredientOrderDay(new Date('2026-09-03T05:00:00Z'))).toBe(true); // Thu
    expect(isDrinkIngredientOrderDay(new Date('2026-09-02T05:00:00Z'))).toBe(false); // Wed
    expect(isDrinkIngredientOrderDay(new Date('2026-09-07T05:00:00Z'))).toBe(false); // Mon
  });

  it('delivers 06:30 Vietnam time the next day', () => {
    // Thursday 03/09 10:00 VN → Friday 04/09 06:30 VN = 03/09 23:30 UTC.
    expect(nextMorningDelivery(new Date('2026-09-03T03:00:00Z')).toISOString()).toBe(
      '2026-09-03T23:30:00.000Z',
    );
    // Late Sunday night VN (23:30) still lands on Monday morning.
    expect(nextMorningDelivery(new Date('2026-09-06T16:30:00Z')).toISOString()).toBe(
      '2026-09-06T23:30:00.000Z',
    );
  });
});
