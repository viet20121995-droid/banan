import type { KitchenStatus, OrderStatus, Prisma } from '@prisma/client';

const DAY_MS = 86_400_000;

/** Statuses an order can hold once it has been routed to a kitchen. */
const KITCHEN_VISIBLE: OrderStatus[] = [
  'SENT_TO_KITCHEN',
  'READY_FOR_PICKUP',
  'DELIVERING',
  'COMPLETED',
];
const DISPATCHED: OrderStatus[] = ['READY_FOR_PICKUP', 'DELIVERING', 'COMPLETED'];

/** yyyy-MM-dd of `d` in Asia/Ho_Chi_Minh — the kitchen's calendar day. */
export function vnDayKey(d: Date): string {
  return d.toLocaleDateString('en-CA', { timeZone: 'Asia/Ho_Chi_Minh' });
}

/** UTC instant of VN midnight starting the given `yyyy-MM-dd`. */
export function vnDayStart(day: string): Date {
  return new Date(`${day}T00:00:00+07:00`);
}

export const KITCHEN_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

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
 *   - orders scheduled inside the range (whatever their status),
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
        { status: { in: KITCHEN_VISIBLE }, scheduledFor: range },
        { status: { in: KITCHEN_VISIBLE }, scheduledFor: null, createdAt: range },
        { status: { in: DISPATCHED }, updatedAt: range },
      ],
    };
  }

  if (!opts.includeDoneToday) return { kitchenId, ...live };

  const startOfToday = vnDayStart(vnDayKey(now));
  return {
    kitchenId,
    OR: [live, { status: { in: DISPATCHED }, updatedAt: { gte: startOfToday } }],
  };
}
