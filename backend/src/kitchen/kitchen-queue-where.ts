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

export const KITCHEN_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export interface KitchenQueueOpts {
  status?: KitchenStatus | null;
  includeDoneToday?: boolean;
  /** VN calendar day (`yyyy-MM-dd`). Omitted = the classic live queue. */
  date?: string;
}

/**
 * Prisma `where` for the kitchen board. Pure, so the day arithmetic is unit
 * tested without a database.
 *
 * Without `date`: orders still routed here (+ today's dispatched ones when
 * `includeDoneToday`). With `date` (a VN calendar day):
 *   - orders scheduled for that day, or unscheduled orders created that day,
 *   - orders dispatched from the kitchen that day,
 *   - and, ONLY when the day is today, every order still live in the kitchen
 *     whatever its date — an overdue order from yesterday is still work.
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

  if (opts.date) {
    const start = new Date(`${opts.date}T00:00:00+07:00`);
    const day = { gte: start, lt: new Date(start.getTime() + DAY_MS) };
    return {
      kitchenId,
      OR: [
        ...(opts.date === vnDayKey(now) ? [live] : []),
        { status: { in: KITCHEN_VISIBLE }, scheduledFor: day },
        { status: { in: KITCHEN_VISIBLE }, scheduledFor: null, createdAt: day },
        { status: { in: DISPATCHED }, updatedAt: day },
      ],
    };
  }

  if (!opts.includeDoneToday) return { kitchenId, ...live };

  const startOfToday = new Date(`${vnDayKey(now)}T00:00:00+07:00`);
  return {
    kitchenId,
    OR: [live, { status: { in: DISPATCHED }, updatedAt: { gte: startOfToday } }],
  };
}
