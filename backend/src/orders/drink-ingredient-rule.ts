import { vnDayKey, vnDayStart } from '../kitchen/kitchen-queue-where';

/**
 * Bar restock rhythm (from the branch order book): drink ingredients are
 * ordered on Sunday and Thursday (Vietnam calendar) and the kitchen delivers
 * them the next morning. Cakes and packaging keep their own rules.
 */
export const DRINK_INGREDIENT_ORDER_DAYS: readonly number[] = [0, 4]; // Sun, Thu

const DAY_MS = 86_400_000;
const DELIVERY_MINUTES = 6 * 60 + 30; // branches receive 06:30–07:30

/** JS weekday (0=Sun) of `now` on the Vietnam calendar. */
export function vnWeekday(now: Date): number {
  return new Date(`${vnDayKey(now)}T12:00:00Z`).getUTCDay();
}

export function isDrinkIngredientOrderDay(now: Date): boolean {
  return DRINK_INGREDIENT_ORDER_DAYS.includes(vnWeekday(now));
}

/** 06:30 Vietnam time on the calendar day after `now`. */
export function nextMorningDelivery(now: Date): Date {
  const tomorrow = vnDayStart(vnDayKey(now)).getTime() + DAY_MS;
  return new Date(tomorrow + DELIVERY_MINUTES * 60_000);
}
