import type { KitchenStatus, OrderStatus, Prisma } from '@prisma/client';

const DAY_MS = 86_400_000;

const DISPATCHED: OrderStatus[] = ['READY_FOR_PICKUP', 'DELIVERING', 'COMPLETED'];
const DISPATCH_EVENTS: OrderStatus[] = ['READY_FOR_PICKUP', 'DELIVERING'];

/** yyyy-MM-dd of `d` in Asia/Ho_Chi_Minh — the kitchen's calendar day. */
export function vnDayKey(d: Date): string {
  return d.toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });
}

/** UTC instant of VN midnight starting the given `yyyy-MM-dd`. */
export function vnDayStart(day: string): Date {
  return new Date(`${day}T00:00:00+07:00`);
}

export const KITCHEN_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Strict calendar validation; JS otherwise rolls 2026-02-31 into March. */
export function isKitchenDate(value: string): boolean {
  if (!KITCHEN_DATE_RE.test(value)) return false;
  const parsed = vnDayStart(value);
  return !Number.isNaN(parsed.getTime()) && vnDayKey(parsed) === value;
}

export interface KitchenQueueOpts {
  status?: KitchenStatus | null;
  includeDoneToday?: boolean;
  /** One VN calendar day (`yyyy-MM-dd`) — shorthand for from = to = date. */
  date?: string;
  /** Inclusive VN calendar-day range. */
  from?: string;
  to?: string;
}

/**
 * Prisma `where` for the kitchen board. Pure, so the day arithmetic is unit
 * tested without a database.
 *
 * Without any day: the classic live queue (+ today's dispatched ones when
 * `includeDoneToday`). With a day / range, the board is keyed on the day the
 * order has to be READY (ngày nhận), never the day it was placed:
 *   - live orders scheduled inside the range,
 *   - unscheduled orders placed inside the range (walk-ins are made now),
 *   - orders dispatched from the kitchen inside the range ("Đã xong"),
 *   - and, only when the range covers today, live orders that are overdue
 *     or unscheduled — still work, whenever they were placed. An order
 *     scheduled for a FUTURE day shows up on that day, not today.
 */
export function kitchenQueueWhere(
  kitchenId: string,
  opts: KitchenQueueOpts,
  now: Date = new Date(),
): Prisma.OrderWhereInput {
  const live: Prisma.OrderWhereInput = {
    status: 'SENT_TO_KITCHEN',
    ...(opts.status !== undefined && { kitchenStatus: opts.status }),
  };

  const dispatchedIn = (range: { gte: Date; lt?: Date }): Prisma.OrderWhereInput => ({
    status: { in: DISPATCHED },
    statusEvents: {
      some: {
        toStatus: { in: DISPATCH_EVENTS },
        createdAt: range,
      },
    },
  });

  const from = opts.from ?? opts.date;
  const to = opts.to ?? opts.date ?? from;
  if (from && to) {
    const start = vnDayStart(from);
    const end = new Date(vnDayStart(to).getTime() + DAY_MS);
    const range = { gte: start, lt: end };
    const today = vnDayKey(now);
    const coversToday = from <= today && today <= to;
    const endOfToday = new Date(vnDayStart(today).getTime() + DAY_MS);
    return {
      kitchenId,
      OR: [
        ...(coversToday
          ? [
              {
                ...live,
                OR: [{ scheduledFor: null }, { scheduledFor: { lt: endOfToday } }],
              },
            ]
          : []),
        { ...live, scheduledFor: range },
        { ...live, scheduledFor: null, createdAt: range },
        ...(opts.status === undefined ? [dispatchedIn(range)] : []),
      ],
    };
  }

  if (!opts.includeDoneToday) return { kitchenId, ...live };

  const startOfToday = vnDayStart(vnDayKey(now));
  const endOfToday = new Date(startOfToday.getTime() + DAY_MS);
  return {
    kitchenId,
    OR: [
      live,
      ...(opts.status === undefined ? [dispatchedIn({ gte: startOfToday, lt: endOfToday })] : []),
    ],
  };
}
